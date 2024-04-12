
module cache_path #(
    parameter integer CACHE_SIZE = 16384,
    parameter integer BLOCK_SIZE = 128,
    parameter integer ADDR_SIZE  = 32,
    parameter integer DATA_SIZE  = 32,
    parameter integer BYTE_SIZE  = 8
) (
    /* Sinais do sistema */
    input logic reset,
    input logic clock,
    /* //// */

    /* Interface com a memória de instruções */
    input  logic [BLOCK_SIZE-1:0] mem_rd_data,
    output logic [BLOCK_SIZE-1:0] mem_wr_data,
    output logic [ADDR_SIZE-1:0] mem_addr,
    /* //// */

    /* Interface com o controlador de memória */
    input  logic crtl_wr_en,
    input  logic [ADDR_SIZE-1:0] crtl_addr,
    input  logic [DATA_SIZE:-10] crtl_wr_data,
    output logic [DATA_SIZE-1:0] crtl_rd_data,
    /* //// */

    /* Interface com a Unidade de Controle */
    input  logic sample_crtl_inputs,
    input  logic set_valid_tag,
    input  logic set_data,
    input  logic set_dirty,
    output logic crtl_wr_en_d,
    output logic hit,
    output logic dirty
    /* //// */
);
  /* Quantidade de bits para cada campo dos sinais */
  localparam integer Offset = $clog2(BLOCK_SIZE/BYTE_SIZE);
  localparam integer DataOffset = $clog2(DATA_SIZE/BYTE_SIZE);
  localparam integer BlockOffset = Offset - DataOffset;
  localparam integer Index = $clog2(CACHE_SIZE/BLOCK_SIZE);  // Simple associativity
  localparam integer Tag = ADDR_SIZE - Index - Offset;
  localparam integer Depth = CACHE_SIZE/BLOCK_SIZE;

  logic [BLOCK_SIZE-1:0] [Depth-1:0] cache_data;
  logic [Tag-1:0] [Depth-1:0] cache_tag;
  logic [Depth-1:0] cache_valid, cache_dirty;

  logic [Depth-1:0] tag_comparisson;

  logic [ADDR_SIZE-1:0] crtl_addr_d;
  logic [DATA_SIZE:-10] crtl_wr_data_d;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  logic [BlockOffset-1:0] block_offset = crtl_addr_d[Offset-1:DataOffset];

  logic [Index-1:0] index = crtl_addr[Index+Offset-1:Offset];

  logic [Tag-1:0] tag = crtl_addr[ADDR_SIZE-1:Index+Offset];

  // buffering signals coming from the Controller
  always_ff @(posedge clock iff sample_crtl_inputs) begin
    crtl_addr_d <= crtl_addr;
    crtl_wr_data_d <= crtl_wr_data;
    crtl_wr_en_d <= crtl_wr_en;
  end

  // Cache
  always_ff @(posedge clock, posedge reset) begin
    if (reset) cache_valid <= 'b0;
    else if(set_valid_tag) begin
        cache_tag[index]   <= tag;
        cache_valid[index] <= 1'b1;
    end
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) cache_dirty <= 'b0;
    else if(set_data) begin
      if(set_dirty) begin
        cache_data[index][block_offset*DATA_SIZE+:DATA_SIZE]  <= crtl_wr_data_d;
        cache_dirty[index] <= 1'b1;
      end else begin
        cache_data[index]  <= mem_rd_data;
        cache_dirty[index] <= 1'b0;
      end
    end
  end

  // Comparisons
  genvar i;
  generate
    for (i = 0; i < Depth; i = i + 1) begin : gen_comparadores
      assign tag_comparisson[i] = ~(|(tag ^ cache_tag[i]));
    end
  endgenerate

  // Outputs
  // Controller
  assign crtl_rd_data = cache_data[index][block_offset*DATA_SIZE+:DATA_SIZE];
  // Memory
  assign mem_addr = crtl_addr_d;
  assign mem_wr_data = cache_data[index];
  // Control Unit
  assign hit = cache_valid[index] & tag_comparisson[index];
  assign dirty = cache_dirty[index];
endmodule
