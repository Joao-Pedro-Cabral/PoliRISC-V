
module dataflow(clock, reset, instruction, instruction_address, read_data, write_data, data_address,
                alua_src, alub_src, aluy_src, alu_src, carry_in, arithmetic, alupc_src, pc_src, pc_enable, 
                write_register_src, write_register_enable, opcode, func3, zero, negative, carry_out, overflow);
    // Common
    input  wire clock;
    input  wire reset;
    // Instruction Memory
    input  wire [31:0] instruction;
    output wire [63:0] instruction_address;
    // Data Memory
    input  wire [63:0] read_data;
    output wire [63:0] write_data;
    output wire [63:0] data_address;
    // From Control Unit
    input  wire alua_src;
    input  wire alub_src;
    input  wire aluy_src;
    input  wire alu_src;
    input  wire carry_in;
    input  wire arithmetic;
    input  wire alupc_src;
    input  wire pc_src;
    input  wire pc_enable;
    input  wire [1:0] write_register_src;
    input  wire write_register_enable;
    // To Control Unit
    output wire [6:0] opcode;
    output wire [2:0] func3;
    output wire zero;
    output wire negative;
    output wire carry_out;
    output wire overflow;
    // Fios intermediários
        // Register File
    wire [4:0]  reg_addr_source_1;
    wire [4:0]  reg_addr_destiny;
    wire [63:0] reg_data_source_1;
    wire [63:0] reg_data_source_2;
    wire [63:0] reg_data_destiny;
    wire [63:0] muxpc4_data_out; // PC + 4 or read_data
        // Extensor de Imediato
    wire [63:0] immediate;
        // ULA
    wire [63:0] aluA;
    wire [63:0] aluB;
    wire [63:0] aluY;
    wire [63:0] muxaluY_out;         // aluY or sign_extended(aluY[31:0])
        // Somador PC + 4
    wire [63:0] pc_plus_4;
        // Somador PC + Imediato
    wire [63:0] muxpc_reg_out;       // PC or Rs1 << 1
    wire [63:0] muxpc_immediate_out; // Immediate or Immediate << 1
    wire [63:0] pc_plus_immediate;
        // Mux PC
    wire [63:0] muxpc_out;
        // PC
    wire [63:0] pc;


    // Instanciação de Componentes
        // Register File
    mux2to1        #(.size(64))              muxpc4_data     (.A(read_data), .B(pc_plus_4), .S(write_register_src[0]), .Y(muxpc4_data_out));
    mux2to1        #(.size(64))              muxreg_destiny  (.A(muxpc4_data_out), .B(muxaluY_out), .S(write_register_src[1]), .Y(reg_data_destiny));
    register_file  #(.size(64), .N(5))       int_reg_state   (.clock(clock), .reset(reset), .write_enable(write_register_enable), .read_address1(reg_addr_source_1), 
        .read_address2(instruction[24:20]), .write_address(instruction[11:7]), .write_data(reg_data_destiny), .read_data1(reg_data_source_1), .read_data2(reg_data_source_2));
        // ULA
    mux2to1        #(.size(64))              muxaluA (.A(reg_data_source_1), .B(pc), .S(alua_src), .Y(aluA));
    mux2to1        #(.size(64))              muxaluB (.A(immediate), .B(reg_data_source_2), .S(alub_src), .Y(aluB)); 
    mux2to1        #(.size(32))              muxaluY (.A(aluY[63:32]), .B({32{aluY[31]}}), .S(aluy_src), .Y(muxaluY_out[63:32]));
    ULA            #(.N(64))                 alu     (.A(aluA), .B(aluB), .seletor(alu_src), .carry_in(carry_in), .arithmetic(arithmetic), 
        .Y(aluY), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow));
        // Somador PC + 4
        // Somador PC + Imediato
    mux2to1       #(.size(64))               muxpc_reg       (.A(pc), .B({reg_data_source_1[62:0], 1'b0}), .S(alupc_src), .Y(muxpc_reg_out));
    mux2to1       #(.size(64))               muxpc_immediate (.A(immediate), .B({immediate[62:0], 1'b0}), .S(alupc_src), .Y(muxpc_immediate_out));
        // PC
    mux2to1       #(.size(64))               muxpc           (.A(pc_plus_4), .B(pc_plus_immediate), .S(pc_src), .Y(muxpc_out));
    register_d    #(.N(64), .reset_value(0)) pc_register     (.clock(clock), .reset(reset), .enable(pc_enable), .D(muxpc_out), .Q(pc));

    // Atribuições intermediárias
    assign reg_addr_source_1 = instruction[19:15] & {4{(~(instruction[4] & instruction[2]))}};
    assign muxaluY_out[31:0] = aluY[31:0];

    // Saídas
        // Instruction Memory
    assign instruction_address = pc;
        // Data Memory
    assign write_data   = reg_data_source_2;
    assign data_address = aluY;
        // Control Unit
    assign opcode = instruction[6:0];
    assign func3  = instruction[14:12];

endmodule