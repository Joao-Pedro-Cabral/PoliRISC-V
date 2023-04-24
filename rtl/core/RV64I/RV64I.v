//
//! @file   RV64I.v
//! @brief  RV64I sem FENCE, ECALL e EBREAK
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

module RV64I
(
    input  wire clock,
    input  wire reset,
    
    // Bus Interface
    input  wire [63:0] read_data,
    output wire [63:0] write_data,
    output wire [63:0] mem_address,
    input  wire transfer_busy,
    output wire transfer_enable,
    output wire [7:0] byte_write_enable,
    
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
    wire ir_enable;
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;

    // Sinais comuns do DF e do controlador de memória
    wire [63:0] data_address;
    wire [63:0] instruction_address;
    wire instruction_mem_enable;
    wire data_mem_read_enable;

    // Dataflow
    Dataflow DF (.clock(clock), .reset(reset), .instruction(read_data[31:0]), .instruction_address(instruction_address), .read_data(read_data), .write_data(write_data),
     .data_address(data_address), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), .arithmetic(arithmetic), .ir_enable(ir_enable),
     .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src), .write_register_enable(write_register_enable), 
     .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow), .db_reg_data(db_reg_data));

    // Control Unit
    control_unit UC (.clock(clock), .reset(reset), .instruction_mem_enable(instruction_mem_enable), .instruction_mem_busy(transfer_busy), .data_mem_read_enable(data_mem_read_enable), 
    .data_mem_byte_write_enable(byte_write_enable), .data_mem_busy(transfer_busy), .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), .ir_enable(ir_enable),
    .negative(negative), .carry_out(carry_out), .overflow(overflow), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), 
    .arithmetic(arithmetic), .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src),
    .write_register_enable(write_register_enable));

    assign mem_address = instruction_mem_enable ? instruction_address : data_address;
    assign transfer_enable = instruction_mem_enable | data_mem_read_enable;

endmodule
