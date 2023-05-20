//
//! @file   decoderN.v
//! @brief  Decoder genérico(N para 2^N)
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

module decoderN (
    A,
    enable,
    Y
);
  parameter N = 5;
  input wire [N - 1:0] A;
  input wire enable;
  output reg [2**N - 1:0] Y;

  always @(*) begin
    if (enable == 1) begin
      Y    = 0;
      Y[A] = 1;
    end else Y = 0;
  end
endmodule
