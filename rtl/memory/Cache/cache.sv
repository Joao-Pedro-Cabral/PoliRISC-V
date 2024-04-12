
module cache #(
    parameter integer CACHE_SIZE = 16384,
    parameter integer BLOCK_SIZE = 128,
    parameter integer ADDR_SIZE  = 32,
    parameter integer DATA_SIZE  = 32,
    parameter integer BYTE_SIZE  = 8
) (
    wishbone_if.secondary wb_if_crtl,
    wishbone_if.primary wb_if_mem
);

  logic hit, dirty, crtl_wr_en_d, sample_crtl_inputs, set_valid_tag, set_data, set_dirty;
  logic mem_rd_en, mem_wr_en, crtl_rd_en, crtl_wr_en;

  // Assume that both clocks and reset are equal
  cache_control control (
      .clock(wb_if_crtl.clock),
      .reset(wb_if_crtl.reset),
      .mem_ack(wb_if_mem.ack),
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .crtl_rd_en(crtl_rd_en),
      .crtl_wr_en(crtl_wr_en),
      .crtl_ack(wb_if_crtl.ack),
      .hit,
      .dirty,
      .crtl_wr_en_d,
      .sample_crtl_inputs,
      .set_valid_tag,
      .set_data,
      .set_dirty
  );

  instruction_cache_path #(
      .CACHE_SIZE(CACHE_SIZE),
      .BLOCK_SIZE(BLOCK_SIZE),
      .ADDR_SIZE (ADDR_SIZE),
      .DATA_SIZE (DATA_SIZE),
      .BYTE_SIZE (BYTE_SIZE)
  ) path (
      .clock(wb_if_crtl.clock),
      .reset(wb_if_crtl.reset),
      .mem_rd_data(wb_if_mem.dat_i_p),
      .mem_wr_data(wb_if_mem.dat_o_p),
      .mem_addr(wb_if_mem.addr),
      .crtl_wr_en(crtl_wr_en),
      .crtl_addr(wb_if_crtl.addr),
      .crtl_wr_data(wb_if_crtl.dat_i_s),
      .crtl_rd_data(wb_if_crtl.dat_o_s),
      .hit,
      .dirty,
      .crtl_wr_en_d,
      .sample_crtl_inputs,
      .set_valid_tag,
      .set_data,
      .set_dirty
  );

  always_comb begin
    crtl_rd_en = wb_if_crtl.rd_en();
    crtl_wr_en = wb_if_crtl.wr_en();
  end

endmodule
