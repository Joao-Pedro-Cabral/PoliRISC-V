//
//! @file   Dataflow.v
//! @brief  Dataflow do RV32I/RV64I
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

`include "macros.vh"
`include "extensions.vh"

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
    input wire [3:0] alu_src,
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
    output wire csr_addr_exception,
    output wire [1:0] privilege_mode
);
  // Fios intermediários
  // Register File
  wire [           4:0] rs1_addr;
  wire [`DATA_SIZE-1:0] rs1;
  wire [`DATA_SIZE-1:0] rs2;
  wire [`DATA_SIZE-1:0] rd;
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
  wire [`DATA_SIZE-1:0] pc_plus_immediate;
  // PC
  wire [`DATA_SIZE-1:0] pc;
  reg  [`DATA_SIZE-1:0] new_pc;
  // Instruction Register(IR)
  wire [          31:0] ir;
  // CSR
  wire [`DATA_SIZE-1:0] trap_addr;
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
  wire [`DATA_SIZE-1:0] csr_mask_rd_data;
  wire [`DATA_SIZE-1:0] csr_wr_data;
  wire [`DATA_SIZE-1:0] csr_aux_wr;
`endif

  // Instanciação de Componentes
  // Register File
`ifdef ZICSR  // Com ZICSR há 4 possíveis origens do rd
  gen_mux #(
      .size(`DATA_SIZE),
      .N(2)
  ) mux11 (
      .A({pc_plus_4, rd_data, csr_mask_rd_data, muxaluY_out}),
      .S(wr_reg_src),
      .Y(rd)
  );
  // caso seja realizada uma leitura do SEIP(9) é preciso realizar o OR com o external_interrupt
  assign csr_mask_rd_data[8:0] = csr_rd_data[8:0];
  assign csr_mask_rd_data[9] = (ir[31:20] == 12'h344 || ir[31:20] == 12'h144)
                                            ? (csr_rd_data[9] | external_interrupt)
                                            : csr_rd_data[9];
  assign csr_mask_rd_data[`DATA_SIZE-1:10] = csr_rd_data[`DATA_SIZE-1:10];
`else  // Sem ZICSR: 3 origens -> Economizar 1 mux
  assign rd = wr_reg_src[1] ? (wr_reg_src[0] ? pc_plus_4 : rd_data) : muxaluY_out;
`endif
  register_file #(
      .size(`DATA_SIZE),
      .N(5)
  ) int_reg_state (
      .clock(clock),
      .reset(reset),
      // You can't write an illegal value coming from CSR
      .write_enable(wr_reg_en && !(wr_reg_src == 2'b01 && csr_addr_exception)),
      .read_address1(rs1_addr),
      .read_address2(ir[24:20]),
      .write_address(ir[11:7]),
      .write_data(rd),
      .read_data1(rs1),
      .read_data2(rs2)
  );
  // ULA
`ifdef RV64I
  assign aluA = alua_src ? pc : (aluy_src ? {{32{rs1[31]}}, rs1[31:0]} : rs1);
  assign aluB = alub_src ? immediate : (aluy_src ? {{32{rs2[31]}}, rs2[31:0]} : rs2);
  assign muxaluY_out[`DATA_SIZE-1:32] = aluy_src ? {32{aluY[31]}} : aluY[`DATA_SIZE-1:32];
`else
  assign aluA = alua_src ? pc : rs1;
  assign aluB = alub_src ? immediate : rs2;
`endif

  ULA #(
      .N(`DATA_SIZE)
  ) alu (
      .A(aluA),
      .B(aluB),
      `ifdef M
      .seletor(alu_src),
      `else
      .seletor({1'b0, alu_src[2:0]}),
      `endif
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
      .A(alupc_src ? {rs1[`DATA_SIZE-1:1], 1'b0} : pc),
      .B({immediate[`DATA_SIZE-1:1], 1'b0}),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_immediate)
  );
  // PC
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) pc_register (
      .clock(clock),
      .reset(reset),
      .enable(pc_en),
      .D(new_pc),
      .Q(pc)
  );
  always @(*) begin
    if (_trap) new_pc = trap_addr;
    `ifdef TrapReturn
    else if (mret) new_pc = mepc;
    else if (sret) new_pc = sepc;
    `endif
    else if (pc_src) new_pc = pc_plus_immediate;
    else new_pc = pc_plus_4;
  end
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
  assign mem_addr = mem_addr_src ? aluY : pc;
  // CSR
  CSR csr_bank (
      .clock(clock),
      .reset(reset),
      .trap_en(pc_en),
      // Interrupt/Exception Signals
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .mem_msip(|mem_msip),
      .mem_mtime(mem_mtime),
      .mem_mtimecmp(mem_mtimecmp),
      .trap_addr(trap_addr),
      .trap(_trap),
      .privilege_mode(_privilege_mode),
      .addr_exception(csr_addr_exception),
      .pc(pc),
      .instruction(ir),
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
      .mret(1'b0),
      .sret(1'b0),
      .mepc(),
      .sepc()
`endif
  );


  // Atribuições intermediárias
  // Mascarar LUI no Rs1
  assign rs1_addr = ir[19:15] & {5{(~(ir[4] & ir[2]))}};
  assign muxaluY_out[31:0] = aluY[31:0];

  // Zicsr
`ifdef ZICSR
  assign csr_aux_wr = csr_imm ? $unsigned(ir[19:15]) : rs1;
  assign csr_wr_data = csr_op[1] ? (csr_op[0] ? (csr_rd_data & (~csr_aux_wr))
                        : (csr_rd_data | csr_aux_wr)) : csr_aux_wr;
`endif

  // Saídas
  // Memory
  assign wr_data = rs2;
  // Control Unit
  assign opcode = ir[6:0];
  assign funct3 = ir[14:12];
  assign funct7 = ir[31:25];
  assign privilege_mode = _privilege_mode;

endmodule
