//
//! @file   core_tb.v
//! @brief  Testbench do core sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do toplevel
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato, CSR, CSR_mem e Banco de Registradores estão corretos.
// Com isso, basta testar se o toplevel consegue interligar a UC e o DF
// corretamente e se o comportamento desses componentes está sincronizado
// Para isso irei verificar as saídas do toplevel

`timescale 1 ns / 1 ns

`include "macros.vh"

`ifdef RV64I
`define BYTE_NUM 8
`define DATA_SIZE 64
`else
`define BYTE_NUM 4
`define DATA_SIZE 32
`endif

`define ASSERT(condition) if (!(condition)) $stop

module core_tb ();
  // sinais do DUT
  reg clock;
  reg reset;
  // BUS
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] wr_data;
  wire [`DATA_SIZE-1:0] mem_addr;
  wire mem_busy;
  wire mem_rd_en;
  wire mem_wr_en;
  wire [`BYTE_NUM-1:0] mem_byte_en;
  // Sinais intermediários de teste
  wire [6:0] opcode;  // opcode simulado pelo TB
  wire [2:0] funct3;  // funct3 simulado pelo TB
  wire [6:0] funct7;  // funct7 simulado pelo TB
  reg [31:0] instruction;  // Instrução executada pelo DUT
  wire [`DATA_SIZE-1:0] immediate;  // Saída do Extensor de Imediato do TB
  wire [`DATA_SIZE-1:0] A_immediate;  // A + imediato
  reg wr_reg_en;  // write enable do banco de registradores
  wire [`BYTE_NUM-1:0] mem_byte_en_;  // data mem byte write enable simulado pelo TB
  wire mem_rd_en_;  // data mem read enable simulado pelo TB
  wire mem_wr_en_;  // data mem write enable simulado pelo TB
  reg [`DATA_SIZE-1:0] reg_data;  // write data do banco de registradores
  wire [`DATA_SIZE-1:0] A;  // read data 1 do banco de registradores
  wire [`DATA_SIZE-1:0] B;  // read data 2 do banco de registradores
  reg [`DATA_SIZE-1:0] pc = 0;  // pc -> Uso esse pc para acessar a memória de
  reg [`DATA_SIZE-1:0] next_pc = 0;  // próximo valor do pc
  // instrução
  reg pc_src;  // seletor da entrada do registrador PC
  reg [`DATA_SIZE-1:0] pc_imm;  // pc + imediato
  reg [`DATA_SIZE-1:0] pc_4;  // pc + 4
  wire mem_op;  // 1, caso esteja sendo executado um S* ou L*
  wire [`BYTE_NUM+1:0] mem_en;  // Concatenação dos sinais de enable gerados pelo tb
  wire [`BYTE_NUM+1:0] db_mem_en;  // Concatenação dos sinais de enable gerados pelo dut
  // Sinais do Barramento
  // Instruction Memory
  wire [31:0] rom_data;
  wire [`DATA_SIZE-1:0] rom_addr;
  wire rom_enable;
  wire rom_busy;
  // Data Memory
  wire [`DATA_SIZE-1:0] ram_address;
  wire [`DATA_SIZE-1:0] ram_write_data;
  wire [`DATA_SIZE-1:0] ram_read_data;
  wire ram_output_enable;
  wire ram_write_enable;
  wire ram_chip_select;
  wire [`BYTE_NUM-1:0] ram_byte_enable;
  wire ram_busy;
  // Registradores do CSR mapeados em memória
  wire csr_mem_rd_en;
  wire csr_mem_wr_en;
  wire csr_mem_busy;
  wire [2:0] csr_mem_addr;
  wire [`DATA_SIZE-1:0] csr_mem_wr_data;
  wire [`DATA_SIZE-1:0] csr_mem_rd_data;
  wire [`DATA_SIZE-1:0] msip;
  wire [63:0] mtime;
  wire [63:0] mtimecmp;
  // Dispositivos
  wire external_interrupt = 1'b0;
  // CSR
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
  wire [`DATA_SIZE-1:0] csr_rd_data;
  reg [`DATA_SIZE-1:0] csr_wr_data;
  reg csr_wr_en;
  reg mret;
  reg sret;
  wire csr_trap;
  wire [`DATA_SIZE-1:0] trap_addr;
  reg _trap;  // csr_trap antes da borda de subida do clock
  wire [1:0] csr_privilege_mode;
  wire csr_addr_exception;
  // flags da ULA (simuladas)
  wire zero_;
  wire negative_;
  wire carry_out_;
  wire overflow_;
  wire [`DATA_SIZE-1:0] xorB;
  wire [`DATA_SIZE-1:0] add_sub;
  // variáveis
  integer limit = 10000;  // tamanho do programa que será executado
  localparam integer Fetch = 0, Decode = 1, Execute = 2, Reset = 5;  // Estados
  integer estado = Reset;
  integer i;

  // DUT
  core DUT (
      .clock(clock),
      .reset(reset),
      .rd_data(rd_data),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .mem_busy(mem_busy),
      .mem_rd_en(mem_rd_en),
      .mem_byte_en(mem_byte_en),
      .mem_wr_en(mem_wr_en),
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp)
  );

  // Instruction Memory
  ROM #(
      .rom_init_file("./ROM.mif"),
      .word_size(8),
      .addr_size(10),
      .offset(2),
      .busy_cycles(2)
  ) Instruction_Memory (
      .clock (clock),
      .enable(rom_enable),
      .addr  (rom_addr[9:0]),
      .data  (rom_data),
      .busy  (rom_busy)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(12),
      .BYTE_SIZE(8),
      .DATA_SIZE(`DATA_SIZE),
      .BUSY_CYCLES(2)
  ) Data_Memory (
      .clk(clock),
      .address(ram_address),
      .write_data(ram_write_data),
      .output_enable(ram_output_enable),
      .write_enable(ram_write_enable),
      .chip_select(ram_chip_select),
      .byte_enable(ram_byte_enable),
      .read_data(ram_read_data),
      .busy(ram_busy)
  );

  // Registradores em memória do CSR
  CSR_mem mem_csr (
      .clock(clock),
      .reset(reset),
      .rd_en(csr_mem_rd_en),
      .wr_en(csr_mem_wr_en),
      .addr(csr_mem_addr),
      .wr_data(csr_mem_wr_data),
      .rd_data(csr_mem_rd_data),
      .busy(csr_mem_busy),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(`BYTE_NUM),
      .MTIME_ADDR({32'b0, 262142*(2**12)}),    // lui 262142
      .MTIMECMP_ADDR({32'b0, 262143*(2**12)}), // lui 262143
      .MSIP_ADDR({32'b0, 262144*(2**12)})      // lui 262144
  ) BUS (
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .mem_byte_en(mem_byte_en),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .rd_data(rd_data),
      .mem_busy(mem_busy),
`ifdef RV64I
      .inst_cache_data({32'b0, rom_data}),
`else
      .inst_cache_data(rom_data),
`endif
      .inst_cache_busy(rom_busy),
      .inst_cache_enable(rom_enable),
      .inst_cache_addr(rom_addr),
      .ram_read_data(ram_read_data),
      .ram_busy(ram_busy),
      .ram_address(ram_address),
      .ram_write_data(ram_write_data),
      .ram_output_enable(ram_output_enable),
      .ram_write_enable(ram_write_enable),
      .ram_chip_select(ram_chip_select),
      .ram_byte_enable(ram_byte_enable),
      .csr_mem_addr(csr_mem_addr),
      .csr_mem_rd_en(csr_mem_rd_en),
      .csr_mem_wr_en(csr_mem_wr_en),
      .csr_mem_wr_data(csr_mem_wr_data),
      .csr_mem_rd_data(csr_mem_rd_data),
      .csr_mem_busy(csr_mem_busy)
  );

  // Componentes auxiliares para a verificação
  ImmediateExtender #(
      .N(`DATA_SIZE)
  ) extensor_imediato (
      .immediate  (immediate),
      .instruction(instruction)
  );

  register_file #(
      .size(`DATA_SIZE),
      .N(5)
  ) banco_de_registradores (
      .clock(clock),
      .reset(reset),
      .write_enable(wr_reg_en && !csr_trap),
      .read_address1(instruction[19:15]),
      .read_address2(instruction[24:20]),
      .write_address(instruction[11:7]),
      .write_data(reg_data),
      .read_data1(A),
      .read_data2(B)
  );

  CSR registradores_de_controle (
      .clock(clock),
      .reset(reset),
      // Interrupt/Exception Signals
      .ecall(check_ecall(opcode, funct3, funct7, estado)),
      // .illegal_instruction(DUT.illegal_instruction),
      .illegal_instruction(check_illegal_instruction(opcode, funct3, funct7, estado,
                           csr_addr_exception, csr_privilege_mode)),
      .external_interrupt(external_interrupt),
      .mem_msip(|msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp),
      .instruction(instruction),
      .trap_addr(trap_addr),
      .trap(csr_trap),
      .privilege_mode(csr_privilege_mode),
      .addr_exception(csr_addr_exception),
      .pc(pc),
      // CSR RW interface
`ifdef ZICSR
      .wr_en(csr_wr_en & (~funct3[1] | (|instruction[19:15]))),
      .addr(instruction[31:20]),
      .wr_data(csr_wr_data),
      .rd_data(csr_rd_data),
`else
      .wr_en(1'b0),
      .addr(12'b0),
      .wr_data(`DATA_SIZE'b0),
      .rd_data(),
`endif
      // MRET & SRET
`ifdef TrapReturn
      .mret(mret),
      .sret(sret),
`else
      .mret(1'b0),
      .sret(1'b0),
`endif
      .mepc(mepc),
      .sepc(sepc)
  );

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  // função que simula o comportamento da ULA
  function automatic [`DATA_SIZE-1:0] ULA_function(
      input reg [`DATA_SIZE-1:0] A, input reg [`DATA_SIZE-1:0] B, input reg [3:0] seletor);
    begin
      case (seletor)
        4'b0000: ULA_function = $signed(A) + $signed(B);  // ADD
        4'b0001: ULA_function = A << (B[$clog2(`DATA_SIZE)-1:0]);  // SLL
        4'b0010: ULA_function = ($signed(A) < $signed(B));  // SLT
        4'b0011: ULA_function = (A < B);  // SLTU
        4'b0100: ULA_function = A ^ B;  // XOR
        4'b0101: ULA_function = A >> (B[$clog2(`DATA_SIZE)-1:0]); // SRL
        4'b0110: ULA_function = A | B;  // OR
        4'b0111: ULA_function = A & B;  // AND
        4'b1000: ULA_function = $signed(A) - $signed(B);  // SUB
        4'b1101: ULA_function = $signed(A) >>> (B[$clog2(`DATA_SIZE)-1:0]);  // SRA
        default: ULA_function = 0;
      endcase
    end
  endfunction

  // função que simula o comportamento do ZICSR
  function automatic [`DATA_SIZE-1:0] CSR_function(
    input reg [`DATA_SIZE-1:0] rd_data, input reg [`DATA_SIZE-1:0] mask, input reg [1:0] op);
    begin
      case(op)
        2'b01: CSR_function = mask; // W
        2'b10: CSR_function = rd_data | mask; // S
        2'b11: CSR_function = rd_data & (~mask); // C
        default: CSR_function = 0;
      endcase
    end
  endfunction

  // função que calcula quando há um ecall
  function automatic check_ecall(input reg [6:0] opcode, input reg [2:0] funct3,
   input reg [6:0] funct7, input reg [3:0] estado);
    begin
      check_ecall = opcode === 7'b1110011 && funct3 === 0 && funct7 === 0 && estado === Execute;
    end
  endfunction

  // função que calcula quando há um sub na ULA
  function automatic check_sub(input reg [6:0] opcode, input reg [6:0] funct7);
    begin
      check_sub = (opcode === 7'b1100011) || (opcode === 7'b0110011 && funct7[5]);
    end
  endfunction

  // função para verificar se uma instrução é inválida
  function automatic check_illegal_instruction(input reg [6:0] opcode, input reg [2:0] funct3,
   input reg [6:0] funct7, input reg [3:0] estado, input reg csr_addr_exception,
   input reg [1:0] priv);
    begin
      check_illegal_instruction = 1'b0;
      if(estado !== Reset && estado !== Fetch) begin
        case(opcode)
          7'b0100011: begin // S-Type
            check_illegal_instruction = 1'b1;
            if(funct3[2] === 1'b0) begin
              check_illegal_instruction = 1'b0;
              `ifndef RV64I
                if(funct3[1:0] === 2'b11) check_illegal_instruction = 1'b1;
              `endif
            end
          end
          7'b0000011: begin // I-Type (Load)
            check_illegal_instruction = 1'b1;
            `ifdef RV64I
              if(funct3 !== 3'b111) check_illegal_instruction = 1'b0;
            `else
              if(funct3 !== 3'b011 && funct3[2:1] !== 2'b11) check_illegal_instruction = 1'b0;
            `endif
          end
          7'b1100011, 7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111: // U/B/J-Type, JALR
            check_illegal_instruction = 1'b0;
          7'b0010011: begin // ULA I-Type
            `ifdef RV64I
              if(funct3 === 3'b001 && funct7[6:1] !== 0) check_illegal_instruction = 1'b1;
              if(funct3 === 3'b101 && {funct7[6],funct7[4:1]} !== 0)
                check_illegal_instruction = 1'b1;
            `else
              if(funct3 === 3'b001 && funct7 !== 0) check_illegal_instruction = 1'b1;
              if(funct3 === 3'b101 && {funct7[6],funct7[4:0]} !== 0)
                check_illegal_instruction = 1'b1;
            `endif
          end
          `ifdef RV64I
          7'b0011011: begin // ULA W I-Type
            check_illegal_instruction = 1'b1;
            if(funct3 === 3'b000) check_illegal_instruction = 1'b0; // ADDIW
            if(funct3 === 3'b001 && funct7 === 0) check_illegal_instruction = 1'b0; // SLLIW
            if(funct3 === 3'b101 && {funct7[6],funct7[4:0]} === 0) check_illegal_instruction = 1'b0;
          end
          `endif
          7'b0110011: begin // ULA R-Type
            if(funct3 === 3'b000 || funct3 === 3'b101) begin
              if({funct7[6],funct7[4:0]} !== 0) check_illegal_instruction = 1'b1;
            end
            else if(funct7 !== 0) check_illegal_instruction = 1'b1;
          end
          `ifdef RV64I
          7'b0111011: begin // ULA W R-Type
            check_illegal_instruction = 1'b1;
            if(funct3 === 3'b000 || funct3 === 3'b101) begin
              if({funct7[6],funct7[4:0]} === 0) check_illegal_instruction = 1'b0;
            end
            else if(funct3 === 3'b001) check_illegal_instruction = 1'b0;
          end
          `endif
          7'b1110011: begin // SYSTEM
            check_illegal_instruction = 1'b1;
            if(funct3 === 0) begin
              if(funct7 === 0) check_illegal_instruction = 1'b0; // ECALL
              `ifdef TrapReturn
              else if(funct7 === 7'h18 && priv === 2'b11) check_illegal_instruction = 1'b0; // MRET
              else if(funct7 === 7'h08 && priv[0]) check_illegal_instruction = 1'b0; // SRET
              `endif
            end
            `ifdef ZICSR
            else if(funct3 !== 3'b100) begin // Zicsr
              if(csr_addr_exception && estado === Execute) check_illegal_instruction = 1'b1;
              else if(priv >= funct7[6:5]) check_illegal_instruction = 1'b0;
            end
            `endif
          end
          default: check_illegal_instruction = 1'b1; // invalid opcode
        endcase
      end
    end
  endfunction

  // flags da ULA -> B-type
  assign xorB = B ^ {`DATA_SIZE{1'b1}};
  assign {carry_out_, add_sub} = A + xorB + 1;
  assign zero_ = ~(|add_sub);
  assign negative_ = add_sub[`DATA_SIZE-1];
  assign overflow_ = (~(A[`DATA_SIZE-1] ^ B[`DATA_SIZE-1] ^ check_sub(opcode, funct7)))
                     & (A[`DATA_SIZE-1] ^ add_sub[`DATA_SIZE-1]);

  // geração dos sinais da instrução
  assign opcode = instruction[6:0];
  assign funct3 = instruction[14:12];
  assign funct7 = instruction[31:25];

  // geração dos sinais de controle do barramento
  assign mem_op = (opcode === 7'b0100011 || opcode === 7'b0000011) ? 1'b1 : 1'b0;
  assign mem_byte_en_ = funct3[1] ? (funct3[0] ? ({`BYTE_NUM{1'b1}} & {`BYTE_NUM{mem_op}})
                                  : (`BYTE_NUM'hF & {`BYTE_NUM{mem_op}}))
                                  : (funct3[0] ? (`BYTE_NUM'h3 & {`BYTE_NUM{mem_op}})
                                  : (`BYTE_NUM'h1 & {`BYTE_NUM{mem_op}}));
  assign mem_rd_en_ = (opcode === 7'b0000011) ? 1'b1 : 1'b0;
  assign mem_wr_en_ = (opcode === 7'b0100011) ? 1'b1 : 1'b0;
  assign mem_en = {mem_wr_en_, mem_rd_en_, mem_byte_en_};
  assign db_mem_en = {mem_wr_en, mem_rd_en, mem_byte_en};

  // geração do A_immediate
  assign A_immediate = A + immediate;

  // Always to finish the simulation
  always @(posedge mem_wr_en) begin
    if(mem_addr == 16781308) begin // Final write addr
      $display("End of program!");
      $display("Write data: 0x%x", wr_data);
      $stop;
    end
  end

  // Não uso apenas @(negedge mem_busy), pois pode haver traps a serem tratadas!
  task automatic wait_mem();
    begin
      forever begin
        @(mem_busy, csr_trap);
        if (csr_trap) disable wait_mem;
        else if (!mem_busy) disable wait_mem;  // Descida
      end
    end
  endtask

  task automatic DoReset();
    begin
      // desabilito a escrita no banco simulado
      wr_reg_en = 1'b0;
      csr_wr_en = 1'b0;
      mret = 1'b0;
      sret = 1'b0;
      reg_data = 0;
      csr_wr_data = 0;
      pc_4 = 0;
      pc_imm = 0;
      reset = 1'b1;
      `ASSERT(db_mem_en === 0);  // Enables abaixados: Idle
      @(posedge clock);
      @(negedge clock);
      reset = 1'b0;
      `ASSERT(db_mem_en === 0);  // Enables abaixados: Idle
    end
  endtask

  task automatic DoFetch();
    begin
      wr_reg_en = 1'b0;
      csr_wr_en = 1'b0;
      mret = 1'b0;
      sret = 1'b0;
      `ASSERT(pc === mem_addr);
      `ASSERT(db_mem_en === {2'b01, {`BYTE_NUM - 4{1'b0}}, 4'hF});
      // Trap não muda o pc anterior, pois não passou a borda de subida
      if(csr_trap) disable DoFetch;
      wait_mem;
      @(negedge clock);
      // Trap -> Ainda estou em Fetch 1
      if (mem_busy) begin
        `ASSERT(pc === mem_addr);
        `ASSERT(db_mem_en === {2'b01, {`BYTE_NUM - 4{1'b0}}, 4'hF});
      end else begin
        instruction = rd_data;  // leitura da ROM -> instrução
        // Busy abaixado -> instruction mem enable abaixado
        `ASSERT(db_mem_en === 4'hF);
      end
    end
  endtask

  task automatic DoDecode();
    begin
      `ASSERT(db_mem_en === 0);
    end
  endtask

  task automatic DoExecute();
    begin
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          // Confiro o endereço de acesso
          `ASSERT(mem_addr === A + immediate);
          // Caso seja store -> confiro a palavra a ser escrita
          if (opcode[5]) `ASSERT(wr_data === B);
          // Confiro se o acesso a memória de dados está correto
          `ASSERT(db_mem_en === mem_en);
          wait_mem;
          // Load: Após o busy abaixar escrevo no banco simulado
          if (!opcode[5]) begin
            wr_reg_en = 1'b1;
            reg_data  = rd_data;
          end
          @(negedge clock);
          // Trap -> Ainda estou em Store1/Load1
          if (mem_busy) begin
            `ASSERT(mem_addr === A + immediate);
            `ASSERT(db_mem_en === mem_en);
          end else begin
            // Na borda de descida, confiro se os sinais de controle abaixaram
            `ASSERT(db_mem_en === {2'b00, mem_byte_en_});
            // Caso load -> confiro a leitura
            if (!opcode[5]) `ASSERT(DUT.DF.rd === reg_data);
          end
          next_pc = pc + 4;
        end
        // Branch(B*)
        7'b1100011: begin
          // Decido o valor de pc_src com base em funct3 e no valor das flags simuladas
          if (funct3[2:1] === 2'b00) pc_src = zero_ ^ funct3[0];
          else if (funct3[2:1] === 2'b10) pc_src = negative_ ^ overflow_ ^ funct3[0];
          else if (funct3[2:1] === 2'b11) pc_src = carry_out_ ~^ funct3[0];
          else $display("Error B-type: Invalid funct3! Funct3 : %b", funct3);
          // Habilito o pc
          pc_4      = pc + 4;
          pc_imm    = pc + (immediate << 1);
          wr_reg_en = 1'b0;
          // Confiro se a memória está inativada
          `ASSERT(db_mem_en === 0);
          // Incremento pc
          if (pc_src) next_pc = pc_imm;
          else next_pc = pc_4;
        end
        // LUI e AUIPC
        7'b0110111, 7'b0010111: begin
          // Habilito o banco simulado
          wr_reg_en = 1'b1;
          if (opcode[5]) reg_data = immediate;  // LUI
          else reg_data = mem_addr + immediate;  // AUIPC
          // Confiro se reg_data está correto
          `ASSERT(reg_data === DUT.DF.rd);
          // Verifico se os enables estão desligados
          `ASSERT(db_mem_en === 0);
          next_pc = pc + 4;
        end
        // JAL e JALR
        7'b1101111, 7'b1100111: begin
          // Habilito o banco simulado
          wr_reg_en = 1'b1;
          reg_data  = pc + 4;  // escrever pc + 4 no banco -> Link
          // Decido o novo valor de pc a partir do opcode da instrução (salto incondicional)
          if (opcode[3]) pc_imm = mem_addr + (immediate << 1);  // JAL
          else pc_imm = {A_immediate[31:1], 1'b0};  // JALR
          // Confiro a escrita no banco
          `ASSERT(DUT.DF.rd === reg_data);
          // Verifico se os enables estão desligados
          `ASSERT(db_mem_en === 0);
          next_pc = pc_imm;
        end
        // ULA R/I-type
        7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
          // Habilito o banco simulado
          wr_reg_en = 1'b1;
          // A partir do opcode, do funct3 e do funct7 descubro o resultado da operação da ULA
          if (opcode[5]) reg_data = ULA_function(A, B, {funct7[5], funct3});
          else if (funct3 === 3'b101) reg_data = ULA_function(A, immediate, {funct7[5], funct3});
          else reg_data = ULA_function(A, immediate, {1'b0, funct3});
          // opcode[3] = 1'b1 -> RV64I
          if (opcode[3] === 1'b1) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
          // Verifico reg_data
          `ASSERT(reg_data === DUT.DF.rd);
          // Verifico se os enables estão desligados
          `ASSERT(db_mem_en === 0);
          next_pc = pc + 4;
        end
        // ECALL, MRET, SRET (SYSTEM) -> O privilégio já foi checado
        7'b1110011: begin
          wr_reg_en = 1'b0;
          if(funct3 === 3'b000) begin
            if(funct7 === 0) next_pc = trap_addr; // Ecall
          `ifdef TrapReturn
            else if(funct7 === 7'b0011000 && csr_privilege_mode === 2'b11) begin
              mret = 1'b1;
              next_pc = mepc; // MRET
            end
            else if(funct7 === 7'b0001000 && csr_privilege_mode[0] === 1'b1) begin
              sret = 1'b1;
              next_pc = sepc; // SRET
            end
          `endif
            else begin
              $display("Error SYSTEM: Invalid funct7! funct7 : %x", funct7);
              $stop;
            end
          end
        `ifdef ZICSR // Apenas aqui há ifdef, pois nem sempre DUT.DF.csr_wr_data existe
          else if(funct3 !== 3'b100) begin // CSRR*
            wr_reg_en = 1'b1;
            csr_wr_en = !(instruction[19:15] === 0);
            reg_data = csr_rd_data;
            if(instruction[31:20] == 12'h344 || instruction[31:20] == 12'h144)
              reg_data[registradores_de_controle.SEIP] =
                csr_rd_data[registradores_de_controle.SEIP] | external_interrupt;
            if(funct3[2]) csr_wr_data = CSR_function(csr_rd_data, instruction[19:15], funct3[1:0]);
            else csr_wr_data = CSR_function(csr_rd_data, A, funct3[1:0]);
            // Sempre checo a leitura/escrita até se ela não acontecer
            if(csr_privilege_mode >= funct7[6:5]) begin
              `ASSERT(csr_wr_data === DUT.DF.csr_wr_data);
              `ASSERT(reg_data === DUT.DF.rd);
            end
            next_pc = pc + 4;
          end
        `endif
          else begin
              $display("Error SYSTEM: Invalid funct3! funct3 : %x", funct3);
              $stop;
          end
          // Confiro se a memória está inativada
          `ASSERT(db_mem_en === 0);
        end
        default: begin
          // Fim do programa -> último opcode: 0000000
          if (pc === `program_size - 4) $display("End  of program!");
          else $display("Error pc: pc = %x", pc);
          $stop;
        end
      endcase
    end
  endtask

  // testar o DUT
  initial begin : Testbench
    $display("Program  size: %d", `program_size);
    $display("SOT!");
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      @(negedge clock);
      case (estado)
        Fetch:   DoFetch;
        Decode:  DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      #1;
      `ASSERT(DUT.trap === csr_trap);
      `ASSERT(DUT.privilege_mode === csr_privilege_mode);
      _trap = csr_trap;
      @(posedge clock);
      // Atualizando estado  e pc
      if (_trap) begin
        estado = Fetch;
        pc = trap_addr;
      end else begin
        estado = (estado + 1) % 3;
        pc = next_pc;
      end
      next_pc = pc;
    end
    $stop;
  end
endmodule
