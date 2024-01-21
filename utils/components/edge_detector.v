//
//! @file   edge_detector.v
//! @brief  Circuito para detectar borda de subida/descida
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//

`include "macros.vh"

module edge_detector #(
    parameter integer RESET_VALUE = 0,
    // 0: borda de subida; 1: borda de descida; 2: qualquer borda
    parameter integer EDGE_MODE   = 0
) (
    input  wire clock,
    input  wire reset,
    input  wire sinal,
    output wire pulso
);

  reg sinal2, sinal3;  // valores anteriores do sinal


  always @(posedge clock, posedge reset) begin
    if (reset) begin
      sinal2 <= RESET_VALUE;
      sinal3 <= RESET_VALUE;
    end else if (clock) begin
      sinal2 <= sinal;
      sinal3 <= sinal2;
    end
  end

  // Gerar o detector de borda
  generate
    if (EDGE_MODE == 0) assign pulso = (~sinal3) & sinal2;  // borda de subida
    else if (EDGE_MODE == 1) assign pulso = sinal3 & (~sinal2);  // borda de descida
    else assign pulso = sinal3 ^ sinal2;  // qualquer borda
  endgenerate

endmodule
