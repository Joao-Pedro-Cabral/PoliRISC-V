
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
  wire mem_busy;
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

  // DUT
  control_unit DUT (
      .clock(clock),
      .reset(reset),
      .ir_en(ir_en),
      .mem_rd_en(mem_rd_en),
      .mem_byte_en(mem_byte_en),
      .mem_busy(mem_busy),
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
      .mem_wr_en(mem_wr_en)
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
      .external_interrupt(external_interrupt),
      .mem_msip(msip),
      .mem_ssip(ssip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(`BYTE_NUM),
      .MTIME_ADDR({32'b0, 262142*(2**12)}),    // lui 262142
      .MTIMECMP_ADDR({32'b0, 262143*(2**12)}), // lui 262143
      .MSIP_ADDR({32'b0, 262144*(2**12)}),     // lui 262144
      .SSIP_ADDR({32'b0, 262145*(2**12)})      // lui 262145
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
              else if(funct3 !== 3'b000 && privilege_mode >= funct7[6:5])
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
    if(mem_addr == 16781308) begin // Final write addr
      $display("End of program!");
      $display("Write data: 0x%x", wr_data);
      $stop;
    end
  end

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
      wait_mem;
      @(negedge clock);
      // Trap -> UC ainda está no Fetch1
      if(mem_busy) `ASSERT(db_df_src === {1'b1,{`BYTE_NUM-4{1'b0}},4'hF});
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
      if (opcode !== 0) begin
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
          if(mem_busy) begin
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
          if(privilege_mode >= funct7[6:5]) begin
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
