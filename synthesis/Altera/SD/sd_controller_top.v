module sd_controller_top (
    /* sistema */
    input n_reset,
    input clock,

    /* cartão SD */
    input  miso,
    output cs,
    output sck,
    output mosi,

    /* depuração */
    input [2:0] sw,
    output reg [9:0] led
);

  wire clock_100M;

  pll pll_inst (
      .inclk0(clock),
      .c0(clock_100M)
  );


  wire reset = ~n_reset;
  wire [4095:0] read_data;
  wire busy;
  wire rd_en;
  wire [31:0] addr;
  wire [15:0] tester_state;
  reg clock_50M;
  reg clock_400K;
  wire [7:0] clock_400K_cnt;
  wire [4:0] clock_50M_cnt;
  wire [4:0] clock_50M_cnt_2;
  wire [12:0] bits_received_dbg;
  wire [7:0] check_cmd_0_dbg;
  wire [7:0] check_cmd_8_dbg;
  wire [7:0] check_cmd_55_dbg;
  wire [7:0] check_acmd_41_dbg;
  wire [7:0] check_cmd_16_dbg;

  sd_controller_test_driver tester (
      /* .clock(clock_50M), */
      .clock(clock_400K),
      .reset(reset),
      .read_data(read_data),
      .busy(busy),
      .rd_en(rd_en),
      .addr(addr),
      .test_driver_state(tester_state)
  );

  sd_controller DUT (
      .clock_400K(clock_400K),
      /* .clock_50M(clock_50M), */
      .clock_50M(clock_400K),
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
      .busy(busy),
      .bits_received_dbg(bits_received_dbg),
      .check_cmd_0_dbg(check_cmd_0_dbg),
      .check_cmd_8_dbg(check_cmd_8_dbg),
      .check_cmd_55_dbg(check_cmd_55_dbg),
      .check_acmd_41_dbg(check_acmd_41_dbg),
      .check_cmd_16_dbg(check_cmd_16_dbg)
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

  always @(*) begin
    case (sw)
      3'b000:  led = tester_state[9:0];
      3'b001:  led = {reset, 3'b000, tester_state[15:10]};
      3'b010:  led = {2'b00, check_cmd_0_dbg};
      3'b011:  led = {2'b00, check_cmd_8_dbg};
      3'b100:  led = {2'b00, check_cmd_55_dbg};
      3'b101:  led = {2'b00, check_acmd_41_dbg};
      3'b110:  led = {2'b00, check_cmd_16_dbg};
      3'b111:  led = {7'b0, bits_received_dbg[12:10]};
      default: led = tester_state[9:0];
    endcase
  end

endmodule
