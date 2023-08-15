//
//! @file   core_tb.v
//! @brief  Testbench do core sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do toplevel
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato e Banco de Registradores estão corretos.
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
  // instrução (para tentar achar mais erros)
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
  wire [`DATA_SIZE-1:0] ssip;
  wire [63:0] mtime;
  wire [63:0] mtimecmp;
  // Dispositivos
  wire external_interrupt = 1'b0;
  // flags da ULA (simuladas)
  wire zero_;
  wire negative_;
  wire carry_out_;
  wire overflow_;
  wire [`DATA_SIZE-1:0] xorB;
  wire [`DATA_SIZE-1:0] add_sub;
  // variáveis
  integer limit = 1000;  // tamanho do programa que será executado
  integer i;
  integer estado = 0;  // sinal de depuração -> 0: Idle, 1: Fetch, 2: Decode, 3: Execute

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
      .mem_ssip(ssip),
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
      .ssip(ssip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(`BYTE_NUM)
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
      .write_enable(wr_reg_en),
      .read_address1(instruction[19:15]),
      .read_address2(instruction[24:20]),
      .write_address(instruction[11:7]),
      .write_data(reg_data),
      .read_data1(A),
      .read_data2(B)
  );

  // Esperar a borda de descida do ciclo seguinte
  task automatic wait_1_cycle;
    begin
      @(posedge clock);
      @(negedge clock);
    end
  endtask

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
    reg [`DATA_SIZE-1:0] xorB;
    reg [`DATA_SIZE-1:0] add_sub;
    reg overflow;
    reg carry_out;
    reg negative;
    begin
      // Funções da ULA
      case (seletor)
        4'b0000:  // ADD
        ULA_function = $signed(A) + $signed(B);
        4'b0001:  // SLL
        ULA_function = A << (B[5:0]);
        4'b0010: begin  // SLT
          ULA_function = ($signed(A) < $signed(B));
        end
        4'b0011: begin  // SLTU
          ULA_function = (A < B);
        end
        4'b0100:  // XOR
        ULA_function = A ^ B;
        4'b0101:  // SRL
        ULA_function = A >> (B[5:0]);
        4'b0110:  // OR
        ULA_function = A | B;
        4'b0111:  // AND
        ULA_function = A & B;
        4'b1000:  // SUB
        ULA_function = $signed(A) - $signed(B);
        4'b1101:  // SRA
        ULA_function = $signed(A) >>> (B[5:0]);
        default: ULA_function = 0;
      endcase
    end
  endfunction

  // flags da ULA -> B-type
  assign xorB = B ^ {`DATA_SIZE{1'b1}};
  assign {carry_out_, add_sub} = A + xorB + 1;
  assign zero_ = ~(|add_sub);
  assign negative_ = add_sub[`DATA_SIZE-1];
  assign overflow_ = (~(A[`DATA_SIZE-1] ^ B[`DATA_SIZE-1] ^ DUT.sub))
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

  // testar o DUT
  initial begin : Testbench
    $display("Program  size: %d", `program_size);
    $display("SOT!");
    // desabilito a escrita no banco simulado
    wr_reg_en = 1'b0;
    // Idle
    estado = 0;
    @(negedge clock);
    reset = 1'b1;
    // Confiro se os enables estão em baixo no Idle
    `ASSERT(db_mem_en === 0);
    wait_1_cycle;
    reset = 1'b0;
    // Ciclo após reset -> Ainda estamos em Idle
    // Confiro se os enables estão em baixo
    `ASSERT(db_mem_en === 0);
    wait_1_cycle;
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      // Fetch
      // Nota: ao final de todos os executes espero até a borda de descida
      // Não é necessário essa espera, apenas fiz isso para que as atribuições
      // fiquem mais espaçadas na forma de onda e facilitem a depuração
      estado = 1;
      wr_reg_en = 1'b0;
      // Confiro se há acesso a memória de instrução
      `ASSERT(pc === mem_addr);
      `ASSERT(db_mem_en === {2'b01, {`BYTE_NUM - 4{1'b0}}, 4'hF});
      @(posedge mem_busy);
      @(negedge mem_busy);
      @(negedge clock);
      instruction = rd_data;  // leitura da ROM -> instrução
      // Busy abaixado -> instruction mem enable abaixado
      `ASSERT(db_mem_en === 4'hF);
      wait_1_cycle;
      // Decode
      estado = 2;
      // Enables abaixados
      `ASSERT(db_mem_en === 0);
      wait_1_cycle;
      // Execute
      estado = 3;
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          // Confiro o endereço de acesso
          `ASSERT(mem_addr === A + immediate);
          // Caso seja store -> confiro a palavra a ser escrita
          if (opcode[5]) `ASSERT(wr_data === B);
          // Confiro se o acesso a memória de dados está correto
          `ASSERT(db_mem_en === mem_en);
          @(posedge mem_busy);
          @(negedge mem_busy);
          // Load: Após o busy abaixar escrevo no banco simulado
          if (!opcode[5]) begin
            wr_reg_en = 1'b1;
            reg_data  = rd_data;
          end
          @(negedge clock);
          // Na borda de descida, confiro se os sinais de controle abaixaram
          `ASSERT(db_mem_en === {2'b00, mem_byte_en_});
          // Caso load -> confiro a leitura
          if (!opcode[5]) `ASSERT(DUT.DF.rd === reg_data);
          wait_1_cycle;
          pc = pc + 4;
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
          wait_1_cycle;
          // Incremento pc
          if (pc_src) pc = pc_imm;
          else pc = pc_4;
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
          wait_1_cycle;
          pc = pc + 4;
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
          wait_1_cycle;
          pc = pc_imm;
        end
        // ULA R/I-type
        7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
          // Habilito o banco simulado
          wr_reg_en = 1'b1;
          // A partir do opcode, do funct3 e do funct7 descubro o resultado da operação da ULA com a máscara aplicada
          if (opcode[5]) reg_data = ULA_function(A, B, {funct7[5], funct3});
          else if (funct3 === 3'b101) reg_data = ULA_function(A, immediate, {funct7[5], funct3});
          else reg_data = ULA_function(A, immediate, {1'b0, funct3});
          // opcode[3] = 1'b1 -> RV64I
          if (opcode[3] === 1'b1) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
          // Verifico reg_data
          `ASSERT(reg_data === DUT.DF.rd);
          // Verifico se os enables estão desligados
          `ASSERT(db_mem_en === 0);
          wait_1_cycle;
          pc = pc + 4;
        end
        7'b0000000: begin
          // Fim do programa -> último opcode: 0000000
          if (pc === `program_size - 4) $display("End  of program!");
          else $display("Error pc: pc = %x", pc);
          $stop;
        end
        default: begin  // Ecall or Illegal Instruction
          wr_reg_en = 1'b0;
          // Confiro se a memória está inativada
          `ASSERT(db_mem_en === 0);
          wait_1_cycle;
          pc = pc + 4;
        end
      endcase
    end
  end
endmodule
