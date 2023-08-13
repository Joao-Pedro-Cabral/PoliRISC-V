//
//! @file   Dataflow.v
//! @brief  Dataflow do RV32I/RV64I
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module Dataflow (
    // Common
    input wire clock,
    input wire reset,
    // Memory
    input wire [`DATA_SIZE-1:0] rd_data,
    output wire [`DATA_SIZE-1:0] wr_data,
    output wire [`DATA_SIZE-1:0] mem_addr,
    // From Control Unit
    input wire alua_src,
    input wire alub_src,
`ifdef RV64I
    input wire aluy_src,
`endif
    input wire [2:0] alu_src,
    input wire sub,
    input wire arithmetic,
    input wire alupc_src,
    input wire pc_src,
    input wire pc_en,
    input wire [1:0] wr_reg_src,
    input wire wr_reg_en,
    input wire ir_en,
    input wire mem_addr_src,
    // Interrupts/Exceptions from UC
    input wire ecall,
    input wire illegal_instruction,
    // Trap Return
`ifdef TrapReturn
    input wire mret,
    input wire sret,
`endif
    // Interrupts from Memory
    input wire external_interrupt,
    input wire [`DATA_SIZE-1:0] mem_msip,
    input wire [`DATA_SIZE-1:0] mem_ssip,
    input wire [63:0] mem_mtime,
    input wire [63:0] mem_mtimecmp,
`ifdef ZICSR
    input wire csr_wr_en,
    input wire [1:0] csr_op,
    input wire csr_imm,
`endif
    // To Control Unit
    output wire [6:0] opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire zero,
    output wire negative,
    output wire carry_out,
    output wire overflow,
    output wire trap,
    output wire [1:0] privilege_mode
);
  // Fios intermediários
  // Register File
  wire [           4:0] reg_addr_source_1;
  wire [`DATA_SIZE-1:0] reg_data_source_1;
  wire [`DATA_SIZE-1:0] reg_data_source_2;
  wire [`DATA_SIZE-1:0] reg_data_destiny;
  wire [`DATA_SIZE-1:0] muxpc4_data_out;  // PC + 4 or read_data
  // Extensor de Imediato
  wire [`DATA_SIZE-1:0] immediate;
  // ULA
  wire [`DATA_SIZE-1:0] aluA;
  wire [`DATA_SIZE-1:0] aluB;
  wire [`DATA_SIZE-1:0] aluY;
  wire [`DATA_SIZE-1:0] muxaluY_out;  // aluY or sign_extended(aluY[31:0])
  // Somador PC + 4
  wire [`DATA_SIZE-1:0] pc_plus_4;
  wire [`DATA_SIZE-1:0] cte_4 = 4;
  // Somador PC + Imediato
  wire [`DATA_SIZE-1:0] muxpc_reg_out;  // PC or Rs1
  wire [`DATA_SIZE-1:0] muxpc_immediate_out;  // Immediate
  wire [`DATA_SIZE-1:0] pc_plus_immediate;
  // Mux PC
  wire [`DATA_SIZE-1:0] muxpc_out;
  // PC
  wire [`DATA_SIZE-1:0] pc;
  // Instruction Register(IR)
  wire [          31:0] ir;
  // CSR
  wire                  _trap;
  wire [           1:0] _privilege_mode;
  // Trap Return
`ifdef TrapReturn
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
`endif
  // ZICSR
`ifdef ZICSR
  wire [`DATA_SIZE-1:0] csr_rd_data;
  wire [`DATA_SIZE-1:0] csr_wr_data;
  wire [`DATA_SIZE-1:0] csr_aux_wr;
`endif

  // Instanciação de Componentes
  // Register File
`ifdef ZICSR  // Com ZICSR há 4 possíveis origens do reg_data_destiny
  gen_mux #(
      .size(`DATA_SIZE),
      .N(2)
  ) mux11 (
      .A({pc_plus_4, rd_data, csr_rd_data, muxaluY_out}),
      .S(wr_reg_src),
      .Y(reg_data_destiny)
  );
`else  // Sem ZICSR: 3 origens -> Economizar 1 reg
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxpc4_data (
      .A(rd_data),
      .B(pc_plus_4),
      .S(wr_reg_src[0]),
      .Y(muxpc4_data_out)
  );
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxreg_destiny (
      .A(muxaluY_out),
      .B(muxpc4_data_out),
      .S(wr_reg_src[1]),
      .Y(reg_data_destiny)
  );
`endif
  register_file #(
      .size(`DATA_SIZE),
      .N(5)
  ) int_reg_state (
      .clock(clock),
      .reset(reset),
      .write_enable(wr_reg_en),
      .read_address1(reg_addr_source_1),
      .read_address2(ir[24:20]),
      .write_address(ir[11:7]),
      .write_data(reg_data_destiny),
      .read_data1(reg_data_source_1),
      .read_data2(reg_data_source_2)
  );
  // ULA
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxaluA (
      .A(reg_data_source_1),
      .B(pc),
      .S(alua_src),
      .Y(aluA)
  );
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxaluB (
      .A(reg_data_source_2),
      .B(immediate),
      .S(alub_src),
      .Y(aluB)
  );

`ifdef RV64I
  mux2to1 #(
      .size(32)
  ) muxaluY (
      .A(aluY[`DATA_SIZE-1:32]),
      .B({32{aluY[31]}}),
      .S(aluy_src),
      .Y(muxaluY_out[`DATA_SIZE-1:32])
  );
`endif

  ULA #(
      .N(`DATA_SIZE)
  ) alu (
      .A(aluA),
      .B(aluB),
      .seletor(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .Y(aluY),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow)
  );
  // Somador PC + 4
  sklansky_adder #(
      .INPUT_SIZE(`DATA_SIZE)
  ) pc_4 (
      .A(pc),
      .B(cte_4),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_4)
  );
  // Somador PC + Imediato
  sklansky_adder #(
      .INPUT_SIZE(`DATA_SIZE)
  ) pc_immediate (
      .A(muxpc_reg_out),
      .B(muxpc_immediate_out),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_immediate)
  );
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxpc_reg (
      .A(pc),
      .B({reg_data_source_1[`DATA_SIZE-1:1], 1'b0}),
      .S(alupc_src),
      .Y(muxpc_reg_out)
  );
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxpc_immediate (
      .A({immediate[`DATA_SIZE-2:0], 1'b0}),
      .B({immediate[`DATA_SIZE-1:1], 1'b0}),
      .S(alupc_src),
      .Y(muxpc_immediate_out)
  );
  // PC
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxpc (
      .A(pc_plus_4),
      .B(pc_plus_immediate),
      .S(pc_src),
      .Y(muxpc_out)
  );

  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) pc_register (
      .clock(clock),
      .reset(reset),
      .enable(pc_en),
      .D(muxpc_out),
      .Q(pc)
  );
  // Immediate Extender
  ImmediateExtender #(
      .N(`DATA_SIZE)
  ) estende_imediato (
      .instruction(ir),
      .immediate  (immediate)
  );
  // Instruction Register -> Borda de Descida!
  register_d #(
      .N(32),
      .reset_value(0)
  ) instru_register (
      .clock(clock),
      .reset(reset),
      .enable(ir_en),
      .D(rd_data[31:0]),
      .Q(ir)
  );
  // Memory
  mux2to1 #(
      .size(`DATA_SIZE)
  ) muxmem_addr (
      .A(pc),
      .B(aluY),
      .S(mem_addr_src),
      .Y(mem_addr)
  );
  // CSR
  csr csr_bank (
      .clock(clock),
      .reset(reset),
      // Interrupt/Exception Signals
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .mem_msip(|mem_msip),
      .mem_ssip(|mem_ssip),
      .mem_mtime(mem_mtime),
      .mem_mtimecmp(mem_mtimecmp),
      .trap(_trap),
      .privilege_mode(_privilege_mode),
      // CSR RW interface
`ifdef ZICSR
      .wr_en(csr_wr_en & (~csr_op[1] | (|ir[19:15]))),
      .addr(ir[31:20]),
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
      .mepc(mepc),
      .sepc(sepc)
`else
      .mret(),
      .sret(),
      .mepc(),
      .sepc()
`endif
  );


  // Atribuições intermediárias
  // Mascarar LUI no Rs1
  assign reg_addr_source_1 = ir[19:15] & {5{(~(ir[4] & ir[2]))}};
  assign muxaluY_out[31:0] = aluY[31:0];

  // Zicsr
`ifdef ZICSR
  assign csr_aux_wr = csr_imm ? $unsigned(ir[19:15]) : reg_data_source_1;
  assign csr_wr_data = csr_op[1] ? (csr_op[0] ? (csr_rd_data & (~csr_aux_wr))
                        : (csr_rd_data | csr_aux_wr)) : csr_aux_wr;
`endif

  // Saídas
  // Memory
  assign wr_data = reg_data_source_2;
  // Control Unit
  assign opcode = ir[6:0];
  assign funct3 = ir[14:12];
  assign funct7 = ir[31:25];
  assign trap = _trap;
  assign privilege_mode = _privilege_mode;

endmodule
