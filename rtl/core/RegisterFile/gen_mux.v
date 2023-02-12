//
//! @file   gen_mux.v
//! @brief  Multiplexador genérico(2^N para 1)
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

module gen_mux(A, S, Y);
    parameter size = 4;     // tamanho dos vetores
    parameter N    = 8;     
    input  wire [size*(2**N) - 1:0] A; // verilog não suporta array como input -> 
                                       // -> linearizar array(2**N vetores de tamanho size)
    input  wire [N - 1:0]    S;
    output wire [size - 1:0] Y;
    wire   [size - 1:0] B[N:0][2**N - 1:0]; // na verdade, para cada linha k uso 2**(N - k) colunas
    genvar i, j, k;                         // variáveis de iteração do generate

    assign Y = B[N][0];

    generate
        for(k = 0; k < 2**N; k = k + 1) begin: B_0_init
            assign B[0][k] = A[(k + 1)*size - 1:k*size];
        end
    endgenerate

    generate
        for(i = 0; i < N; i = i + 1) begin: line
            for(j = 0; j < 2**(N - i - 1); j = j + 1) begin: column
                // gero o multiplexador usando vários mux2to1
                mux2to1 #(.size(size)) mux (.A(B[i][2*j]), .B(B[i][2*j + 1]), .S(S[i]), .Y(B[i + 1][j]));
            end
        end
    endgenerate
endmodule