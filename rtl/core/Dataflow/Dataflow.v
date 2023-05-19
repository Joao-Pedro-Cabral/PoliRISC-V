//
//! @file   Dataflow.v
//! @brief  Dataflow do RV32I/RV64I
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

module Dataflow(
    // Common
    input  wire clock,
    input  wire reset,
    // Memory
    input  wire [`data_size-1:0] rd_data, // data_size é definido no toplevel
    output wire [`data_size-1:0] wr_data,
    output wire [`data_size-1:0] mem_addr,
    // From Control Unit
    input  wire alua_src,
    input  wire alub_src,
    `ifdef RV64I
        input  wire aluy_src,
    `endif
    input  wire [2:0] alu_src,
    input  wire sub,
    input  wire arithmetic,
    input  wire alupc_src,
    input  wire pc_src,
    input  wire pc_en,
    input  wire [1:0] wr_reg_src,
    input  wire wr_reg_en,
    input  wire ir_en,
    input  wire mem_addr_src,
    // To Control Unit
    output wire [6:0] opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire zero,
    output wire negative,
    output wire carry_out,
    output wire overflow,
    output wire [`data_size-1:0] db_reg_data  // depuracao
);
    // Fios intermediários
        // Register File
    wire [4:0]  reg_addr_source_1;
    wire [`data_size-1:0] reg_data_source_1;
    wire [`data_size-1:0] reg_data_source_2;
    wire [`data_size-1:0] reg_data_destiny;
    wire [`data_size-1:0] muxpc4_data_out;     // PC + 4 or read_data
        // Extensor de Imediato
    wire [`data_size-1:0] immediate;
        // ULA
    wire [`data_size-1:0] aluA;
    wire [`data_size-1:0] aluB;
    wire [`data_size-1:0] aluY;
    wire [`data_size-1:0] muxaluY_out;         // aluY or sign_extended(aluY[31:0])
        // Somador PC + 4
    wire [`data_size-1:0] pc_plus_4;
        // Somador PC + Imediato
    wire [`data_size-1:0] muxpc_reg_out;       // PC or Rs1
    wire [`data_size-1:0] muxpc_immediate_out; // Immediate
    wire [`data_size-1:0] pc_plus_immediate;
        // Mux PC
    wire [`data_size-1:0] muxpc_out;
        // PC
    wire [`data_size-1:0] pc;
        // Instruction Register(IR)
    wire [31:0]  ir;

    // Instanciação de Componentes
        // Register File
    mux2to1        #(.size(`data_size))              muxpc4_data      (.A(rd_data), .B(pc_plus_4), .S(wr_reg_src[0]), .Y(muxpc4_data_out));
    mux2to1        #(.size(`data_size))              muxreg_destiny   (.A(muxaluY_out), .B(muxpc4_data_out), .S(wr_reg_src[1]), .Y(reg_data_destiny));
    register_file  #(.size(`data_size), .N(5))       int_reg_state    (.clock(clock), .reset(reset), .write_enable(wr_reg_en), .read_address1(reg_addr_source_1), 
        .read_address2(ir[24:20]), .write_address(ir[11:7]), .write_data(reg_data_destiny), .read_data1(reg_data_source_1), .read_data2(reg_data_source_2));
        // ULA
    mux2to1        #(.size(`data_size))              muxaluA          (.A(reg_data_source_1), .B(pc), .S(alua_src), .Y(aluA));
    mux2to1        #(.size(`data_size))              muxaluB          (.A(reg_data_source_2), .B(immediate), .S(alub_src), .Y(aluB)); 
    `ifdef RV64I // mascarar os 32 MSb de aluY
        mux2to1    #(.size(32))                      muxaluY          (.A(aluY[`data_size-1:32]), .B({32{aluY[31]}}), .S(aluy_src), .Y(muxaluY_out[`data_size-1:32]));
    `endif
    ULA            #(.N(`data_size))                 alu              (.A(aluA), .B(aluB), .seletor(alu_src), .sub(sub), .arithmetic(arithmetic), 
        .Y(aluY), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow));
        // Somador PC + 4
    sklansky_adder #(.INPUT_SIZE(`data_size))        pc_4             (.A(pc), .B('b0100), .c_in(1'b0), .c_out(), .S(pc_plus_4));
        // Somador PC + Imediato
    sklansky_adder #(.INPUT_SIZE(`data_size))        pc_immediate     (.A(muxpc_reg_out), .B(muxpc_immediate_out), .c_in(1'b0), .c_out(), .S(pc_plus_immediate));
    mux2to1        #(.size(`data_size))              muxpc_reg        (.A(pc), .B({reg_data_source_1[`data_size-1:1], 1'b0}), .S(alupc_src), .Y(muxpc_reg_out));
    mux2to1        #(.size(`data_size))              muxpc_immediate  (.A({immediate[`data_size-2:0],1'b0}), .B({immediate[`data_size-1:1], 1'b0}), .S(alupc_src), .Y(muxpc_immediate_out));
        // PC
    mux2to1       #(.size(`data_size))               muxpc            (.A(pc_plus_4), .B(pc_plus_immediate), .S(pc_src), .Y(muxpc_out));
    register_d    #(.N(`data_size), .reset_value(0)) pc_register      (.clock(clock), .reset(reset), .enable(pc_en), .D(muxpc_out), .Q(pc));
        // Immediate Extender
    ImmediateExtender #(.N(`data_size))              estende_imediato (.instruction(ir), .immediate(immediate));
        // Instruction Register -> Borda de Descida!
    register_d    #(.N(32), .reset_value(0))         instru_register  (.clock(clock), .reset(reset), .enable(ir_en), .D(rd_data[31:0]), .Q(ir));
        // Memory
    mux2to1       #(.size(`data_size))               muxmem_addr      (.A(pc), .B(aluY), .S(mem_addr_src), .Y(mem_addr));


    // Atribuições intermediárias
        // Mascarar LUI no Rs1
    assign reg_addr_source_1 = ir[19:15] & {5{(~(ir[4] & ir[2]))}};
    assign muxaluY_out[31:0] = aluY[31:0];

    // Saídas
        // Memory
    assign wr_data   = reg_data_source_2;
        // Control Unit
    assign opcode = ir[6:0];
    assign funct3 = ir[14:12];
    assign funct7 = ir[31:25];
        // Depuracao
    assign db_reg_data = reg_data_destiny;

endmodule