//
//! @file   instruction_cache_path.v
//! @brief  Implementação de um controlador de cache para uma memória
//          ROM de instruções
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

`timescale 1 ns / 100 ps

module instruction_cache_path #(
    parameter integer L2_CACHE_SIZE = 8,  // log_2(tamanho da cache em bytes)
    parameter integer L2_BLOCK_SIZE = 6,  // log_2(tamanho do bloco em bytes)
    parameter integer L2_ADDR_SIZE  = 5,  // log2(bits de endereço)
    parameter integer L2_DATA_SIZE  = 2   // log2(bytes de dados)
) (
    /* Sinais do sistema */
    input reset,
    /* //// */

    /* Interface com a memória de instruções */
    input [2**(L2_BLOCK_SIZE+3)-1:0] inst_data,
    output [2**L2_ADDR_SIZE-1:0] inst_addr,
    /* //// */

    /* Interface com o controlador de memória */
    input [2**L2_ADDR_SIZE-1:0] inst_cache_addr,
    output [2**(L2_DATA_SIZE+3)-1:0] inst_cache_data,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input  cache_write_enable,
    output hit
    /* //// */
);
  /* Quantidade de bits para cada campo dos sinais */
  localparam integer OFFSET = L2_BLOCK_SIZE;
  localparam integer BYTE_OFFSET = L2_DATA_SIZE;
  localparam integer BLOCK_OFFSET = L2_BLOCK_SIZE - L2_DATA_SIZE;
  localparam integer INDEX = L2_CACHE_SIZE - OFFSET;
  localparam integer TAG = 64 - OFFSET - INDEX;
  localparam integer DEPTH = 2 ** (L2_CACHE_SIZE - L2_BLOCK_SIZE);

  reg  [2**(OFFSET+3)-1:0] cache_data      [DEPTH-1:0];
  reg  [          TAG-1:0] cache_tag       [DEPTH-1:0];
  reg  [        DEPTH-1:0] cache_valid;


  wire [        DEPTH-1:0] tag_comparisson;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  generate
    if (OFFSET != 0) begin : g_offset_if
      wire [OFFSET-1:0] offset = inst_cache_addr[OFFSET-1:0];
      wire [BYTE_OFFSET-1:0] byte_offset = offset[BYTE_OFFSET-1:0];
      wire [BLOCK_OFFSET-1:0] block_offset = offset[OFFSET-1:BYTE_OFFSET];
    end else begin : g_offset_else
      wire offset = 0;
      wire byte_offset = 0;
      wire block_offset = 0;
    end

  endgenerate
  generate
    if (INDEX != 0) wire [INDEX-1:0] index = inst_cache_addr[INDEX+OFFSET-1:OFFSET];
    else wire index = 0;
  endgenerate

  wire [TAG-1:0] tag = inst_cache_addr[2**L2_ADDR_SIZE-1:INDEX+OFFSET];

  assign inst_cache_data = cache_data[index][(block_offset+1)*(2**(OFFSET+3))-1-:(2**(OFFSET+3))];

  genvar i;
  generate
    for (i = 0; i < DEPTH; i = i + 1) begin : gen_comparadores
      assign tag_comparisson[i] = ~(|(tag[TAG-1:0] ^ cache_tag[i]));
    end
  endgenerate

  assign hit = cache_valid[index] & tag_comparisson[index];

  assign inst_addr = inst_cache_addr;

  integer j;
  always @(posedge cache_write_enable, posedge reset) begin
    if (reset) cache_valid <= 'b0;
    else if (cache_write_enable) begin
      cache_data[index]  <= inst_data;
      cache_tag[index]   <= tag;
      cache_valid[index] <= 1'b1;
    end else begin
      cache_data[index]  <= cache_data[index];
      cache_tag[index]   <= cache_tag[index];
      cache_valid[index] <= cache_valid[index];
    end
  end
endmodule
