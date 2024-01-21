
//
//! @file   control_unit_tb.v
//! @brief  Testbench da control_unit
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-03
//

// Ideia do testbench: testar ciclo a ciclo o comportamento da UC
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, CSR_mem e DF estão corretos.
// Com isso, basta testar se a UC consegue enviar os sinais corretos
// a partir dos sinais de entrada provenientes da RAM, ROM, CSR_mem e DF.
// Para isso irei verificar as saídas da UC

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

module control_unit_tb ();
  // Parâmetros determinados pelas extensões
  `ifdef RV64I
    localparam integer HasRV64I = 1;
  `else
    localparam integer HasRV64I = 0;
  `endif
  // Parâmetros do Sheets
  localparam integer NLineI = 58;
  localparam integer NColumnI = (HasRV64I == 1) ? 49 : 44;
  // Parâmetros do df_src
    // Bits do df_src que não dependem apenas do opcode
  localparam integer DfSrcSize = NColumnI - 17;  // Coluna tirando opcode, funct3 e funct7
  localparam integer NotOnlyOp = (HasRV64I == 1) ? 12: 8;
  // sinais do DUT
  // Common
  reg clock;
  reg reset;
  // Bus
  wire mem_wr_en;
  wire mem_rd_en;
  wire [`BYTE_NUM-1:0] mem_byte_en;
  wire mem_ack;
  // From Dataflow
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire zero;
  wire negative;
  wire carry_out;
  wire overflow;
  wire trap;
  wire [1:0] privilege_mode;
  wire csr_addr_exception;
  // To Dataflow
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
  wire csr_imm;
  wire [1:0] csr_op;
  wire csr_wr_en;
  wire illegal_instruction;
  // Sinais do Controlador de Memória
  wire [`DATA_SIZE-1:0] mem_addr;
  wire [`DATA_SIZE-1:0] wr_data;
  wire [`DATA_SIZE-1:0] rd_data;
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
  // Sinais intermediários de teste
  reg [NColumnI-1:0] LUT_uc[NLineI-1:0];  // UC simulada com tabela
  wire [NColumnI*NLineI-1:0] LUT_linear;  // Tabela acima linearizada
  reg [DfSrcSize-1:0] df_src;
  wire [DfSrcSize+1:0] db_df_src;  // Idem df_src, adicionando pc_en e ir_en
  reg _trap;
  // variáveis
  integer limit = 10000;  // evitar loop infinito
  localparam integer Fetch = 0, Decode = 1, Execute = 2, Reset = 5; // Estados
  integer estado = Reset;
  integer i;
  genvar j;
  // Address
  localparam integer FinalAddress = 16781308; // Final execution address
  localparam integer ExternalInterruptAddress = 16781320; // Active/Desactive External Interrupt

  // DUT
  control_unit DUT (
      .clock(clock),
      .reset(reset),
      .ir_en(ir_en),
      .mem_rd_en(mem_rd_en),
      .mem_byte_en(mem_byte_en),
      .mem_ack(mem_ack),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .trap(trap),
      .privilege_mode(privilege_mode),
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
      .mem_addr_src(mem_addr_src),
      .mem_wr_en(mem_wr_en),
      .csr_addr_exception(csr_addr_exception)
  );

  // Dataflow
  Dataflow DF (
      .clock(clock),
      .reset(reset),
      .rd_data(rd_data),
      .wr_data(wr_data),
      .ir_en(ir_en),
      .mem_addr(mem_addr),
      .alua_src(alua_src),
      .alub_src(alub_src),
    `ifdef RV64I
      .aluy_src(aluy_src),
    `endif
    `ifdef ZICSR
      .csr_imm(csr_imm),
      .csr_op(csr_op),
      .csr_wr_en(csr_wr_en),
    `endif
      .alu_src(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .alupc_src(alupc_src),
      .pc_src(pc_src),
      .pc_en(pc_en),
      .wr_reg_src(wr_reg_src),
      .wr_reg_en(wr_reg_en),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .trap(trap),
      .privilege_mode(privilege_mode),
      .mem_addr_src(mem_addr_src),
      .ecall(ecall),
    `ifdef TrapReturn
      .mret(mret),
      .sret(sret),
    `endif
      .illegal_instruction(illegal_instruction),
      .csr_addr_exception(csr_addr_exception),
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp)
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

  `ifndef TrapReturn
    assign {mret, sret} = 2'b00;
  `endif

  `ifndef ZICSR
    assign {csr_imm, csr_op, csr_wr_en} = 4'h0;
  `endif

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  // geração do LUT linear -> função não suporta array
  generate
    for (j = 0; j < NLineI; j = j + 1)
      assign LUT_linear[NColumnI*(j+1)-1:NColumnI*j] = LUT_uc[j];
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
        for (i = 3; i < 43; i = i + 1) begin
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
        for (i = 43; i < 58; i = i + 1)
        if(opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
             funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3] &&
             funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end
      if(temp == 0) temp[DfSrcSize-1] = 1'b1; // Não achou a instrução
      find_instruction = temp;
    end
  endfunction

  // Concatenação dos sinais produzidos pela UC
  assign db_df_src = {
    // Sinais determinados pelo estado
    pc_en, // DfSrcSize + 1
    ir_en, // DfSrcSize
    illegal_instruction, // DfSrcSize + 1
    // Sinais determinados pelo opcode
    alua_src,
    alub_src,
  `ifdef RV64I
    aluy_src,
  `endif
    alu_src,
    sub,
    arithmetic,
    alupc_src,
    wr_reg_src,
    mem_addr_src,
    ecall,
    mret,
    sret,
    csr_imm,
    csr_op,
    csr_wr_en,
    // Sinais que não dependem apenas do opcode
    pc_src,  // NotOnlyOp -1
    wr_reg_en,  // NotOnlyOp -2
    mem_wr_en,
    mem_rd_en,
    mem_byte_en
  };

  // Always to finish the simulation
  always @(posedge mem_wr_en) begin
    if(mem_addr == FinalAddress) begin // Final write addr
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

  // Não uso apenas @(posedge mem_ack), pois pode haver traps a serem tratadas!
  task automatic wait_mem();
    begin
      forever begin
        @(mem_ack, trap);
        if(trap || mem_ack) disable wait_mem;
      end
    end
  endtask

  task automatic DoReset();
    begin
      reset = 1'b1;
      `ASSERT(db_df_src === 0); // Idle
      @(posedge clock);
      @(negedge clock);
      reset = 1'b0;
      `ASSERT(db_df_src === 0); // Pós reset -> Idle
    end
  endtask

  task automatic DoFetch();
    begin
      `ASSERT(db_df_src === {1'b1,{`BYTE_NUM-4{1'b0}},4'hF});
      // Trap não muda o df_src ainda
      if(trap) disable DoFetch;
      wait_mem;
      @(negedge clock);
      // Trap -> UC ainda está no Fetch1
      if(!mem_ack) `ASSERT(db_df_src === {1'b1,{`BYTE_NUM-4{1'b0}},4'hF});
      // Após a memória abaixar confiro se o ir_en levantou e o instruction mem en desceu
      else `ASSERT(db_df_src === {2'b01, {DfSrcSize - 4{1'b0}}, 4'hF});
    end
  endtask

  task automatic DoDecode();
    begin
      df_src = find_instruction(opcode, funct3, funct7, LUT_linear); // obter saídas pelo sheets
      // Verifico se algum enable está erroneamente habilitado
      `ASSERT(db_df_src[DfSrcSize+1:DfSrcSize] === 0);
      // Illegal instruction já pode ter levantado
      `ASSERT(db_df_src[DfSrcSize-1] === df_src[DfSrcSize-1]);
      `ASSERT(db_df_src[DfSrcSize-2:0] === 0);
    end
  endtask

  task automatic DoExecute();
    begin
      if (!csr_addr_exception) begin
        `ASSERT({1'b0, df_src[DfSrcSize-1:NotOnlyOp]} === db_df_src[DfSrcSize:NotOnlyOp]);
        `ASSERT(df_src[NotOnlyOp-3:0] === db_df_src[NotOnlyOp-3:0]);
        // Não testo pc_src para instruções do tipo B
        if (opcode !== 7'b1100011) `ASSERT(df_src[NotOnlyOp-1] === db_df_src[NotOnlyOp-1]);
        // Load -> não posso usar o sheets!(wr_reg_en só habilita depois)
        if (opcode !== 7'b0000011) begin
          `ASSERT(db_df_src[NotOnlyOp-2] === df_src[NotOnlyOp-2]);
        end else begin
          `ASSERT(db_df_src[NotOnlyOp-2] === 1'b0);
        end
      end
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          wait_mem;
          // Espero o busy abaixar para verificar os enables
          @(negedge clock);
          // Trap -> UC ainda está no Store1/Load1
          if(!mem_ack) begin
            `ASSERT({2'h0, df_src[DfSrcSize-1:NotOnlyOp-1]} === db_df_src[DfSrcSize+1:NotOnlyOp-1]);
            `ASSERT({1'b0, df_src[NotOnlyOp-3:0]} === db_df_src[NotOnlyOp-2:0]);
          end
          else begin
            `ASSERT(pc_en === 1'b1);
            `ASSERT(wr_reg_en === df_src[NotOnlyOp-2]);
            `ASSERT(mem_rd_en === 1'b0);
            `ASSERT(mem_wr_en === 1'b0);
          end
        end
        // Branch(B*)
        7'b1100011: begin
          `ASSERT(pc_en === 1'b1);
          // testo pc_src de acordo com as flags do DF
          if (funct3[2:1] === 2'b00) begin
            if (zero ^ funct3[0] === 1'b1) begin
              `ASSERT(pc_src === 1'b1);
            end else begin
              `ASSERT(pc_src === 1'b0);
            end
          end else if (funct3[2:1] === 2'b10) begin
            if (negative ^ overflow ^ funct3[0] === 1'b1) begin
              `ASSERT(pc_src === 1'b1);
            end else begin
              `ASSERT(pc_src === 1'b0);
            end
          end else if (funct3[2:1] === 2'b11) begin
            if (carry_out ~^ funct3[0] === 1'b1) begin
              `ASSERT(pc_src === 1'b1);
            end else begin
              `ASSERT(pc_src === 1'b0);
            end
          end else begin
            $display("Error B-type: Invalid funct3! Funct3 : %x", funct3);
            $stop;
          end
        end
        // JAL, JALR, U-type & ULA R/I-type
        7'b1101111, 7'b1100111, 7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011,
        7'b0110111, 7'b0010111: begin
          `ASSERT(pc_en === 1'b1);
        end
        // ECALL, MRET, SRET, CSRR* (SYSTEM)
        7'b1110011: begin
          if(funct3[1:0] !== 2'b00 && csr_addr_exception) `ASSERT(illegal_instruction === 1'b1);
          if(privilege_mode >= funct7[4:3]) begin
            `ASSERT(pc_en === (|funct3));
          end else begin
            `ASSERT(pc_en === 1'b0);
          end
        end
        default: begin
          // Fim do programa -> última instrução 0000000
          if (DF.pc === `program_size - 4) $display("End of program!");
          else $display("Error pc: pc = %x", DF.pc);
          $stop;
        end
      endcase
    end
  endtask

  // testar o DUT
  initial begin : Testbench
    $display("Program  size: %d", `program_size);
  `ifdef RV64I
    $readmemb("./MIFs/core/core/RV64I.mif", LUT_uc);
  `else
    $readmemb("./MIFs/core/core/RV32I.mif", LUT_uc);
  `endif
    $display("SOT!");
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      @(negedge clock);
      case(estado)
        Fetch: DoFetch;
        Decode: DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      #1;
      _trap = trap;
      @(posedge clock);
      // Atualizando estado
      if(_trap) estado = Fetch;
      else estado = (estado + 1)%3;
    end
  end
endmodule
