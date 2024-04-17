
module cache_path #(
    parameter integer CACHE_SIZE = 131072,
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
    input  logic ctrl_wr_en,
    input  logic [ADDR_SIZE-1:0] ctrl_addr,
    input  logic [DATA_SIZE-1:0] ctrl_wr_data,
    output logic [DATA_SIZE-1:0] ctrl_rd_data,
    /* //// */

    /* Interface com a Unidade de Controle */
    input  logic sample_ctrl_inputs,
    input  logic set_valid,
    input  logic set_tag,
    input  logic set_data,
    input  logic set_dirty,
    output logic ctrl_wr_en_d,
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

  logic [Depth-1:0] [BLOCK_SIZE-1:0] cache_data;
  logic [Depth-1:0] [Tag-1:0] cache_tag;
  logic [Depth-1:0] cache_valid, cache_dirty;

  logic [Depth-1:0] tag_comparisson;

  logic [ADDR_SIZE-1:0] ctrl_addr_d;
  logic [DATA_SIZE-1:0] ctrl_wr_data_d;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  logic [BlockOffset-1:0] block_offset;

  logic [Index-1:0] index;

  logic [Tag-1:0] tag;

  assign block_offset = ctrl_addr_d[Offset-1:DataOffset];
  assign index = ctrl_addr_d[Index+Offset-1:Offset];
  assign tag = ctrl_addr_d[ADDR_SIZE-1:Index+Offset];

  // buffering signals coming from the Controller
  always_ff @(posedge clock iff sample_ctrl_inputs) begin
    ctrl_addr_d <= ctrl_addr;
    ctrl_wr_data_d <= ctrl_wr_data;
    ctrl_wr_en_d <= ctrl_wr_en;
  end

  // Cache
  always_ff @(posedge clock, posedge reset) begin
    if (reset) cache_valid <= 'b0;
    else if(set_valid) cache_valid[index] <= 1'b1;
  end

  always_ff @(posedge clock iff set_tag) begin
    cache_tag[index] <= tag;
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) cache_dirty <= 'b0;
    else if(set_data) cache_dirty[index] <= set_dirty;
  end

  always_ff @(posedge clock iff set_data) begin
    if(set_dirty) cache_data[index][block_offset*DATA_SIZE+:DATA_SIZE]  <= ctrl_wr_data_d;
    else cache_data[index] <= mem_rd_data;
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
  assign ctrl_rd_data = cache_data[index][block_offset*DATA_SIZE+:DATA_SIZE];
  // Memory
  assign mem_addr = ctrl_addr_d;
  assign mem_wr_data = cache_data[index];
  // Control Unit
  assign hit = cache_valid[index] & tag_comparisson[index];
  assign dirty = cache_dirty[index];
endmodule
