module sd_controller_tb (
    /* sistema */
    input reset,

    /* cartão SD */
    input  miso,
    output cs,
    output sck,
    output mosi,

    /* depuração */
    output [15:0] tester_state
);

  wire [4095:0] read_data;
  wire busy;
  wire rd_en;
  wire [31:0] addr;

  sd_controller_test_driver tester (
      .clock(),
      .reset(reset),
      .read_data(read_data),
      .busy(busy),
      .rd_en(rd_en),
      .addr(addr),
      .test_driver_state(tester_state)
  );

  sd_controller DUT (
      .clock_400K(),
      .clock_50M(),
      .reset(reset),
      .rd_en(rd_en),
      .addr(addr),
      .read_data(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .busy(busy)
  );

endmodule
