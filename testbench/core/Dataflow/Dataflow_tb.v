//
//! @file   Dataflow_tb.v
//! @brief  Testbench do Dataflow
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-23
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do Dataflow
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato, Banco de Registradores, CSR e CSR_mem estão corretos.
// Com isso, basta testar se o Dataflow consegue interligar os componentes
// e se os componentes funcionam corretamente.
// Para isso irei verificar as saídas do DF (principalmente pc e reg_data,
// pois elas determinam o contexto)

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

module Dataflow_tb ();
  // Parâmetros determinados pelas extensões
  `ifdef RV64I
    localparam integer HasRV64I = 1;
  `else
    localparam integer HasRV64I = 0;
  `endif
  // Parâmetros do Sheets
  localparam integer NLineI = 72;
  localparam integer NColumnI = (HasRV64I == 1) ? 50 : 45;
  // Parâmetros do df_src
    // Bits do df_src que não dependem apenas do opcode
  localparam integer DfSrcSize = NColumnI - 17;  // Coluna tirando opcode, funct3 e funct7
  localparam integer NotOnlyOp = (HasRV64I == 1) ? 12: 8;
  // sinais do DUT
  // Common
  reg clock;
  reg reset;
  // Bus
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] wr_data;
  wire [`DATA_SIZE-1:0] mem_addr;
  wire mem_ack;
  wire mem_rd_en;
  wire mem_wr_en;
  wire [`BYTE_NUM-1:0] mem_byte_en;
  // From Control Unit (LUT_uc)
  wire alua_src;
  wire alub_src;
`ifdef RV64I
  wire aluy_src;
`endif
  wire [3:0] alu_src;
  wire sub;
  wire arithmetic;
  wire alupc_src;
  wire pc_src;
  wire pc_en;
  wire [1:0] wr_reg_src;
  wire wr_reg_en;
  wire ir_en;
  wire mem_addr_src;
  wire ecall;
  wire mret;
  wire sret;
  wire csr_imm;
  wire [1:0] csr_op;
  wire csr_wr_en;
  wire illegal_instruction;
  // To Control Unit
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire zero;
  wire negative;
  wire carry_out;
  wire overflow;
  wire [1:0] privilege_mode;
  wire csr_addr_exception;
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
  wire csr_trap;
  wire [`DATA_SIZE-1:0] trap_addr;
  wire [1:0] csr_privilege_mode;
  wire csr_addr_exception_;
  // Sinais intermediários de teste
  reg [NColumnI-1:0] LUT_uc[NLineI-1:0];  // UC simulada com tabela(google sheets)
  wire [NColumnI*NLineI-1:0] LUT_linear;  // Tabela acima linearizada
  reg [DfSrcSize-1:0] df_src;  // sinais da UC para o df -> sheets
  reg [DfSrcSize+1:0] db_df_src;  // sinais da UC para o df
  reg [31:0] instruction = 0;  // instrução a ser executada
  wire [`DATA_SIZE-1:0] immediate;  // Saída do Extensor de Imediato do TB
  wire [`DATA_SIZE-1:0] A_immediate;  // A + imediato
  reg [`DATA_SIZE-1:0] reg_data;  // write data do banco de registradores
  wire [`DATA_SIZE-1:0] A;  // read data 1 do banco de registradores
  wire [`DATA_SIZE-1:0] B;  // read data 2 do banco de registradores
  reg [`DATA_SIZE-1:0] pc = 0;  // pc -> Acessa memória de instrução
  reg [`DATA_SIZE-1:0] next_pc = 0; // próximo valor do pc
  reg [`DATA_SIZE-1:0] pc_imm;  // pc + (imediato << 1) OU {A + immediate[N-1:1], 0}
  reg [`DATA_SIZE-1:0] pc_4;  // pc + 4
  reg _trap; // csr_trap antes da borda de subida do clock
  reg [`DATA_SIZE-1:0] _trap_addr; // trap_addr antes da borda de subida do clock
  // flags da ULA ->  geradas de forma simulada
  wire zero_;
  wire negative_;
  wire carry_out_;
  wire overflow_;
  wire [`DATA_SIZE-1:0] xorB;
  wire [`DATA_SIZE-1:0] add_sub;
  // variáveis
  integer limit = 10000;  // número máximo de iterações a serem feitas(evitar loop infinito)
  localparam integer Fetch = 0, Decode = 1, Execute = 2, Reset = 5; // Estados
  integer estado = Reset;
  integer i;
  genvar j;
  // Address
  localparam integer FinalAddress = 16781308; // Final execution address
  localparam integer ExternalInterruptAddress = 16781320; // Active/Desactive External Interrupt

  // DUT
  Dataflow DUT (
      .clock(clock),
      .reset(reset),
      .rd_data(rd_data),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .alua_src(alua_src),
      .alub_src(alub_src),
    `ifdef RV64I
      .aluy_src(aluy_src),
    `endif
      .alu_src(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .alupc_src(alupc_src),
      .pc_src(pc_src),
      .pc_en(pc_en),
      .wr_reg_src(wr_reg_src),
      .wr_reg_en(wr_reg_en),
      .ir_en(ir_en),
      .mem_addr_src(mem_addr_src),
      .ecall(ecall),
    `ifdef TrapReturn
      .mret(mret),
      .sret(sret),
    `endif
    `ifdef ZICSR
      .csr_imm(csr_imm),
      .csr_op(csr_op),
      .csr_wr_en(csr_wr_en),
    `endif
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .csr_addr_exception(csr_addr_exception),
      .privilege_mode(privilege_mode)
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
      .cpu_CYC_I(mem_rd_en | mem_wr_en),
      .cpu_STB_I(mem_rd_en | mem_wr_en),
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
      .write_enable(wr_reg_en && !(wr_reg_src == 2'b01 && csr_addr_exception_)),
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
      .trap_en(pc_en),
      // Interrupt/Exception Signals
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .mem_msip(|msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp),
      .trap_addr(trap_addr),
      .trap(csr_trap),
      .privilege_mode(csr_privilege_mode),
      .addr_exception(csr_addr_exception_),
      .pc(pc),
      .instruction(instruction),
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

  // geração do LUT linear -> função não suporta array
  generate
    for (j = 0; j < NLineI; j = j + 1) assign LUT_linear[NColumnI*(j+1)-1:NColumnI*j] = LUT_uc[j];
  endgenerate

  // função para determinar os seletores(sinais provenientes da UC) a partir do opcode, funct3 e funct7
  function automatic [DfSrcSize-1:0] find_instruction(
      input reg [6:0] opcode, input reg [2:0] funct3, input reg [6:0] funct7,
      input reg [NColumnI*NLineI-1:0] LUT_linear);
    integer i;
    reg [DfSrcSize-1:0] temp;
    begin
      temp = 0;
      // os valores de i nos for estão ligados a como o mif foi montado com base no sheets
      // U,J : apenas opcode
      if (opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
        for (i = 0; i < 3; i = i + 1)
        if (opcode === LUT_linear[(NColumnI*(i+1)-7)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end  // I, S, B: opcode e funct3
      else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 ||
              opcode === 7'b0010011 || opcode === 7'b0011011 || opcode === 7'b1100111 ||
              opcode === 7'b1110011) begin
        for (i = 3; i < 44; i = i + 1) begin
          if (opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
              funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3]) begin
            // SRLI e SRAI: funct7
            if (opcode == 7'b0010011 && funct3 === 3'b101) begin
              if (funct7[6:1] == LUT_linear[(NColumnI*(i+1)-16)+:6])
                temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
            end // ECALL + Privilegied
            else if(opcode === 7'b1110011) begin
              // ECALL, MRET, SRET
              if(funct3 === 3'b000 && funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7]) begin
                if(funct7 === 7'b0) temp = LUT_linear[NColumnI*i+:(NColumnI-17)]; // ECALL
                // MRET, SRET
                else if({funct7[6:5], funct7[3:0]} === 6'b001000 &&
                (privilege_mode[0] && (privilege_mode[1] | !funct7[4])))
                  temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
              end
              // Zicsr
              else if(funct3 !== 3'b000 && privilege_mode >= funct7[4:3])
                temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
            end else temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
          end
        end
      end  // R: opcode, funct3 e funct7
      else if (opcode === 7'b0111011 || opcode === 7'b0110011) begin
        for (i = 44; i < 72; i = i + 1)
        if(opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
             funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3] &&
             funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end
      if(temp == 0 && opcode !== 7'b0001111) temp[DfSrcSize-1] = 1'b1; // Não achou a instrução
      find_instruction = temp;
    end
  endfunction

  // função que simula o comportamento da ULA
  function automatic [`DATA_SIZE-1:0] ULA_function(
    input reg [`DATA_SIZE-1:0] A, input reg [`DATA_SIZE-1:0] B, input reg [4:0] seletor);
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
        5'b10001: ULA_function = ($signed(A) * $signed(B))[2*`DATA_SIZE-1:`DATA_SIZE]; // MULH
        5'b10010: ULA_function = ($signed(A) * B)[2*`DATA_SIZE-1:`DATA_SIZE]; // MULHSU
        5'b10011: ULA_function = (A * B)[2*`DATA_SIZE-1:`DATA_SIZE]; // MULHU
        5'b10100: ULA_function = $signed(A) / $signed(B); // DIV
        5'b10101: ULA_function = A / B; // DIVU
        5'b10110: ULA_function = $signed(A) % $signed(B); // REM
        5'b10111: ULA_function = A % B; // REMU
        default: ULA_function = 0;
      endcase
    end
  endfunction

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

  // flags da ULA -> Apenas conferidas para B-type
  assign xorB = B ^ {`DATA_SIZE{1'b1}};
  assign {carry_out_, add_sub} = A + xorB + 1;
  assign zero_ = ~(|add_sub);
  assign negative_ = add_sub[`DATA_SIZE-1];
  assign overflow_ = (~(A[`DATA_SIZE-1] ^ B[`DATA_SIZE-1] ^ sub))
                   & (A[`DATA_SIZE-1] ^ add_sub[`DATA_SIZE-1]);

  // geração do A_immediate
  assign A_immediate = A + immediate;

  // sinais do DF vindos da UC
  assign {
      // Sinais determinados pelo estado
      pc_en, // DfSrcSize + 1
      ir_en, // DfSrcSize
      illegal_instruction, // DfSrcSize - 1
      // Sinais determinados pelo opcode
      alua_src, alub_src,
    `ifdef RV64I
      aluy_src,
    `endif
      alu_src, sub, arithmetic, alupc_src, wr_reg_src, mem_addr_src, ecall, mret, sret, csr_imm,
      csr_op, csr_wr_en,
      // Sinais que não dependem apenas do opcode
      pc_src,  // NotOnlyOp -1
      wr_reg_en,  // NotOnlyOp -2
      mem_wr_en, mem_rd_en, mem_byte_en} = db_df_src;

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
      db_df_src = 0;
      reg_data = 0;
      csr_wr_data = 0;
      pc_4 = 0;
      pc_imm = 0;
      @(negedge clock);
      reset = 1'b1;
      @(posedge clock);
      @(negedge clock);
      reset = 1'b0;
      next_pc = pc;
    end
  endtask

  task automatic DoFetch();
    begin
      // Evitar bugs de sincronismos com a memória
      db_df_src = 0;
      @(negedge clock);
      db_df_src = {1'b1, {`BYTE_NUM - 4{1'b0}}, 4'hF};
      // Testo o endereço de acesso a Memória de Instrução
      `ASSERT(pc === mem_addr);
      @(posedge mem_ack);
      @(negedge clock);
      db_df_src   = {2'b01, {DfSrcSize - 4{1'b0}}, 4'hF};
      instruction = rd_data;
    end
  endtask

  task automatic DoDecode();
    begin
      @(negedge clock);
      // Checo opcode, funct3 e funct7
      `ASSERT(opcode === instruction[6:0]);
      `ASSERT(funct3 === instruction[14:12]);
      `ASSERT(funct7 === instruction[31:25]);
      // Obtenho os sinais da UC -> Sheets
      df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
      db_df_src = 0;
    end
  endtask

  task automatic DoExecute();
    begin
      // Atribuo ao tb os valores do sheets
      db_df_src[DfSrcSize:NotOnlyOp] = {1'b0, df_src[DfSrcSize-1:NotOnlyOp]};
      db_df_src[NotOnlyOp-3:0] = df_src[NotOnlyOp-3:0];
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          db_df_src[NotOnlyOp-1] = df_src[NotOnlyOp-1];
          @(negedge clock);
          // Confiro o endereço de acesso
          `ASSERT(mem_addr === A + immediate);
          // Caso seja store -> confiro a palavra a ser escrita
          if (opcode[5]) `ASSERT(wr_data === B);
          @(posedge mem_ack);
          db_df_src[`BYTE_NUM+1:`BYTE_NUM] = 2'b00;
          // caso necessário escrevo no banco
          db_df_src[NotOnlyOp-2] = df_src[NotOnlyOp-2];
          db_df_src[DfSrcSize+1] = 1'b1; // Incremento PC
          if (!opcode[5]) reg_data = rd_data;
          @(negedge clock);
          // Caso load -> confiro a leitura
          if (!opcode[5]) `ASSERT(DUT.rd === reg_data);
          next_pc = pc + 4;
        end
        // Branch(B*)
        7'b1100011: begin
          @(negedge clock);
          // Decido o valor de pc_src com base em funct3 e no valor das flags simuladas
          if (funct3[2:1] === 2'b00) db_df_src[NotOnlyOp-1] = zero_ ^ funct3[0];
          else if (funct3[2:1] === 2'b10) db_df_src[NotOnlyOp-1] = negative_ ^ overflow ^ funct3[0];
          else if (funct3[2:1] === 2'b11) db_df_src[NotOnlyOp-1] = carry_out_ ~^ funct3[0];
          else begin
            $display("Error B-type: Invalid funct3! funct3 : %x", funct3);
            $stop;
          end
          pc_4                   = pc + 4;
          pc_imm                 = pc + immediate;
          db_df_src[DfSrcSize+1] = 1'b1;
          db_df_src[NotOnlyOp-2] = 1'b0;
          // Decido o próximo valor de pc
          if (db_df_src[NotOnlyOp-1]) next_pc = pc_imm;
          else next_pc = pc_4;
          // Confiro as flags da ULA
          `ASSERT(overflow === overflow_);
          `ASSERT(carry_out === carry_out_);
          `ASSERT(negative === negative_);
          `ASSERT(zero === zero_);
        end
        // LUI e AUIPC
        7'b0110111, 7'b0010111: begin
          // Habilito o pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          if (opcode[5]) reg_data = immediate;  // LUI
          else reg_data = pc + immediate;  // AUIPC
          next_pc = pc + 4;
          @(negedge clock);
          // Confiro se reg_data está correto
          `ASSERT(reg_data === DUT.rd);
        end
        // JAL e JALR
        7'b1101111, 7'b1100111: begin
          // Habilito pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          reg_data = pc + 4;  // escrever pc + 4 no banco -> Link
          @(negedge clock);
          if (opcode[3]) pc_imm = pc + immediate;  // JAL
          else pc_imm = {A_immediate[31:1], 1'b0};  // JALR
          next_pc = pc_imm;
          // Confiro a escrita no banco
          `ASSERT(DUT.rd === reg_data);
        end
        // ULA R/I-type
        7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
          // Habilito pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
          // Uso ULA_function para calcular o reg_data
          if (opcode[5]) reg_data = ULA_function(A, B, {funct7[0], funct7[5], funct3});
          else if (funct3 === 3'b101) reg_data = ULA_function(A, immediate, {funct7[0], funct7[5], funct3});
          else reg_data = ULA_function(A, immediate, {2'b00, funct3});
          // opcode[3] = 1'b1 -> RV64I
          if (opcode[3] === 1'b1) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
          next_pc = pc + 4;
          // Verifico reg_data
          `ASSERT(reg_data === DUT.rd);
        end
        // FENCE
        7'b0001111: begin
          // Conservativo: NOP
          db_df_src[DfSrcSize+1] = 1'b1;
          next_pc = pc + 4;
          @(negedge clock);
        end
        // ECALL, MRET, SRET, CSRR* (SYSTEM)
        7'b1110011: begin
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = df_src[NotOnlyOp-1:NotOnlyOp-2];
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
          if(funct3 === 3'b000) begin
            if(funct7 === 0) next_pc = trap_addr; // Ecall
          `ifdef TrapReturn
            else if(funct7 === 7'b0011000 && privilege_mode === 2'b11) next_pc = mepc; // MRET
            else if(funct7 === 7'b0001000 && privilege_mode[0] === 1'b1) next_pc = sepc; // SRET
          `endif
            else begin
              $display("Error SYSTEM: Invalid funct7! funct7 : %x", funct7);
              $stop;
            end
          end
        `ifdef ZICSR // Apenas aqui há ifdef, pois nem sempre DUT.csr_wr_data existe
          else if(funct3 !== 3'b100) begin // CSRR*
            reg_data = csr_rd_data;
            if(instruction[31:20] == 12'h344 || instruction[31:20] == 12'h144)
              reg_data[registradores_de_controle.SEIP] =
                csr_rd_data[registradores_de_controle.SEIP] | external_interrupt;
            if(funct3[2]) csr_wr_data = CSR_function(csr_rd_data, instruction[19:15], funct3[1:0]);
            else csr_wr_data = CSR_function(csr_rd_data, A, funct3[1:0]);
            // Sempre checo a leitura/escrita até se ela não acontecer
            if(csr_addr_exception_) db_df_src[DfSrcSize-1] = 1'b1;
            `ASSERT(csr_addr_exception === csr_addr_exception_);
            if(privilege_mode >= funct7[4:3]) begin
              `ASSERT(csr_wr_data === DUT.csr_wr_data);
              `ASSERT(reg_data === DUT.rd);
            end
            next_pc = pc + 4;
          end
        `endif
          else begin
              $display("Error SYSTEM: Invalid funct3! funct3 : %x", funct3);
              $stop;
          end
        end
        default: begin
          // Habilito pc e illegal_instruction
          db_df_src[DfSrcSize-1] = 1'b1;
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
        end
      endcase
    end
  endtask

  // testar o DUT
  initial begin
  `ifdef RV64I
    $readmemb("./MIFs/core/core/RV64I.mif", LUT_uc);
  `else
    $readmemb("./MIFs/core/core/RV32I.mif", LUT_uc);
  `endif
    $display("SOT!");
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      case(estado)
        Fetch: DoFetch;
        Decode: DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      #1;
      `ASSERT(DUT._trap === csr_trap);
      `ASSERT(privilege_mode === csr_privilege_mode);
      _trap = csr_trap;
      _trap_addr = trap_addr;
      @(posedge clock);
      // Atualizando estado  e pc
      estado = (estado + 1)%3;
      pc = _trap ? _trap_addr : next_pc;
      next_pc = pc;
    end
    $stop;
  end
endmodule
