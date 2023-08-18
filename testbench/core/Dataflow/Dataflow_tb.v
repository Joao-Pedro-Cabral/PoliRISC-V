//
//! @file   Dataflow_tb.v
//! @brief  Testbench do Dataflow
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-23
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do Dataflow
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato e Banco de Registradores estão corretos.
// Com isso, basta testar se o Dataflow consegue interligar os componentes
// e se os componentes funcionam corretamente.
// Para isso irei verificar as saídas do DF (principalmente pc e reg_data,
// pois elas determinam o contexto)

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

module Dataflow_tb ();
  // Parâmetros determinados pelas extensões
  `ifdef RV64I
    localparam integer RV64IExtension = 5;
    localparam integer HasRV64I = 1;
  `else
    localparam integer RV64IExtension = 0;
    localparam integer HasRV64I = 0;
  `endif
  // Parâmetros do Sheets
  localparam integer NLineI = 52;
  localparam integer NColumnI = 40 + RV64IExtension;
  // Parâmetros do df_src
    // Bits do df_src que não dependem apenas do opcode
  localparam integer DfSrcSize = NColumnI - 17;  // Coluna tirando opcode, funct3 e funct7
  localparam integer NotOnlyOp = (HasRV64I == 1) ? 12: 8;
  // Endereço da Trap
  localparam integer TrapAddress = 1000;
  // sinais do DUT
  // Common
  reg clock;
  reg reset;
  // Bus
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] wr_data;
  wire [`DATA_SIZE-1:0] mem_addr;
  wire mem_busy;
  wire mem_rd_en;
  wire mem_wr_en;
  wire [`BYTE_NUM-1:0] mem_byte_en;
  // From Control Unit (LUT_uc)
  wire alua_src;
  wire alub_src;
`ifdef RV64I
  wire aluy_src;
`endif
  wire [2:0] alu_src;
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
  wire illegal_instruction;
  // To Control Unit
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire zero;
  wire negative;
  wire carry_out;
  wire overflow;
  wire trap;
  wire [1:0] privilege_mode;
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
  wire [2:0] csr_mem_addr;
  wire [`DATA_SIZE-1:0] csr_mem_wr_data;
  wire [`DATA_SIZE-1:0] csr_mem_rd_data;
  wire [`DATA_SIZE-1:0] msip;
  wire [`DATA_SIZE-1:0] ssip;
  wire [63:0] mtime;
  wire [63:0] mtimecmp;
  wire csr_mem_busy;
  // Dispositivos
  wire external_interrupt = 1'b0;
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
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_ssip(ssip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .trap(trap),
      .privilege_mode(privilege_mode)
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
      .write_enable(wr_reg_en && !trap),
      .read_address1(instruction[19:15]),
      .read_address2(instruction[24:20]),
      .write_address(instruction[11:7]),
      .write_data(reg_data),
      .read_data1(A),
      .read_data2(B)
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
        for (i = 3; i < 37; i = i + 1) begin
          if (opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
              funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3]) begin
            // SRLI e SRAI: funct7
            if (funct3 === 3'b101 && opcode[4] == 1'b1) begin
              if (funct7 == LUT_linear[(NColumnI*(i+1)-17)+:7])
                temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
            end else temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
          end
        end
      end  // R: opcode, funct3 e funct7
      else if (opcode === 7'b0111011 || opcode === 7'b0110011) begin
        for (i = 37; i < 52; i = i + 1)
        if(opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
             funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3] &&
             funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end
      if(temp == 0) temp[DfSrcSize-1] = 1'b1; // Não achou a instrução
      find_instruction = temp;
    end
  endfunction

  // função que simula o comportamento da ULA
  function automatic [`DATA_SIZE-1:0] ULA_function(
      input reg [`DATA_SIZE-1:0] A, input reg [`DATA_SIZE-1:0] B, input reg [3:0] seletor);
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
      pc_en, ir_en,
      // Exceção -> Instrução não existe ou falta privilégio (não está no sheets!)
      illegal_instruction,
      // Sinais determinados pelo opcode
      alua_src, alub_src,
    `ifdef RV64I
      aluy_src,
    `endif
      alu_src, sub, arithmetic, alupc_src, wr_reg_src, mem_addr_src, ecall, mret, sret,
      // Sinais que não dependem apenas do opcode
      pc_src,  // Pressuponho que seja NotOnlyOp -1
      wr_reg_en,  // Pressuponho que seja NotOnlyOp -2
      mem_wr_en, mem_rd_en, mem_byte_en} = db_df_src;

  // Não uso apenas @(posedge mem_busy), pois pode haver traps a serem tratadas!
  task automatic wait_mem();
    reg num_edge = 1'b0;
  begin
    forever begin
      @(mem_busy, trap);
      // num_edge = 1 -> Agora é descida
      if(trap || (num_edge == 1'b1)) disable wait_mem;
      else if(mem_busy == 1'b1) num_edge = 1'b1; //Subida
    end
  end
  endtask

  task automatic DoReset();
  begin
    db_df_src = 0;
    @(negedge clock);
    reset = 1'b1;
    @(posedge clock);
    @(negedge clock);
    reset = 1'b0;
    next_pc = pc;
    @(posedge clock);
  end
  endtask

  task automatic DoFetch();
  begin
    db_df_src = {1'b1, {`BYTE_NUM - 4{1'b0}}, 4'hF};
    @(negedge clock);
    // Testo o endereço de acesso a Memória de Instrução
    `ASSERT(pc === mem_addr);
    wait_mem;
    if(trap) disable DoFetch; // Trap -> Recomeçar Fetch
    @(negedge clock);
    db_df_src   = {2'b01, {DfSrcSize - 4{1'b0}}, 4'hF};
    instruction = rd_data;
    @(posedge clock);
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
    db_df_src[DfSrcSize-1] = df_src[DfSrcSize-1]; // illegal_instruction
    @(posedge clock);
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
        wait_mem;
        if(trap) disable DoExecute; // Trap -> Fetch
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
        pc_imm                 = pc + (immediate << 1);
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
        if (opcode[3]) pc_imm = pc + (immediate << 1);  // JAL
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
        if (opcode[5]) reg_data = ULA_function(A, B, {funct7[5], funct3});
        else if (funct3 === 3'b101) reg_data = ULA_function(A, immediate, {funct7[5], funct3});
        else reg_data = ULA_function(A, immediate, {1'b0, funct3});
        // opcode[3] = 1'b1 -> RV64I
        if (opcode[3] === 1'b1) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
        next_pc = pc + 4;
        // Verifico reg_data
        `ASSERT(reg_data === DUT.rd);
      end
      // Ecall, MRET, SRET (SYSTEM)
      7'b1110011: begin  // Ecall
        db_df_src[NotOnlyOp-1:NotOnlyOp-2] = 2'b00;
        db_df_src[DfSrcSize+1] = 1'b0;
        @(negedge clock);
        // Trap
        next_pc = TrapAddress;
        `ASSERT(trap === 1'b1);
      end
      default: begin
        // Fim do programa -> última instrução 0000000
        if (pc === `program_size - 4) $display("End of program!");
        else $display("Error pc: pc = %x", pc);
        @(negedge clock);
        $stop;
      end
    endcase
    @(posedge clock);
  end
  endtask

  // testar o DUT
  initial begin
    $display("Program  size: %d", `program_size);
  `ifdef RV64I
    $readmemb("./MIFs/core/core/RV64I.mif", LUT_uc);
  `else
    $readmemb("./MIFs/core/core/RV32I.mif", LUT_uc);
  `endif
    $display("SOT!");
    // fim do reset
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      case(estado)
        Fetch: DoFetch;
        Decode: DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      // Atualizando estado  e pc
      if(trap) begin
        estado = Fetch;
        pc = TrapAddress;
      end else begin
        estado = (estado + 1)%3;
        pc = next_pc;
      end
      next_pc = pc;
    end
    $stop;
  end
endmodule
