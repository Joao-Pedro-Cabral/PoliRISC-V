//
//! @file   instruction_cache.v
//! @brief  Implementação de um cache
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-02
//

module instruction_cache #(
    parameter integer L2_CACHE_SIZE = 8,  // log_2(tamanho da cache em bytes)
    parameter integer L2_BLOCK_SIZE = 6,  // log_2(tamanho do bloco em bytes)
    parameter integer L2_ADDR_SIZE  = 5,  // log2(bits de endereço)
    parameter integer L2_DATA_SIZE  = 2   // log2(bytes de dados)
) (
    /* Sinais do sistema */
    input clock,
    input reset,
    /* //// */

    /* Interface com a memória de instruções */
    input [2**(L2_BLOCK_SIZE+3)-1:0] inst_data,
    input inst_busy,
    output inst_enable,
    output [2**L2_ADDR_SIZE-1:0] inst_addr,
    /* //// */

    /* Interface com o controlador de memória */
    input inst_cache_enable,
    input [2**L2_ADDR_SIZE-1:0] inst_cache_addr,
    output [2**(L2_DATA_SIZE+3)-1:0] inst_cache_data,
    output inst_cache_busy
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
      .L2_BLOCK_SIZE(L2_BLOCK_SIZE),
      .L2_ADDR_SIZE (L2_ADDR_SIZE),
      .L2_DATA_SIZE (L2_DATA_SIZE)
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
