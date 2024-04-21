
module cache #(
    parameter integer CACHE_SIZE = 16384
) (
    wishbone_if.secondary wb_if_ctrl,
    wishbone_if.primary wb_if_mem
);

  localparam integer BlockSize = $size(wb_if_mem.dat_i_s);
  localparam integer DataSize = $size(wb_if_ctrl.dat_i_s);
  localparam integer AddrSize = $size(wb_if_ctrl.addr);
  localparam integer ByteSize = DataSize/$size(wb_if_ctrl.sel);
  localparam integer SelSize = $size(wb_if_mem.sel);

  logic hit, dirty, ctrl_wr_en_d, sample_ctrl_inputs, set_valid, set_tag, set_data, set_dirty;
  logic mem_rd_en, mem_wr_en, ctrl_rd_en, ctrl_wr_en;

  // Assume that both clocks and reset are equal
  cache_control #(
    .BYTE_NUM(SelSize)
  ) control (
      .clock(wb_if_ctrl.clock),
      .reset(wb_if_ctrl.reset),
      .mem_ack(wb_if_mem.ack),
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .mem_sel(wb_if_mem.sel),
      .ctrl_rd_en(ctrl_rd_en),
      .ctrl_wr_en(ctrl_wr_en),
      .ctrl_ack(wb_if_ctrl.ack),
      .hit,
      .dirty,
      .ctrl_wr_en_d,
      .sample_ctrl_inputs,
      .set_valid,
      .set_tag,
      .set_data,
      .set_dirty
  );

  cache_path #(
      .CACHE_SIZE(CACHE_SIZE),
      .BLOCK_SIZE(BlockSize),
      .ADDR_SIZE (AddrSize),
      .DATA_SIZE (DataSize),
      .BYTE_SIZE (ByteSize)
  ) path (
      .clock(wb_if_ctrl.clock),
      .reset(wb_if_ctrl.reset),
      .mem_rd_data(wb_if_mem.dat_i_p),
      .mem_wr_data(wb_if_mem.dat_o_p),
      .mem_addr(wb_if_mem.addr),
      .ctrl_wr_en(ctrl_wr_en),
      .ctrl_sel(wb_if_ctrl.sel),
      .ctrl_addr(wb_if_ctrl.addr),
      .ctrl_rd_signed(wb_if_ctrl.tgd),
      .ctrl_wr_data(wb_if_ctrl.dat_i_s),
      .ctrl_rd_data(wb_if_ctrl.dat_o_s),
      .mem_addr_src(mem_wr_en),
      .hit,
      .dirty,
      .ctrl_wr_en_d,
      .sample_ctrl_inputs,
      .set_valid,
      .set_tag,
      .set_data,
      .set_dirty
  );

  always_comb begin
    ctrl_rd_en = wb_if_ctrl.rd_en();
    ctrl_wr_en = wb_if_ctrl.wr_en();
  end

  assign wb_if_mem.cyc = mem_rd_en | mem_wr_en;
  assign wb_if_mem.stb = mem_rd_en | mem_wr_en;
  assign wb_if_mem.we = mem_wr_en;

endmodule
