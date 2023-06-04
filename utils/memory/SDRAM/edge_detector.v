//
//! @file   edge_detector.v
//! @brief  Circuito para detectar borda de subida
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//
module edge_detector (
    input  wire clock,
    input  wire reset,
    input  wire sinal,
    output wire pulso
);

  reg sinal2, sinal3;  // valores anteriores do sinal


  always @(posedge clock, posedge reset) begin
    if (reset) begin
      sinal2 <= 1'b0;
      sinal3 <= 1'b0;
    end else if (clock) begin
      sinal2 <= sinal;
      sinal3 <= sinal2;
    end
  end

  assign pulso = (~sinal3) & sinal2;

endmodule
