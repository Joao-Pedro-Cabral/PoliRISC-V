//
//! @file   RV64I.v
//! @brief  RV64I sem FENCE, ECALL e EBREAK
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

module RV64I (
    input  wire clock,
    input  wire reset,
    // Data Memory
    input  wire [63:0] read_data,
    output wire [63:0] write_data,
    output wire [63:0] data_address,
    input  wire data_mem_busy,
    output wire data_mem_enable,
    output wire [7:0] data_mem_byte_write_enable,
    // Instruction Memory
    input  wire [31:0] instruction,
    output wire [63:0] instruction_address,
    input  wire instruction_mem_busy,
    output wire instruction_mem_enable,
    // depuracao
    output wire [63:0] db_reg_data
);

    // Sinais comuns do DF e da UC
    wire alua_src;
    wire alub_src;
    wire aluy_src;
    wire [2:0] alu_src;
    wire sub;
    wire arithmetic;
    wire alupc_src;
    wire pc_src;
    wire pc_enable;
    wire [2:0] read_data_src;
    wire [1:0] write_register_src;
    wire write_register_enable;
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;

    // Dataflow
    Dataflow DF (.clock(clock), .reset(reset), .instruction(instruction), .instruction_address(instruction_address), .read_data(read_data), .write_data(write_data),
     .data_address(data_address), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), .arithmetic(arithmetic), 
     .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src), .write_register_enable(write_register_enable), 
     .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow), .db_reg_data(db_reg_data));

    // Control Unit
    control_unit UC (.clock(clock), .reset(reset), .instruction_mem_enable(instruction_mem_enable), .instruction_mem_busy(instruction_mem_busy), .data_mem_enable(data_mem_enable), 
    .data_mem_byte_write_enable(data_mem_byte_write_enable), .data_mem_busy(data_mem_busy), .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), 
    .negative(negative), .carry_out(carry_out), .overflow(overflow), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), 
    .arithmetic(arithmetic), .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src),
    .write_register_enable(write_register_enable));

endmodule
