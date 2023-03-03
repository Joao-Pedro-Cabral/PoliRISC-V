//
//! @file   simple_mux2to1.v
//! @brief  Multiplexador 2 para 1
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-03
//

module simple_mux2to1
(
    input a_in,
    input b_in,
    input sel,
    output wire out
);

   assign out = sel ? b_in : a_in;

endmodule

