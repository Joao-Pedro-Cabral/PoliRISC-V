//
//! @file   micro_cache.v
//! @brief  Implementação de um cache para uma memória
//          ROM de instruções alinhada em 16 bits
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-02
//

`timescale 1 ns / 100 ps

module instruction_cache
#(
  parameter L2_CACHE_SIZE = 3, // log_2(tamanho da cache em bytes)
  parameter L2_BLOCK_SIZE = 2  // log_2(tamanho do bloco em bytes)
)
(
  /* Sinais do sistema */
  input clock,
  input reset,
  /* //// */

  /* Interface com a memória de instruções */
  input  [63:0] inst_data,
  input  inst_busy,
  output inst_enable,
  output [63:0] inst_addr,
  /* //// */

  /* Interface com o controlador de memória */
  input  inst_cache_enable,
  input  [63:0] inst_cache_addr,
  output [63:0] inst_cache_data,
  output reg inst_cache_busy
  /* //// */

);

  /* Quantidade de bits para cada campo dos sinais */
  localparam OFFSET = L2_BLOCK_SIZE;
  localparam INDEX  = L2_CACHE_SIZE - OFFSET;
  localparam TAG    = 64 - OFFSET - INDEX;
  localparam DEPTH  = 2**(L2_CACHE_SIZE-L2_BLOCK_SIZE);

  reg [2**(OFFSET+3)-1:0] cache_data  [DEPTH-1:0];
  reg [TAG-1:0]           cache_tag   [DEPTH-1:0];
  reg [INDEX-1:0]         cache_index [DEPTH-1:0];
  reg [DEPTH-1:0]         cache_valid;
  wire                    hit;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  generate
    if(OFFSET!=0)
      wire [OFFSET-1:0] offset = inst_cache_addr[OFFSET-1:0];
    else
      wire offset = 0;
  endgenerate
  wire [INDEX-1:0] index = inst_cache_addr[INDEX+OFFSET-1:OFFSET];
  wire [TAG-1:0]   tag   = inst_cache_addr[63:INDEX+OFFSET];

  wire [DEPTH-1:0] tag_comparisson;
  wire [31:0] instruction; // dados lidos da cache
  genvar i;
  genvar sum;
  generate
    for(i=0; i<(4)/(2**OFFSET); i=i+1)
    begin : dado_saida
      assign instruction[(i+1)*8*2**OFFSET-1:i*8*2**OFFSET] = cache_data[index+i];
    end

    for(i=0; i<DEPTH; i=i+1) 
    begin : comparadores
      assign tag_comparisson[i] = ~(|(tag[TAG-1:0] ^ cache_tag[i])); 
    end
  endgenerate

  assign hit = cache_valid[index] & tag_comparisson[index];

  assign inst_cache_data = {32'b0, instruction};
  assign inst_addr   = inst_cache_addr;
  assign inst_enable = hit ? 1'b0 : inst_cache_enable;

  localparam [1:0]
      hit_state = 2'b00,
      miss_state = 2'b01,
      default_state = 2'b11;

  reg [1:0] current_state, next_state;

  always @(posedge clock, posedge reset)
  begin
      if(reset)
        current_state <= default_state;
      else if(clock == 1'b1)
        current_state <= next_state;
  end

  always @(*)
  begin
    case(current_state) // synthesis parallel_case
      default:
      begin
        inst_cache_busy = 1'b0;

        if(inst_cache_enable)
        begin
          if(hit)
            next_state = hit_state;
          else
            next_state = miss_state;
        end
        else
          next_state = default_state;
      end

      hit_state:
      begin
        inst_cache_busy = 1'b1;
        next_state = default_state;
      end

      miss_state:
      begin
        inst_cache_busy = 1'b1;
        next_state = inst_busy ? miss_state : default_state;
      end
    endcase
  end

  integer j;
  wire write_condition = (current_state==miss_state && inst_busy==1'b0) ? 1'b1 : 1'b0;
  always @(write_condition, reset)
  begin
    if(reset==1'b1)
	    cache_valid   <= 'b0;
	 else if(write_condition==1'b1)
	 begin
		 /* Escreve 8 bytes na memória cache */
		 for(j=0; j<(8)/(2**OFFSET); j=j+1)
			  cache_data[index+j] <= inst_data[(j+1)*(2**(OFFSET+3))-1-:(2**(OFFSET+3))];
		 cache_tag[index] <= tag;
		 cache_valid[index] <= 1'b1;
	 end
  end
endmodule
