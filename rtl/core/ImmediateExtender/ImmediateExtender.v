//
//! @file   ImmediateExtender.v
//! @brief  Extensor de Imediato
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-20
//

`include "macros.vh"

module ImmediateExtender (
    instruction,
    immediate
);
  parameter integer N = 64;  // N >= 32, preferencialmente apenas 64 ou 32
  input wire [31:0] instruction;
  output wire [N-1:0] immediate;

  wire imm11_int;  // saida do mux intermediário para seleção do immediate[11]

  // muxes para formação do imediato
  assign immediate[N-1:31] = $signed({instruction[31]});
  assign immediate[30:20] = (~instruction[6] & instruction[2])
                             ? instruction[30:20] : {11{instruction[31]}};
  assign immediate[19:12] = ((~instruction[4] & instruction[3]) | ~instruction[6] & instruction[2])
                              ? instruction[19:12] : {8{instruction[31]}};
  assign imm11_int = (instruction[3]) ? instruction[20] : instruction[31];
  assign immediate[10:5] = (~instruction[6] & instruction[2]) ? 1'b0 : instruction[30:25];
  assign immediate[4:1]   = (~instruction[6] & instruction[2]) ? 1'b0 :
                              (instruction[5] & (~instruction[2]))
                              ? instruction[11:8] : instruction[24:21];
  assign immediate[0]     = ((instruction[6] ^ instruction[2]) | (instruction[3] & instruction[2]))
                              ? 1'b0 : (instruction[5] & (~instruction[2]))
                              ? instruction[7] : instruction[20];

  gen_mux #(
      .size(1),
      .N(2)
  ) mux11 (
      .A({imm11_int, instruction[7], 1'b0, instruction[31]}),
      .S({instruction[6], instruction[2]}),
      .Y(immediate[11])
  );

endmodule
