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
    input [4:0] sw,
`ifdef NEXYS4
    output reg [15:0] led
`else
    output reg [9:0] led
`endif
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
  wire [7:0] check_cmd_59_dbg;
  wire [7:0] check_acmd_41_dbg;
  wire [7:0] check_cmd_16_dbg;
  wire [7:0] check_cmd_24_dbg;
  wire [7:0] check_write_dbg;
  wire [15:0] check_cmd_13_dbg;
  wire [7:0] check_cmd_17_dbg;
  wire [7:0] check_read_dbg;
  wire [7:0] check_error_token_dbg;
  wire crc_error;

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

  sd_controller2 DUT (
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
      .check_cmd_59_dbg(check_cmd_59_dbg),
      .check_acmd_41_dbg(check_acmd_41_dbg),
      .check_cmd_16_dbg(check_cmd_16_dbg),
      .check_cmd_24_dbg(check_cmd_24_dbg),
      .check_write_dbg(check_write_dbg),
      .check_cmd_13_dbg(check_cmd_13_dbg),
      .check_cmd_17_dbg(check_cmd_17_dbg),
      .check_read_dbg(check_read_dbg),
      .check_error_token_dbg(check_error_token_dbg),
      .crc_error_dbg(crc_error)
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

`ifdef NEXYS4
  always @(*) begin
    case (sw)
      5'b00000: led = tester_state[15:0];
      5'b00001: led = {check_cmd_8_dbg, check_cmd_0_dbg};
      5'b00010: led = {check_cmd_55_dbg, check_cmd_59_dbg};
      5'b00011: led = {check_cmd_16_dbg, check_acmd_41_dbg};
      5'b00100: led = {check_write_dbg, check_cmd_24_dbg};
      5'b00101: led = {check_read_dbg, check_cmd_17_dbg};
      5'b00110: led = {check_error_token_dbg, };
      5'b00111: led = check_cmd_13_dbg;
      5'b01000: led = read_data[15:0];
      5'b01001: led = read_data[31:16];
      5'b01010: led = read_data[47:32];
      5'b01011: led = read_data[63:48];
      5'b01100: led = read_data[79:64];
      5'b01101: led = read_data[95:80];
      5'b01110: led = read_data[111:96];
      5'b01111: led = read_data[127:112];
      5'b10000: led = read_data[143:128];
      5'b10001: led = read_data[159:144];
      5'b10010: led = read_data[3903:3888];
      5'b10011: led = read_data[3919:3904];
      5'b10100: led = read_data[3935:3920];
      5'b10101: led = read_data[3951:3936];
      5'b10110: led = read_data[3967:3952];
      5'b10111: led = read_data[3983:3968];
      5'b11000: led = read_data[3999:3984];
      5'b11001: led = read_data[4015:4000];
      5'b11010: led = read_data[4031:4016];
      5'b11011: led = read_data[4047:4032];
      5'b11100: led = read_data[4063:4048];
      5'b11101: led = read_data[4079:4064];
      5'b11110: led = read_data[4095:4080];
      5'b11111: led = {6'b0, reset, crc_error, 3'b000, sd_controller_state};
      default:  led = 0;
    endcase
  end
`else
  always @(*) begin
    case (sw)
      5'b00000: led = tester_state[9:0];
      5'b00001: led = {reset, crc_error, 2'b00, tester_state[15:10]};
      5'b00010: led = {2'b00, check_cmd_0_dbg};
      5'b00011: led = {2'b00, check_cmd_8_dbg};
      5'b00100: led = {2'b00, check_cmd_59_dbg};
      5'b00101: led = {2'b00, check_cmd_55_dbg};
      5'b00110: led = {2'b00, check_acmd_41_dbg};
      5'b00111: led = {2'b00, check_cmd_16_dbg};
      5'b01000: led = {2'b00, check_cmd_24_dbg};
      5'b01001: led = {2'b00, check_write_dbg};
      5'b01010: led = {2'b00, check_cmd_17_dbg};
      5'b01011: led = {2'b00, check_read_dbg};
      5'b01100: led = {2'b00, check_error_token_dbg};
      5'b01101: led = {2'b00, check_cmd_13_dbg[7:0]};
      5'b01110: led = {2'b00, check_cmd_13_dbg[15:8]};
      5'b01111: led = read_data[3945:3936];
      5'b10000: led = read_data[3955:3946];
      5'b10001: led = read_data[3965:3956];
      5'b10010: led = read_data[3975:3966];
      5'b10011: led = read_data[3985:3976];
      5'b10100: led = read_data[3995:3986];
      5'b10101: led = read_data[4005:3996];
      5'b10110: led = read_data[4015:4006];
      5'b10111: led = read_data[4025:4016];
      5'b11000: led = read_data[4035:4026];
      5'b11001: led = read_data[4045:4036];
      5'b11010: led = read_data[4055:4046];
      5'b11011: led = read_data[4065:4056];
      5'b11100: led = read_data[4075:4066];
      5'b11101: led = read_data[4085:4076];
      5'b11110: led = read_data[4095:4086];
      5'b11111: led = {5'b00000, sd_controller_state};
      default:  led = 0;
    endcase
  end
`endif
endmodule
