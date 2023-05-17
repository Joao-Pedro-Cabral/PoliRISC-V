//
//! @file   instruction_cache_path.v
//! @brief  Implementação de um controlador de cache para uma memória
//          ROM de instruções
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

`timescale 1 ns / 100 ps

module instruction_cache_path #(
    parameter integer L2_CACHE_SIZE = 3,  // log_2(tamanho da cache em bytes)
    parameter integer L2_BLOCK_SIZE = 2   // log_2(tamanho do bloco em bytes)
) (
    /* Sinais do sistema */
    input reset,
    /* //// */

    /* Interface com a memória de instruções */
    input  [63:0] inst_data,
    output [63:0] inst_addr,
    /* //// */

    /* Interface com o controlador de memória */
    input  [63:0] inst_cache_addr,
    output [63:0] inst_cache_data,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input  cache_write_enable,
    output hit
    /* //// */
);
  /* Quantidade de bits para cada campo dos sinais */
  localparam integer OFFSET = L2_BLOCK_SIZE;
  localparam integer INDEX = L2_CACHE_SIZE - OFFSET;
  localparam integer TAG = 64 - OFFSET - INDEX;
  localparam integer DEPTH = 2 ** (L2_CACHE_SIZE - L2_BLOCK_SIZE);

  reg  [2**(OFFSET+3)-1:0] cache_data                                     [0:DEPTH-1];
  reg  [          TAG-1:0] cache_tag                                      [0:DEPTH-1];
  reg  [        DEPTH-1:0] cache_valid;


  wire [        DEPTH-1:0] tag_comparisson;
  wire [             31:0] instruction;  // dados lidos da cache

  wire [        INDEX-1:0] index = inst_cache_addr[INDEX+OFFSET-1:OFFSET];
  wire [          TAG-1:0] tag = inst_cache_addr[63:INDEX+OFFSET];

  genvar i;
  generate
    for (i = 0; i < (4) / (2 ** OFFSET); i = i + 1) begin : gen_dado_saida
      assign instruction[(i+1)*8*2**OFFSET-1:i*8*2**OFFSET] = cache_data[index+i];
    end

    for (i = 0; i < DEPTH; i = i + 1) begin : gen_comparadores
      assign tag_comparisson[i] = ~(|(tag[TAG-1:0] ^ cache_tag[i]));
    end
  endgenerate

  assign hit = cache_valid[index] & tag_comparisson[index];

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  generate
    if (OFFSET != 0) wire [OFFSET-1:0] offset = inst_cache_addr[OFFSET-1:0];
    else wire offset = 0;
  endgenerate

  assign inst_addr = inst_cache_addr;
  assign inst_cache_data = {32'b0, instruction};

  integer j;
  always @(posedge cache_write_enable, posedge reset) begin
    if (reset) cache_valid <= 'b0;
    else if (cache_write_enable) begin
      /* Escreve 8 bytes na memória cache */
      for (j = 0; j < (8) / (2 ** OFFSET); j = j + 1) begin
        cache_data[index+j]  <= inst_data[(j+1)*(2**(OFFSET+3))-1-:(2**(OFFSET+3))];
        cache_tag[index+j]   <= tag;
        cache_valid[index+j] <= 1'b1;
      end
    end else begin
      for (j = 0; j < (8) / (2 ** OFFSET); j = j + 1) begin
        cache_data[index+j]  <= cache_data[index+j];
        cache_tag[index+j]   <= cache_tag[index+j];
        cache_valid[index+j] <= cache_valid[index+j];
      end
    end
  end
endmodule
