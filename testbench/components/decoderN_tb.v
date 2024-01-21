//
//! @file   decoderN_tb.v
//! @brief  Testbench para Decoder genérico(N para 2^N)
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

`include "macros.vh"

module decoderN_tb ();
  // portas do DUT
  reg [3:0] A;
  reg enable;
  wire [15:0] Y;
  // variáveis de iteração
  integer j;

  // instanciando o DUT
  decoderN #(
      .N(4)
  ) DUT (
      .A(A),
      .enable(enable),
      .Y(Y)
  );

  // initial para testar o DUT
  initial begin
    $display("SOT!");
    $display("1");
    enable = 0;
    for (j = 0; j < 16; j = j + 1) begin
      A = j;
      #10;
      if (Y !== 0) $display("Error: A = %d, Y = %b", j, Y);
      #10;
    end
    $display("2");
    enable = 1;
    for (j = 0; j < 16; j = j + 1) begin
      A = j;
      #10;
      if (Y !== 2 ** j) $display("Error: A = %d, Y = %b", j, Y);
      #10;
    end
    $display("EOT!");
  end
endmodule
