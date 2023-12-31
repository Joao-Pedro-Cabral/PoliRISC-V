//
//! @file   full_barrel_shifter.v
//! @brief  Barrel Shifter para shift arimético e lógico para a direita e lógico para a esquerda
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-03
//

module full_barrel_shifter
#(
    parameter XLEN=32
)
(
    input [XLEN-1:0] in_data,
    input [$clog2(XLEN)-1:0] shamt,
    input left_or_right_shift, // 0 or 1: funct3[2] of SLL/SRL/SRA
    input arithmetic_right_shift, // SRL/SRA instruction[30]
    output wire [XLEN-1:0] out_data
);

    wire [XLEN-1:0] O [$clog2(XLEN):0];
    wire [XLEN-1:0] b_in_wire [$clog2(XLEN)-1:0];
    wire msb;


    assign O[0] = in_data;
    assign out_data = O[$clog2(XLEN)];
    assign msb = arithmetic_right_shift & O[0][XLEN-1];


    genvar i, j;
    generate

        for(i = 0; i < $clog2(XLEN); i = i + 1) begin : b_columns
            for(j = 0; j < XLEN; j = j + 1) begin : b_rows
                mux2to1  // decides b_in signal of main shift muxes
                #(
                    .size(1)
                )
                b_i_j
                (
                    .A
                    (
                        (j < ('b01 << i)) // j < 2^i
                        ?
                            1'b0
                        :
                            O[i][j-('sb01 << i)]
                    ),
                    .B
                    (
                        ((j + ('b01 << i)) >= XLEN)
                        ?
                            msb
                        :
                            O[i][j+('b01 << i)]
                    ),
                    .S(left_or_right_shift),
                    .Y(b_in_wire[i][j])
                );
            end
        end


        for(i = 1; i <= $clog2(XLEN); i = i + 1) begin : columns
            for(j = 0; j < XLEN; j = j + 1) begin : rows
                mux2to1 // main shift muxes
                #(
                    .size(1)
                )
                O_i_j
                (
                    .A(O[i-1][j]),
                    .B(b_in_wire[i-1][j]),
                    .S(shamt[i-1]),
                    .Y(O[i][j])
                );
            end
        end
    endgenerate

endmodule
