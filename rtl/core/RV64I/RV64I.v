//
//! @file   RV64I.v -> Qual o novo nome?
//! @brief  RV64I sem FENCE, ECALL e EBREAK
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

`ifdef RV64I
    `define data_size 64
`else
    `define data_size 32
`endif

module RV64I
(
    input  wire clock,
    input  wire reset,
    
    // Bus Interface
    input  wire [data_size-1:0] rd_data,
    output wire [data_size-1:0] wr_data,
    output wire [data_size-1:0] mem_addr,
    input  wire mem_busy,
    output wire mem_rd_en,
    output wire mem_wr_en,
    `ifdef RV64I // 64 bits = 8 bytes
        output wire [7:0] mem_byte_en,
    `else // 32 bits = 4 bytes
        output wire [3:0] mem_byte_en,
    `endif

    // depuracao
    output wire [data_size-1:0] db_reg_data
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
    wire pc_en;
    wire [1:0] wr_reg_src;
    wire wr_reg_en;
    wire ir_en;
    wire mem_addr_src;
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;

    // Dataflow
    Dataflow DF (.clock(clock), .reset(reset), .rd_data(rd_data), .wr_data(wr_data), .mem_addr(mem_addr), .alua_src(alua_src),
     .alub_src(alub_src), .alu_src(alu_src), `ifdef RV64I .aluy_src(aluy_src), `endif .sub(sub), .arithmetic(arithmetic), .ir_en(ir_en), 
     .mem_addr_src(mem_addr_src), .alupc_src(alupc_src), .pc_src(pc_src), .pc_en(pc_en), .wr_reg_src(wr_reg_src), .wr_reg_en(wr_reg_en), .opcode(opcode), 
     .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow), .db_reg_data(db_reg_data));

    // Control Unit
    control_unit UC (.clock(clock), .reset(reset), .mem_rd_en(mem_rd_en), .mem_wr_en(mem_wr_en), .mem_byte_en(mem_byte_en), .mem_busy(mem_busy), 
    .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), .ir_en(ir_en), .negative(negative), .carry_out(carry_out), .overflow(overflow), 
    .alua_src(alua_src), .alub_src(alub_src), `ifdef RV64I .aluy_src(aluy_src), `endif .alu_src(alu_src), .sub(sub), .arithmetic(arithmetic), 
    .alupc_src(alupc_src), .pc_src(pc_src), .pc_en(pc_en), .wr_reg_src(wr_reg_src), .wr_reg_en(wr_reg_en), .mem_addr_src(mem_addr_src));

endmodule