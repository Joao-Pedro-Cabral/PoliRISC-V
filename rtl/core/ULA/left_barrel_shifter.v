
module left_barrel_shifter
#(
    parameter XLEN=32
)
(
    input [XLEN-1:0] in_data,
    input [$clog2(XLEN)-1:0] shamt,
    output wire [XLEN-1:0] out_data
);

    wire [XLEN-1:0] O [$clog2(XLEN)-1:0];
    assign O[0] = in_data;
    assign out_data = O[$clog2(XLEN)-1];


    genvar i, j;
    generate
        for(i = 1; i < $clog2(XLEN); i = i + 1) begin
            for(j = 0; j < XLEN; j = j + 1) begin
                mux2to1
                #(
                    .size(1)
                )
                O_i_j
                (
                    .B(O[i-1][j]),
                    .A(j < ('b01 << (i-1)) ? 0 : O[i-1][j-('b01 << (i-1))]),
                    .S(shamt[i]),
                    .Y(O[i][j])
                );
            end
        end
    endgenerate

endmodule
