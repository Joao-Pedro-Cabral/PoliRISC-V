//
//! @file   sklansky_adder.v
//! @brief  Implementação do somador condicional de Sklansky
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-21
//

module sklansky_adder
#(
    // quantidade de bits em cada número
    parameter INPUT_SIZE = 4
)
(
    input [INPUT_SIZE-1:0] A,
    input [INPUT_SIZE-1:0] B,
    input c_in, // carry in
    output c_out, // carry out
    output wire [INPUT_SIZE-1:0] S // resultado da soma
);

    wire [INPUT_SIZE:0] G [INPUT_SIZE:0];
    wire [INPUT_SIZE:0] P [INPUT_SIZE:0];
    wire half_sum_carry_out;
    wire propagate_carry_out;
    wire generate_carry_out;

    assign G[0][0] = c_in;
    assign P[0][0] = 1'b0;


    genvar i, m, n_index;
    generate

        for(i = 1; i <= INPUT_SIZE; i = i + 1) begin : precomputation
            and(G[i][i], A[i-1], B[i-1]);
            or(P[i][i], A[i-1], B[i-1]);
        end

        for(i=0; i < $clog2(INPUT_SIZE); i = i + 1) begin : levels
            //localparam m_index = 0;
            for(m=2**i -1; m < INPUT_SIZE; m = m + 2**(i+1)) begin : blocks
                for(n_index = m + 1; n_index < m + 1 + 2**i; n_index = n_index + 1) begin : prefixes
                    prefix_operator propagate_generate
                    (
                        .g_i(G[n_index][m+1]), .g_j(G[m][m-2**i+1]),
                        .p_i(P[n_index][m+1]), .p_j(P[m][m-2**i+1]),
                        .g(G[n_index][m-2**i+1]), .p(P[n_index][m-2**i+1])
                    );
                end
                //localparam m_index = m_index + 2**(i+1);
            end
        end

        for(i = 0; i < INPUT_SIZE; i = i + 1) begin : result
            xor(S[i], A[i], B[i], G[i][0]);
        end
    endgenerate

    and(generate_carry_out, A[INPUT_SIZE-1], B[INPUT_SIZE-1]);
    xor(half_sum_carry_out, A[INPUT_SIZE-1], B[INPUT_SIZE-1]);
    and(propagate_carry_out, half_sum_carry_out, G[INPUT_SIZE-1][0]);
    or(c_out, propagate_carry_out, generate_carry_out);


endmodule
