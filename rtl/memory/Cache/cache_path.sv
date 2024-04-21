
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
    input  logic [DATA_SIZE/BYTE_SIZE-1:0] ctrl_sel,
    input  logic [ADDR_SIZE-1:0] ctrl_addr,
    input  logic [DATA_SIZE-1:0] ctrl_wr_data,
    input  logic ctrl_rd_signed,
    output logic [DATA_SIZE-1:0] ctrl_rd_data,
    /* //// */

    /* Interface com a Unidade de Controle */
    input  logic sample_ctrl_inputs,
    input  logic set_valid,
    input  logic set_tag,
    input  logic set_data,
    input  logic set_dirty,
    input  logic mem_addr_src,
    output logic ctrl_wr_en_d,
    output logic hit,
    output logic dirty
    /* //// */
);
  /* Quantidade de bits para cada campo dos sinais */
  localparam integer Offset = $clog2(BLOCK_SIZE/BYTE_SIZE);
  localparam integer ByteNum = DATA_SIZE/BYTE_SIZE;
  localparam integer DataOffset = $clog2(ByteNum);
  localparam integer BlockOffset = Offset - DataOffset;
  localparam integer Index = $clog2(CACHE_SIZE/BLOCK_SIZE);  // Simple associativity
  localparam integer Tag = ADDR_SIZE - Index - Offset;
  localparam integer Depth = CACHE_SIZE/BLOCK_SIZE;

  logic [Depth-1:0] [BLOCK_SIZE-1:0] cache_data;
  logic [Depth-1:0] [Tag-1:0] cache_tag;
  logic [Depth-1:0] cache_valid, cache_dirty;

  logic [Depth-1:0] tag_comparisson;

  logic [ADDR_SIZE-1:0] ctrl_addr_d;
  logic [DATA_SIZE-1:0] ctrl_wr_data_d, shifted_wr_data, shifted_rd_data;
  logic [ByteNum-1:0] shifted_ctrl_sel;
  logic [DataOffset-1:0] ctrl_shift_sel;
  logic [DataOffset:0] extended_bits;

  /* separação dos campos correspondentes nos sinais de entrada vindos da
  * memória */
  logic [DataOffset-1:0] data_offset;

  logic [BlockOffset-1:0] block_offset;

  logic [Index-1:0] index;

  logic [Tag-1:0] tag;

  genvar i;

  assign data_offset = ctrl_addr_d[DataOffset-1:0];
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

  generate
    for(i = 0; i < DataOffset; i++) begin: gen_ctrl_rd_sel
      assign ctrl_shift_sel[i] = data_offset[i] & ~ctrl_sel[2**(2**i)-1];
    end
  endgenerate

  left_barrel_shifter #(
      .XLEN(ByteNum),
      .YLEN(BYTE_SIZE)
  ) wr_shifter (
      .in_data(ctrl_wr_data_d),
      .shamt(ctrl_shift_sel),
      .out_data(shifted_wr_data)
  );

  left_barrel_shifter #(
      .XLEN(ByteNum),
      .YLEN(1)
  ) sel_shifter (
      .in_data(ctrl_sel),
      .shamt(ctrl_shift_sel),
      .out_data(shifted_ctrl_sel)
  );

  always_ff @(posedge clock iff set_data) begin
    if(set_dirty) begin
      for(int i = 0; i < ByteNum; i++)
        if(shifted_ctrl_sel[i])
          cache_data[index][(block_offset*DATA_SIZE+i*BYTE_SIZE)+:BYTE_SIZE] <=
                                    shifted_wr_data[(i*BYTE_SIZE)+:BYTE_SIZE];
    end else cache_data[index] <= mem_rd_data;
  end

  // Comparisons
  generate
    for (i = 0; i < Depth; i++) begin : gen_comparadores
      assign tag_comparisson[i] = ~(|(tag ^ cache_tag[i]));
    end
  endgenerate

  // Outputs
  // Controller
  barrel_shifter_r #(
    .N(DataOffset),
    .M(BYTE_SIZE)
  ) rd_shifter (
    .A(cache_data[index][block_offset*DATA_SIZE+:DATA_SIZE]),
    .shamt(ctrl_shift_sel),
    .arithmetic(ctrl_rd_signed),
    .Y(shifted_rd_data)
  );

  generate
    for(i = 0; i <= DataOffset; i++) begin: gen_extended_bit
      if(i == 0) assign extended_bits[0] = shifted_rd_data[BYTE_SIZE-1];
      else assign extended_bits[i] = ctrl_sel[2**(2**(i-1))-1] ?
                                     shifted_rd_data[BYTE_SIZE*(2**i)-1] : extended_bits[i-1];
    end
  endgenerate

  generate
    for(i = 0; i < ByteNum; i++) begin: gen_ctrl_rd_data
      assign ctrl_rd_data[i*BYTE_SIZE+:BYTE_SIZE] = ctrl_sel[i] ?
                                      shifted_rd_data[i*BYTE_SIZE+:BYTE_SIZE] :
                                      {BYTE_SIZE{(extended_bits[DataOffset] & ctrl_rd_signed)}};
    end
  endgenerate
  // Memory
  assign mem_addr = mem_addr_src ? {cache_tag[index], index, {Offset{1'b0}}} :
                                   {ctrl_addr_d[ADDR_SIZE-1:Offset], {Offset{1'b0}}};
  assign mem_wr_data = cache_data[index];
  // Control Unit
  assign hit = cache_valid[index] & tag_comparisson[index];
  assign dirty = cache_dirty[index];
endmodule
