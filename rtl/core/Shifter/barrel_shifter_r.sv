
module barrel_shifter_r (
    A,
    shamt,
    Y,
    arithmetic
);
  parameter integer N = 4;
  parameter integer M = 4;
  input wire [2**N - 1 : 0] [M-1:0] A;
  input wire [N - 1:0] shamt;
  input wire arithmetic;  // 1: SRA, 0: SRL
  output wire [2**N - 1 : 0] [M-1:0] Y;

  wire [M-1:0] shift;
  wire [2**N - 1 : 0] [M-1:0] B[N : 0];  // array intermediário
  genvar i, j;  // variável de iteração do generate

  // padronizando as entradas/saídas dos muxes
  assign B[0] = A;
  assign Y    = B[N];

  // decide se é aritmético ou lógico
  assign shift = {M{arithmetic & A[2**N - 1][M-1]}};

  // generate para criar o barrel shifter p/ direita usando muxes
  generate
    for (i = 0; i < N; i = i + 1) begin : g_row
      for (j = 0; j < 2 ** N; j = j + 1) begin : g_column
        if (j > 2 ** N - 1 - 2 ** i)
          mux2to1 #(
              .size(M)
          ) mux (
              .A(B[i][j]),
              .B(shift),
              .S(shamt[i]),
              .Y(B[i+1][j])
          );
        else
          mux2to1 #(
              .size(M)
          ) mux (
              .A(B[i][j]),
              .B(B[i][j+2**i]),
              .S(shamt[i]),
              .Y(B[i+1][j])
          );
      end
    end
  endgenerate

endmodule
