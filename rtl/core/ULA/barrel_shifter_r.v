//
//! @file   barrel_shifter_r.v
//! @brief  Barrel Shifter para direita (aritmético e lógico)
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//


module barrel_shifter_r(A, shamt, Y, arithmetic);
    parameter N = 4;
    input  wire [2**N - 1 : 0] A;
    input  wire [N - 1: 0]    shamt;
    input  wire arithmetic; // 1: SRA, 0: SRL
    output wire [2**N - 1 : 0] Y;

    wire shift; 
    wire [2**N - 1 : 0] B[N : 0]; // array intermediário
    genvar i, j;                 // variável de iteração do generate

    // padronizando as entradas/saídas dos muxes
    assign B[0] = A;
    assign Y    = B[N];

    // decide se é aritmético ou lógico
    assign shift = arithmetic & A[2**N - 1];

    // generate para criar o barrel shifter p/ direita usando muxes
    generate
        for(i = 0; i < N; i = i + 1) begin: row
            for(j = 0; j < 2**N; j = j + 1) begin: column
                if(j > 2**N - 1 - 2**i)
                    mux2to1 #(.size(1)) mux (.A(B[i][j]), .B(shift), .S(shamt[i]), .Y(B[i + 1][j]));
                else
                    mux2to1 #(.size(1)) mux (.A(B[i][j]), .B(B[i][j + 2**i]), .S(shamt[i]), .Y(B[i + 1][j]));
            end
        end
    endgenerate

endmodule