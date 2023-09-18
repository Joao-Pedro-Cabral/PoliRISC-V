//
//! @file   core.v -> Qual o novo nome?
//! @brief  RV64I/RV32I sem FENCE, ECALL e EBREAK
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

/*
module core (
*    input wire CLK_I,
*    input wire RST_I,
*
*    // Bus Interface
*    input wire [`DATA_SIZE-1:0] DAT_I,
*    output wire [`DATA_SIZE-1:0] DAT_O,
*    output wire [`DATA_SIZE-1:0] ADR_O,
*    input wire ACK_O, -- LEMBRAR QUE A LÓGICA É INVERSA
*    output wire WE_O,
*    output wire [`DATA_SIZE/8-1:0] SEL_O
*);
*/


`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module core (
    input wire CLK_I,
    input wire RST_I,

    // Bus Interface
    input wire [`DATA_SIZE-1:0] rd_data,
    output wire [`DATA_SIZE-1:0] wr_data,
    output wire [`DATA_SIZE-1:0] mem_addr,
    input wire mem_busy,
    output wire mem_rd_en,
    output wire mem_wr_en,
    output wire [`DATA_SIZE/8-1:0] mem_byte_en,
    // Interrupts from Memory
    input wire external_interrupt,
    input wire [`DATA_SIZE-1:0] mem_msip,
    input wire [63:0] mem_mtime,
    input wire [63:0] mem_mtimecmp
);

  // Sinais comuns do DF e da UC
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
  wire ADR_O_src;
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire zero;
  wire negative;
  wire carry_out;
  wire overflow;
  wire trap;
  wire [1:0] privilege_mode;
  wire ecall;
  wire illegal_instruction;
  wire csr_addr_exception;
`ifdef TrapReturn
  wire mret;
  wire sret;
`endif
`ifdef ZICSR
  wire csr_wr_en;
  wire [1:0] csr_op;
  wire csr_imm;
`endif

  // Dataflow
  Dataflow DF (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .DAT_I(DAT_I),
      .DAT_O(DAT_O),
      .ADR_O(ADR_O),
      .alua_src(alua_src),
      .alub_src(alub_src),
      .alu_src(alu_src),
`ifdef RV64I
      .aluy_src(aluy_src),
`endif
      .sub(sub),
      .arithmetic(arithmetic),
      .alupc_src(alupc_src),
      .pc_src(pc_src),
      .pc_en(pc_en),
      .wr_reg_src(wr_reg_src),
      .ir_en(ir_en),
      .mem_addr_src(mem_addr_src),
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .csr_addr_exception(csr_addr_exception),
`ifdef TrapReturn
      .mret(mret),
      .sret(sret),
`endif
      .external_interrupt(external_interrupt),
      .mem_msip(mem_msip),
      .mem_mtime(mem_mtime),
      .mem_mtimecmp(mem_mtimecmp),
`ifdef ZICSR
      .csr_wr_en(csr_wr_en),
      .csr_op(csr_op),
      .csr_imm(csr_imm),
`endif
      .wr_reg_en(wr_reg_en),
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

  // Control Unit
  control_unit UC (
      .clock(clock),
      .reset(reset),
      .mem_busy(mem_busy),
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .mem_byte_en(mem_byte_en),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .trap(trap),
      .privilege_mode(privilege_mode),
      .csr_addr_exception(csr_addr_exception),
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
`ifdef ZICSR
      .csr_wr_en(csr_wr_en),
      .csr_op(csr_op),
      .csr_imm(csr_imm),
`endif
      .ir_en(ir_en),
      .mem_addr_src(mem_addr_src),
`ifdef TrapReturn
      .mret(mret),
      .sret(sret),
`endif
      .illegal_instruction(illegal_instruction),
      .ecall(ecall)
  );

endmodule
