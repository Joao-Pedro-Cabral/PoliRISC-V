
import board_pkg::*;

module sd_controller_top (
    /* sistema */
    input reset,
    input clock,

    /* cartão SD */
    input  miso,
    output sd_reset,
    output cs,
    output sck,
    output mosi,

    /* depuração */
    input [4:0] sw,
    output reg [LedSize-1:0] led
);

  import sd_controller_pkg::*;
  import sd_receiver_pkg::*;
  import sd_sender_pkg::*;

  wire clock_100M;

  wishbone_if #(.DATA_SIZE(4096), .BYTE_SIZE(8), .ADDR_SIZE(32)) wb_if (.clock(clock_100M), .reset);
  wire [4095:0] read_data;
  wire [15:0] tester_state;
  wire [15:0] tester_state_return;
  sd_controller_fsm_t sd_controller_state_db;
  sd_receiver_fsm_t sd_receiver_state_db;
  sd_sender_fsm_t sd_sender_state_db;
  wire [12:0] bits_received_db;
  wire [7:0] check_cmd_0_db;
  wire [7:0] check_cmd_8_db;
  wire [7:0] check_cmd_55_db;
  wire [7:0] check_cmd_59_db;
  wire [7:0] check_acmd_41_db;
  wire [7:0] check_cmd_16_db;
  wire [7:0] check_cmd_24_db;
  wire [7:0] check_write_db;
  wire [15:0] check_cmd_13_db;
  wire [7:0] check_cmd_17_db;
  wire [7:0] check_read_db;
  wire [7:0] check_error_token_db;
  wire crc_error;
  wire [15:0] crc16_db;

  sd_controller_test_driver tester (
      .clock(clock_100M),
      .reset(reset),
      .wb_if_p(wb_if),
      .test_driver_state(tester_state),
      .test_driver_state_return(tester_state_return)
  );

  sd_controller DUT (
      .wb_if_s(wb_if),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .sd_controller_state_db(sd_controller_state_db),
      .sd_receiver_state_db(sd_receiver_state_db),
      .sd_sender_state_db(sd_sender_state_db),
      .check_cmd_0_db(check_cmd_0_db),
      .check_cmd_8_db(check_cmd_8_db),
      .check_cmd_55_db(check_cmd_55_db),
      .check_cmd_59_db(check_cmd_59_db),
      .check_acmd_41_db(check_acmd_41_db),
      .check_cmd_16_db(check_cmd_16_db),
      .check_cmd_24_db(check_cmd_24_db),
      .check_write_db(check_write_db),
      .check_cmd_13_db(check_cmd_13_db),
      .check_cmd_17_db(check_cmd_17_db),
      .check_read_db(check_read_db),
      .check_error_token_db(check_error_token_db),
      .crc_error_db(crc_error),
      .crc16_db(crc16_db)
  );

  assign read_data = wb_if.dat_i_p;

  generate
    if(Nexys4) begin: gen_nexys4_outputs
      always_comb begin
        unique case (sw)
          5'b00000: led = tester_state[15:0];
          5'b00001: led = {check_cmd_8_db, check_cmd_0_db};
          5'b00010: led = {check_cmd_55_db, check_cmd_59_db};
          5'b00011: led = {check_cmd_16_db, check_acmd_41_db};
          5'b00100: led = {check_write_db, check_cmd_24_db};
          5'b00101: led = {check_read_db, check_cmd_17_db};
          5'b00110: led = {8'b0, check_error_token_db};
          5'b00111: led = check_cmd_13_db;
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
          5'b11000: led = tester_state_return;
          5'b11001: led = read_data[4015:4000];
          5'b11010: led = read_data[4031:4016];
          5'b11011: led = read_data[4047:4032];
          5'b11100: led = read_data[4063:4048];
          5'b11101: led = read_data[4079:4064];
          5'b11110: led = read_data[4095:4080];
          5'b11111: led = {6'b0, reset, crc_error, 3'b000, sd_controller_state_db};
          default:  led = 0;
        endcase
      end
      assign clock_100M = clock;
      assign sd_reset = reset;
    end else begin: gen_de10_outputs
      always_comb begin
        case (sw)
          5'b00000: led = tester_state[9:0];
          5'b00001: led = {reset, crc_error, 2'b00, tester_state[15:10]};
          5'b00010: led = {2'b00, check_cmd_0_db};
          5'b00011: led = {2'b00, check_cmd_8_db};
          5'b00100: led = {2'b00, check_cmd_59_db};
          5'b00101: led = {2'b00, check_cmd_55_db};
          5'b00110: led = {2'b00, check_acmd_41_db};
          5'b00111: led = {2'b00, check_cmd_16_db};
          5'b01000: led = {2'b00, check_cmd_24_db};
          5'b01001: led = {2'b00, check_write_db};
          5'b01010: led = {2'b00, check_cmd_17_db};
          5'b01011: led = {2'b00, check_read_db};
          5'b01100: led = {2'b00, check_error_token_db};
          5'b01101: led = {2'b00, check_cmd_13_db[7:0]};
          5'b01110: led = {2'b00, check_cmd_13_db[15:8]};
          5'b01111: led = {2'b00, crc16_db[7:0]};
          5'b10000: led = {2'b00, crc16_db[15:8]};
          5'b10001: led = read_data[3965:3956];
          5'b10010: led = read_data[3975:3966];
          5'b10011: led = read_data[3985:3976];
          5'b10100: led = tester_state_return[9:0];
          5'b10101: led = {read_data[3999:3996], tester_state_return[15:10]};
          5'b10110: led = read_data[4015:4006];
          5'b10111: led = read_data[4025:4016];
          5'b11000: led = read_data[4035:4026];
          5'b11001: led = read_data[4045:4036];
          5'b11010: led = read_data[4055:4046];
          5'b11011: led = read_data[4065:4056];
          5'b11100: led = read_data[4075:4066];
          5'b11101: led = read_data[4085:4076];
          5'b11110: led = read_data[4095:4086];
          5'b11111: led = {2'b00, sd_sender_state_db, sd_receiver_state_db, sd_controller_state_db};
          default:  led = 0;
        endcase
      end
      pll pll_inst (
        .inclk0(clock),
        .c0(clock_100M)
      );
      assign sd_reset = 1'b0;
    end
  endgenerate

endmodule
