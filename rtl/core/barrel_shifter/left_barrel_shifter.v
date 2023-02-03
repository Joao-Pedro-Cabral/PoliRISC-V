module mux_2to1
#(
    parameter DATA_SIZE=32
)
(   input [DATA_SIZE-1:0] a_in,
    input [DATA_SIZE-1:0] b_in,
    input sel,
    output wire [DATA_SIZE-1:0] out
);

   assign out = sel ? a_in : b_in;

endmodule

module left_barrel_shifter
#(
    parameter XLEN=32
)
(
    input [XLEN-1:0] in_data,
    input [$clog2(XLEN)-1:0] shamt,
    output wire out_data
);

    wire [XLEN-1:0] O [$clog2(XLEN)-1:0];
    assign O[0] = in_data;
    assign out_data = O[$clog2(XLEN)-1];


    genvar i, j;
    generate
        for(i = 1; i < $clog2(XLEN); i = i + 1) begin
            for(j = 0; j < XLEN; j = j + 1) begin
                mux_2to1
                #(
                    .DATA_SIZE(XLEN)
                )
                O_i_j
                (
                    .a_in(O[i-1][j]),
                    .b_in(j < $pow(2,i) ? 0 : O[i-1][j-$pow(2,i)]),
                    .sel(shamt[i]),
                    .out(O[i][j])
                );
            end
        end
    endgenerate

endmodule
