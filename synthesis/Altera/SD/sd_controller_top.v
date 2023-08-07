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
    input [3:0] sw,
    output reg [9:0] led
);

  wire clock_100M;

  pll pll_inst (
      .inclk0(clock),
      .c0(clock_100M)
  );


  wire reset = ~n_reset;
  wire [4095:0] read_data;
  wire [4095:0] write_data;
  wire busy;
  wire rd_en;
  wire wr_en;
  wire [31:0] addr;
  wire [15:0] tester_state;
  wire [4:0] sd_controller_state;
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
  wire [7:0] check_cmd_24_dbg;
  wire [7:0] check_cmd_17_dbg;

  sd_controller_test_driver tester (
      /* .clock(clock_50M), */
      .clock(clock_400K),
      .reset(reset),
      .read_data(read_data),
      .busy(busy),
      .rd_en(rd_en),
      .wr_en(wr_en),
      .addr(addr),
      .write_data(write_data),
      .test_driver_state(tester_state)
  );

  sd_controller DUT (
      .clock_400K(clock_400K),
      /* .clock_50M(clock_50M), */
      .clock_50M(clock_400K),
      .reset(reset),
      .rd_en(rd_en),
      .wr_en(wr_en),
      .addr(addr),
      .write_data(write_data),
      .read_data(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .busy(busy),
      /* .bits_received_dbg(bits_received_dbg), */
      .sd_controller_state(sd_controller_state),
      .check_cmd_0_dbg(check_cmd_0_dbg),
      .check_cmd_8_dbg(check_cmd_8_dbg),
      .check_cmd_55_dbg(check_cmd_55_dbg),
      .check_acmd_41_dbg(check_acmd_41_dbg),
      .check_cmd_16_dbg(check_cmd_16_dbg),
      .check_cmd_24_dbg(check_cmd_24_dbg),
      .check_cmd_17_dbg(check_cmd_17_dbg)
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
      4'b0000: led = tester_state[9:0];
      4'b0001: led = {reset, 3'b000, tester_state[15:10]};
      4'b0010: led = {2'b00, check_cmd_0_dbg};
      4'b0011: led = {2'b00, check_cmd_8_dbg};
      4'b0100: led = {2'b00, check_cmd_55_dbg};
      4'b0101: led = {2'b00, check_acmd_41_dbg};
      4'b0110: led = {2'b00, check_cmd_16_dbg};
      4'b0111: led = {2'b00, check_cmd_24_dbg};
      4'b1000: led = {2'b00, check_cmd_17_dbg};
      4'b1001: led = bits_received_dbg[9:0];
      4'b1010: led = read_data[9:0];
      4'b1011: led = read_data[19:10];
      4'b1100: led = read_data[29:20];
      4'b1101: led = read_data[39:30];
      4'b1110: led = read_data[49:40];
      4'b1111: led = {5'b00000, sd_controller_state};
      default: led = 0;
    endcase
  end

endmodule
