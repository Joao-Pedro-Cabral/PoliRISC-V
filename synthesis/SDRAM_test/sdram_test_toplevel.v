module sdram_test_toplevel (
    input clk,
	 output sdram_clk,
    input not_reset,

    // interface com a SDRAM
    output [12:0] sdram_a,
    output [1:0] sdram_ba,
    inout [15:0] sdram_dq,
    output sdram_cke,
    output sdram_cs_n,
    output sdram_ras_n,
    output sdram_cas_n,
    output sdram_we_n,
    output sdram_dqml,
    output sdram_dqmh,

    output [9:0] dbg_state

);


  wire reset = ~not_reset;
  wire test_clk;

  pll pll_inst (
      .inclk0(clk),
      .c0(sdram_clk),
      .c1(test_clk)
  );


  // sinais do DUT
  //  entradas do DUT
  wire [23:0] addr;
  wire [31:0] data;
  wire [3:0] bwe;
  wire we;
  wire req;
  //  saídas do DUT
  wire ack;
  wire valid;
  wire [31:0] q;
  ////
  //

  sdram_controller2 #(
      .CLK_FREQ(100)
  ) memory_controller (
      .reset(reset),
      .clk(test_clk),
      .addr(addr),
      .data(data),
      .bwe(bwe),
      .we(we),
      .req(req),
      .ack(ack),
      .valid(valid),
      .q(q),
      .sdram_a(sdram_a),
      .sdram_ba(sdram_ba),
      .sdram_dq(sdram_dq),
      .sdram_cke(sdram_cke),
      .sdram_cs_n(sdram_cs_n),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqml(sdram_dqml),
      .sdram_dqmh(sdram_dqmh)
  );

  sdram_test tester (
      .reset(reset),
      .clk(test_clk),
      .addr(addr),
      .data(data),
      .bwe(bwe),
      .we(we),
      .req(req),
      .ack(ack),
      .valid(valid),
      .q(q),
      .dbg_state(dbg_state)
  );

endmodule
