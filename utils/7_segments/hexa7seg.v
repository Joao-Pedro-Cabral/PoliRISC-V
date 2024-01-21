//
//! @file hexa7seg.v
//! @brief Decodificador de hexadecimal para display de 7 segmentos
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date 2023-05-03
//

`include "macros.vh"

module hexa7seg (
    input  wire [3:0] hexa,
    output reg  [6:0] sseg
);

  // Display ativo baixo
  always @(*) begin
    case (hexa)
      0: sseg = 7'h40;
      1: sseg = 7'h79;
      2: sseg = 7'h24;
      3: sseg = 7'h30;
      4: sseg = 7'h19;
      5: sseg = 7'h12;
      6: sseg = 7'h02;
      7: sseg = 7'h78;
      8: sseg = 7'h00;
      9: sseg = 7'h10;
      10: sseg = 7'h08;
      11: sseg = 7'h03;
      12: sseg = 7'h46;
      13: sseg = 7'h21;
      14: sseg = 7'h06;
      15: sseg = 7'h0E;
      default: sseg = 7'h7F;
    endcase
  end
endmodule
