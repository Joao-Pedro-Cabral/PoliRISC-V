//
//! @file   micro_cache.v
//! @brief  Implementação de um cache para uma memória
//          ROM de instruções alinhada em 16 bits
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-02
//

`timescale 1 ns / 100 ps

module instruction_cache #(
    parameter integer L2_CACHE_SIZE = 3,  // log_2(tamanho da cache em bytes)
    parameter integer L2_BLOCK_SIZE = 2   // log_2(tamanho do bloco em bytes)
) (
    /* Sinais do sistema */
    input clock,
    input reset,
    /* //// */

    /* Interface com a memória de instruções */
    input [63:0] inst_data,
    input inst_busy,
    output inst_enable,
    output [63:0] inst_addr,
    /* //// */

    /* Interface com o controlador de memória */
    input inst_cache_enable,
    input [63:0] inst_cache_addr,
    output [63:0] inst_cache_data,
    output reg inst_cache_busy
    /* //// */

);

  wire hit, cache_write_enable;

  instruction_cache_control control (
      .clock(clock),
      .reset(reset),
      .inst_busy(inst_busy),
      .inst_enable(inst_enable),
      .inst_cache_enable(inst_cache_enable),
      .inst_cache_busy(inst_cache_busy),
      .hit(hit),
      .cache_write_enable(cache_write_enable)
  );

  instruction_cache_path #(
      .L2_CACHE_SIZE(L2_CACHE_SIZE),
      .L2_BLOCK_SIZE(L2_BLOCK_SIZE)
  ) path (
      .reset(reset),
      .inst_data(inst_data),
      .inst_addr(inst_addr),
      .inst_cache_addr(inst_cache_addr),
      .inst_cache_data(inst_cache_data),
      .cache_write_enable(cache_write_enable),
      .hit(hit)
  );

endmodule
