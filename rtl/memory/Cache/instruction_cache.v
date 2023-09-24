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
    input CLK_I,
    input RST_I,
    /* //// */

    /* Interface com a memória de instruções */
    input [2**(L2_BLOCK_SIZE+3)-1:0] inst_DAT_I,
    input inst_ACK_I,
    output inst_CYC_O,
    output [2**L2_ADDR_SIZE-1:0] inst_ADR_O,
    /* //// */

    /* Interface com o controlador de memória */
    input inst_cache_CYC_I,
    input [2**L2_ADDR_SIZE-1:0] inst_cache_ADR_I,
    output [2**(L2_DATA_SIZE+3)-1:0] inst_cache_DAT_O,
    output inst_cache_ACK_O
    /* //// */

);

  wire TGC_I, TGC_O, cache_WE_I, cache_WE_O;

  instruction_cache_control control (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .inst_ACK_I(inst_ACK_I),
      .inst_CYC_O(inst_CYC_O),
      .inst_cache_CYC_I(inst_cache_CYC_I),
      .inst_cache_ACK_O(inst_cache_ACK_O),
      .TGC_I(TGC_I),
      .cache_WE_O(cache_WE_O)
  );

  instruction_cache_path #(
      .L2_CACHE_SIZE(L2_CACHE_SIZE),
      .L2_BLOCK_SIZE(L2_BLOCK_SIZE),
      .L2_ADDR_SIZE (L2_ADDR_SIZE),
      .L2_DATA_SIZE (L2_DATA_SIZE)
  ) path (
      .RST_I(RST_I),
      .inst_DAT_I(inst_DAT_I),
      .inst_ADR_O(inst_ADR_O),
      .inst_cache_ADR_I(inst_cache_ADR_I),
      .inst_cache_DAT_O(inst_cache_DAT_O),
      .cache_WE_I(cache_WE_I),
      .TGC_O(TGC_O)
  );

  assign TGC_I = TGC_O;
  assign cache_WE_I = cache_WE_O;

endmodule
