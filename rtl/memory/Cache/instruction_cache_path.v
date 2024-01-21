//
//! @file   instruction_cache_path.v
//! @brief  Implementação de um controlador de cache
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

`include "macros.vh"

module instruction_cache_path #(
    parameter integer L2_CACHE_SIZE = 8,   // log2(tamanho da cache em bytes)
    parameter integer L2_BLOCK_SIZE = 6,   // log2(tamanho do bloco em bytes)
    parameter integer L2_ADDR_SIZE  = 32,  // log2(tamanho do endereço em bits)
    parameter integer L2_DATA_SIZE  = 2    // log2(tamanho do dados em bytes)
) (
    /* Sinais do sistema */
    input wire RST_I,
    input wire CLK_I,
    /* //// */

    /* Interface com a memória de instruções */
    input wire [2**(L2_BLOCK_SIZE+3)-1:0] inst_DAT_I,
    output wire [L2_ADDR_SIZE-1:0] inst_ADR_O,
    /* //// */

    /* Interface com o controlador de memória */
    input wire [L2_ADDR_SIZE-1:0] inst_cache_ADR_I,
    output wire [2**(L2_DATA_SIZE+3)-1:0] inst_cache_DAT_O,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input  wire cache_WE_I,
    output wire TGC_O
    /* //// */
);
  /* Quantidade de bits para cada campo dos sinais */
  localparam integer Offset = L2_BLOCK_SIZE;
  localparam integer ByteOffset = L2_DATA_SIZE;
  localparam integer BlockOffset = L2_BLOCK_SIZE - L2_DATA_SIZE;
  localparam integer Index = L2_CACHE_SIZE - L2_BLOCK_SIZE;  // Simple associativity
  localparam integer Tag = L2_ADDR_SIZE - Index - Offset;
  localparam integer Depth = 2 ** (L2_CACHE_SIZE - L2_BLOCK_SIZE);

  reg [2**(Offset+3)-1:0] cache_data[Depth-1:0];  // Offset in bytes
  reg [Tag-1:0] cache_tag[Depth-1:0];
  reg [Depth-1:0] cache_valid;


  wire [Depth-1:0] tag_comparisson;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  wire [(Offset>0 ? Offset-1 : 0):0] offset = Offset > 0 ? inst_cache_ADR_I[Offset-1:0] : 0;
  wire [(ByteOffset>0 ? ByteOffset-1 : 0):0] byte_offset = ByteOffset > 0 ? offset[ByteOffset-1:0] : 0;
  wire [(BlockOffset>0 ? BlockOffset-1 : 0):0] block_offset = BlockOffset > 0 ? offset[Offset-1:ByteOffset] : 0;

  wire [(Index>0 ? Index-1 : 0):0] index = Index > 0 ? inst_cache_ADR_I[Index+Offset-1:Offset] : 0;

  wire [Tag-1:0] tag = inst_cache_ADR_I[L2_ADDR_SIZE-1:Index+Offset];

  assign inst_cache_DAT_O = cache_data[index][block_offset*(2**(ByteOffset+3))+:(2**(ByteOffset+3))];

  genvar i;
  generate
    for (i = 0; i < Depth; i = i + 1) begin : gen_comparadores
      assign tag_comparisson[i] = ~(|(tag ^ cache_tag[i]));
    end
  endgenerate

  assign TGC_O = cache_valid[index] & tag_comparisson[index];

  assign inst_ADR_O = inst_cache_ADR_I;

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) cache_valid <= 'b0;
    else if (cache_WE_I) begin
      cache_data[index]  <= inst_DAT_I;
      cache_tag[index]   <= tag;
      cache_valid[index] <= 1'b1;
    end
  end
endmodule
