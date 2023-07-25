module sd_controller_top (
    /* sistema */
    input reset,
    input clock_100M,

    /* cartão SD */
    input  miso,
    output sd_reset,
    output cs,
    output sck,
    output mosi,

    /* depuração */
    input  [ 1:0] sw,
    output [15:0] led
);

  wire [4095:0] read_data;
  wire busy;
  wire rd_en;
  wire [31:0] addr;
  wire [15:0] tester_state;
  reg clock_50M;
  reg clock_50M_2;
  reg clock_400K;
  wire [7:0] clock_400K_cnt;
  wire [4:0] clock_50M_cnt;
  wire [4:0] clock_50M_cnt_2;

  sd_controller_test_driver tester (
      .clock(clock_50M_2),
      .reset(reset),
      .read_data(read_data),
      .busy(busy),
      .rd_en(rd_en),
      .addr(addr),
      .test_driver_state(tester_state)
  );

  sd_controller DUT (
      .clock_400K(clock_400K),
      .clock_50M(clock_50M),
      .reset(reset),
      .rd_en(rd_en),
      .wr_en(1'b0),
      .addr(addr),
      .write_data(4096'b0),
      .read_data(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .busy(busy)
  );

  // Gerar clock de 12,5 MHz
  sync_parallel_counter #(
      .size(5),
      .init_value(0)
  ) clock_50M_gen (
      .clock(clock_100M),
      .reset(reset),
      .load(clock_50M_cnt == 16),  // Carrega a cada nova transmissão
      .load_value(5'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(clock_50M_cnt)
  );

  always @(posedge clock_100M) begin
    if (reset) clock_50M <= 1'b0;
    else if (clock_50M_cnt == 16) clock_50M <= ~clock_50M;
    else clock_50M <= clock_50M;
  end

  // Gerar clock de 12,5 MHz
  sync_parallel_counter #(
      .size(5),
      .init_value(0)
  ) clock_50M_gen_2 (
      .clock(clock_100M),
      .reset(reset),
      .load(clock_50M_cnt_2 == 16),  // Carrega a cada nova transmissão
      .load_value(5'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(clock_50M_cnt_2)
  );

  always @(posedge clock_100M) begin
    if (reset) clock_50M_2 <= 1'b0;
    else if (clock_50M_cnt_2 == 16) clock_50M_2 <= ~clock_50M_2;
    else clock_50M_2 <= clock_50M_2;
  end

  // Gerar clock de 400 KHz
  sync_parallel_counter #(
      .size(8),
      .init_value(0)
  ) clock_400K_gen (
      .clock(clock_100M),
      .reset(reset),
      .load(clock_400K_cnt == 125),  // Carrega a cada nova transmissão
      .load_value(8'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(clock_400K_cnt)
  );

  always @(posedge clock_100M) begin
    if (reset) clock_400K <= 1'b0;
    else if (clock_400K_cnt == 125) clock_400K <= ~clock_400K;
    else clock_400K <= clock_400K;
  end

  assign led = sw[0] ? (sw[1] ? read_data[31:16] : read_data[15:0]) : tester_state;
  assign sd_reset = reset;

endmodule
