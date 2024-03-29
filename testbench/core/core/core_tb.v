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

`include "macros.vh"
`include "extensions.vh"

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
  wire mem_ack;
  wire mem_wr_en;
  wire mem_CYC_O;
  wire mem_STB_O;
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
  wire mem_CYC_O_;  // data mem CYC O simulado pelo TB
  wire mem_STB_O_;  // data mem STB O simulado pelo TB
  wire mem_wr_en_;  // data mem write enable simulado pelo TB
  reg [`DATA_SIZE-1:0] reg_data;  // write data do banco de registradores
  wire [`DATA_SIZE-1:0] A;  // read data 1 do banco de registradores
  wire [`DATA_SIZE-1:0] B;  // read data 2 do banco de registradores
  reg [`DATA_SIZE-1:0] aluA; // register operator A of ULA
  reg [`DATA_SIZE-1:0] aluB; // register operator B of ULA
  reg [`DATA_SIZE-1:0] pc = 0;  // pc -> Uso esse pc para acessar a memória de
  reg [`DATA_SIZE-1:0] next_pc = 0;  // próximo valor do pc
  // instrução
  reg pc_src;  // seletor da entrada do registrador PC
  reg [`DATA_SIZE-1:0] pc_imm;  // pc + imediato
  reg [`DATA_SIZE-1:0] pc_4;  // pc + 4
  wire mem_op;  // 1, caso esteja sendo executado um S* ou L*
  wire [`BYTE_NUM+2:0] mem_en;  // Concatenação dos sinais de enable gerados pelo tb
  wire [`BYTE_NUM+2:0] db_mem_en;  // Concatenação dos sinais de enable gerados pelo dut
  // Sinais do Barramento
  // Instruction Memory
  wire [31:0] rom_DAT_I;
  wire [`DATA_SIZE-1:0] rom_ADR_O;
  wire rom_CYC_O;
  wire rom_STB_O;
  wire rom_ACK_I;
  // Data Memory
  wire [`DATA_SIZE-1:0] ram_ADR_O;
  wire [`DATA_SIZE-1:0] ram_DAT_O;
  wire [`DATA_SIZE-1:0] ram_DAT_I;
  wire ram_CYC_O;
  wire ram_STB_O;
  wire ram_WE_O;
  wire [`BYTE_NUM-1:0] ram_SEL_O;
  wire ram_ACK_I;
  // Registradores do CSR mapeados em memória
  wire csr_mem_CYC_O;
  wire csr_mem_STB_O;
  wire csr_mem_WE_O;
  wire csr_mem_ACK_I;
  wire [2:0] csr_mem_ADR_O;
  wire [`DATA_SIZE-1:0] csr_mem_DAT_O;
  wire [`DATA_SIZE-1:0] csr_mem_DAT_I;
  wire [`DATA_SIZE-1:0] msip;
  wire [63:0] mtime;
  wire [63:0] mtimecmp;
  // Dispositivos
  reg external_interrupt;
  // CSR
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
  wire [`DATA_SIZE-1:0] csr_rd_data;
  reg [`DATA_SIZE-1:0] csr_wr_data;
  reg csr_wr_en;
  reg mret;
  reg sret;
  reg trap_en = 1'b0;
  wire csr_trap;
  wire [`DATA_SIZE-1:0] trap_addr;
  reg [`DATA_SIZE-1:0] _trap_addr;
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
  // Address
  localparam integer FinalAddress = 16781308; // Final execution address
  localparam integer ExternalInterruptAddress = 16781320; // Active/Desactive External Interrupt

  // DUT
  core DUT (
      .clock(clock),
      .reset(reset),
      .DAT_I(rd_data),
      .DAT_O(wr_data),
      .mem_ADR_O(mem_addr),
      .mem_ACK_I(mem_ack),
      .mem_CYC_O(mem_CYC_O),
      .mem_STB_O(mem_STB_O),
      .mem_SEL_O(mem_byte_en),
      .mem_WE_O(mem_wr_en),
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp)
  );

  // Instruction Memory
  ROM #(
      .ROM_INIT_FILE("./ROM.mif"),
      .WORD_SIZE(8),
      .ADDR_SIZE(10),
      .OFFSET(2),
      .BUSY_CYCLES(2)
  ) Instruction_Memory (
      .CLK_I(clock),
      .CYC_I(rom_CYC_O),
      .STB_I(rom_STB_O),
      .ADR_I(rom_ADR_O[9:0]),
      .DAT_O(rom_DAT_I),
      .ACK_O(rom_ACK_I)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(12),
      .BYTE_SIZE(8),
      .DATA_SIZE(`DATA_SIZE),
      .BUSY_CYCLES(2)
  ) Data_Memory (
      .CLK_I(clock),
      .ADR_I(ram_ADR_O),
      .DAT_I(ram_DAT_O),
      .CYC_I(ram_CYC_O),
      .STB_I(ram_STB_O),
      .WE_I (ram_WE_O),
      .SEL_I(ram_SEL_O),
      .DAT_O(ram_DAT_I),
      .ACK_O(ram_ACK_I)
  );

  // Registradores em memória do CSR
  CSR_mem mem_csr (
    .CLK_I(clock),
    .RST_I(reset),
    .ADR_I(csr_mem_ADR_O),
    .DAT_I(csr_mem_DAT_O),
    .CYC_I(csr_mem_CYC_O),
    .STB_I(csr_mem_STB_O),
    .WE_I(csr_mem_WE_O),
    .DAT_O(csr_mem_DAT_I),
    .ACK_O(csr_mem_ACK_I),
    .msip(msip),
    .mtime(mtime),
    .mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(`BYTE_NUM),
      .ROM_ADDR_INIT(0),
      .ROM_ADDR_END(32'h00FFFFFF),
      .RAM_ADDR_INIT(32'h01000000),
      .RAM_ADDR_END(32'h04FFFFFF),
      .MTIME_ADDR({32'b0, 262142*(2**12)}),    // lui 262142
      .MTIMECMP_ADDR({32'b0, 262143*(2**12)}), // lui 262143
      .MSIP_ADDR({32'b0, 262144*(2**12)})      // lui 262144
  ) BUS (
      .cpu_CYC_I(mem_CYC_O),
      .cpu_STB_I(mem_STB_O),
      .cpu_WE_I(mem_wr_en),
      .cpu_SEL_I(mem_byte_en),
      .cpu_DAT_I(wr_data),
      .cpu_ADR_I(mem_addr),
      .cpu_DAT_O(rd_data),
      .cpu_ACK_O(mem_ack),
    `ifdef RV64I
      .rom_DAT_I    ({32'b0, rom_DAT_I}),
    `else
      .rom_DAT_I    (rom_DAT_I),
    `endif
      .rom_ACK_I    (rom_ACK_I),
      .rom_CYC_O    (rom_CYC_O),
      .rom_STB_O    (rom_STB_O),
      .rom_ADR_O    (rom_ADR_O),
      .ram_DAT_I    (ram_DAT_I),
      .ram_ACK_I    (ram_ACK_I),
      .ram_ADR_O    (ram_ADR_O),
      .ram_DAT_O    (ram_DAT_O),
      .ram_CYC_O    (ram_CYC_O),
      .ram_WE_O     (ram_WE_O),
      .ram_STB_O    (ram_STB_O),
      .ram_SEL_O    (ram_SEL_O),
      .csr_mem_DAT_I(csr_mem_DAT_I),
      .csr_mem_ACK_I(csr_mem_ACK_I),
      .csr_mem_ADR_O(csr_mem_ADR_O),
      .csr_mem_DAT_O(csr_mem_DAT_O),
      .csr_mem_CYC_O(csr_mem_CYC_O),
      .csr_mem_STB_O(csr_mem_STB_O),
      .csr_mem_WE_O (csr_mem_WE_O)
  );

  // Componentes auxiliares para a verificação
  immediate_extender #(
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
      .write_enable(wr_reg_en && !(opcode === 7'b1110011 && funct3 !== 0 && csr_addr_exception)),
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
      .trap_en(trap_en),
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
      input reg [`DATA_SIZE-1:0] A, input reg [`DATA_SIZE-1:0] B, input reg [4:0] seletor);
    reg [2*`DATA_SIZE-1:0] mulh, mulhsu, mulhu;
    begin
      case (seletor)
        5'b00000: ULA_function = $signed(A) + $signed(B);  // ADD
        5'b00001: ULA_function = A << (B[$clog2(`DATA_SIZE)-1:0]);  // SLL
        5'b00010: ULA_function = ($signed(A) < $signed(B));  // SLT
        5'b00011: ULA_function = (A < B);  // SLTU
        5'b00100: ULA_function = A ^ B;  // XOR
        5'b00101: ULA_function = A >> (B[$clog2(`DATA_SIZE)-1:0]); // SRL
        5'b00110: ULA_function = A | B;  // OR
        5'b00111: ULA_function = A & B;  // AND
        5'b01000: ULA_function = $signed(A) - $signed(B);  // SUB
        5'b01101: ULA_function = $signed(A) >>> (B[$clog2(`DATA_SIZE)-1:0]);  // SRA
        5'b10000: ULA_function = A * B; // MUL
        5'b10001: begin  // MULH
          mulh = $signed(A) * $signed(B);
          ULA_function = mulh[2*`DATA_SIZE-1:`DATA_SIZE];
        end
        5'b10010: begin
          mulhsu = $signed(A) * B;
          ULA_function = mulhsu[2*`DATA_SIZE-1:`DATA_SIZE]; // MULHSU
        end
        5'b10011: begin
          mulhu = A * B;
          ULA_function = mulhu[2*`DATA_SIZE-1:`DATA_SIZE]; // MULHU
        end
        5'b10100: ULA_function = $signed(A) / $signed(B); // DIV
        5'b10101: ULA_function = A / B; // DIVU
        5'b10110: ULA_function = $signed(A) % $signed(B); // REM
        5'b10111: ULA_function = A % B; // REMU
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
          7'b0001111: begin // FENCE
            check_illegal_instruction = 1'b0;
            if(funct3 !== 3'b000) check_illegal_instruction = 1'b1;
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
              else if(priv >= funct7[4:3]) check_illegal_instruction = 1'b0;
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
  assign mem_op = (opcode === 7'b0100011 || opcode === 7'b0000011);
  assign mem_byte_en_ = funct3[1] ? (funct3[0] ? ({`BYTE_NUM{1'b1}} & {`BYTE_NUM{mem_op}})
                                  : (`BYTE_NUM'hF & {`BYTE_NUM{mem_op}}))
                                  : (funct3[0] ? (`BYTE_NUM'h3 & {`BYTE_NUM{mem_op}})
                                  : (`BYTE_NUM'h1 & {`BYTE_NUM{mem_op}}));
  assign mem_rd_en_ = (opcode === 7'b0000011);
  assign mem_wr_en_ = (opcode === 7'b0100011);
  assign mem_CYC_O_ = mem_rd_en_ | mem_wr_en_;
  assign mem_STB_O_ = mem_CYC_O_;
  assign mem_en = {mem_wr_en_, mem_CYC_O_, mem_STB_O_, mem_byte_en_};
  assign db_mem_en = {mem_wr_en, mem_CYC_O, mem_STB_O, mem_byte_en};

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

  // Always to set/reset external_interrupt
  always @(posedge clock, posedge reset) begin
    if(reset) external_interrupt = 1'b0;
    else if(mem_addr == ExternalInterruptAddress && mem_wr_en) external_interrupt = |wr_data;
  end

  task automatic DoReset();
    begin
      // desabilito a escrita no banco simulado
      wr_reg_en = 1'b0;
      csr_wr_en = 1'b0;
      mret = 1'b0;
      sret = 1'b0;
      reg_data = 0;
      aluA = 0;
      aluB = 0;
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
      `ASSERT(db_mem_en === {3'b011, {`BYTE_NUM - 4{1'b0}}, 4'hF});
      @(posedge mem_ack);
      @(negedge clock);
      instruction = rd_data;  // leitura da ROM -> instrução
      `ASSERT(db_mem_en === {3'b011, {`BYTE_NUM - 4{1'b0}}, 4'hF});
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
          @(posedge mem_ack);
          // Load: Após o ack levantar escrevo no banco simulado
          if (!opcode[5]) begin
            wr_reg_en = 1'b1;
            reg_data  = rd_data;
          end
          @(negedge clock);
          `ASSERT(db_mem_en === mem_en);
          // Caso load -> confiro a leitura
          if (!opcode[5]) `ASSERT(DUT.DF.rd === reg_data);
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
          pc_imm    = pc + immediate;
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
          if (opcode[3]) pc_imm = mem_addr + immediate;  // JAL
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
          aluA = opcode[3] ? {{32{A[31]}}, A[31:0]} : A;
          aluB = opcode[3] ? {{32{B[31]}}, B[31:0]} : B;
          if (opcode[5]) reg_data = ULA_function(aluA, aluB, {funct7[0], funct7[5], funct3});
          else if (funct3 === 3'b101) reg_data = ULA_function(aluA, immediate, {funct7[0] &
                                                  (opcode != 7'b0010011), funct7[5], funct3});
          else reg_data = ULA_function(aluA, immediate, {2'b00, funct3});
          // opcode[3] = 1'b1 -> RV64I
          if (opcode[3]) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
          // Verifico reg_data
          `ASSERT(reg_data === DUT.DF.rd);
          // Verifico se os enables estão desligados
          `ASSERT(db_mem_en === 0);
          next_pc = pc + 4;
        end
        // FENCE
        7'b0001111: begin
          // Conservativo: NOP
          wr_reg_en = 1'b0;
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
            if(csr_privilege_mode >= funct7[4:3]) begin
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
        default: begin // Illegal
          // Confiro se a memória está inativada
          `ASSERT(db_mem_en === 0);
        end
      endcase
    end
  endtask

  // testar o DUT
  initial begin : Testbench
    $display("SOT!");
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      trap_en = 1'b0;
      @(negedge clock);
      case (estado)
        Fetch:   DoFetch;
        Decode:  DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      if(estado === Execute) trap_en = 1'b1;
      else trap_en = 1'b0;
      #1;
      `ASSERT(DUT.DF._trap === csr_trap);
      `ASSERT(DUT.privilege_mode === csr_privilege_mode);
      _trap = csr_trap;
      _trap_addr = trap_addr;
      @(posedge clock);
      // Atualizando estado  e pc
      estado = (estado + 1) % 3;
      pc = _trap ? trap_addr : next_pc;
      next_pc = pc;
    end
    $stop;
  end
endmodule
