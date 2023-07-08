module sd_cmd_sender (
    input clock,
    input reset,

    input [5:0] cmd_index,
    input [31:0] argument,
    input cmd_valid,

    // interface com o cartão SD
    output mosi,

    output reg sending_cmd
);

  reg cmd_index_reg;
  reg argument_reg;

  always @(posedge clock) begin
    cmd_index_reg <= cmd_index;
    argument_reg  <= argument;
  end

  wire _sending_cmd;
  wire cmd_valid_pulse;

  edge_detector #(
      .RESET_VALUE(0),
      .EDGE_MODE  (0)   // borda de subida
  ) cmd_valid_edge_detector (
      .clock(clock),
      .reset(reset),
      .sinal(cmd_valid),
      .pulso(cmd_valid_pulse)
  );

  wire [5:0] bits_sent;

  // FIXME: valor inicial de 47 bits?
  sync_parallel_counter #(
      .size(6),
      .init_value(48)
  ) bit_counter (
      .clock(clock),
      .load(cmd_valid_pulse),
      .load_value(6'd48),
      .reset(reset),
      .inc_enable(1'b0),
      .dec_enable(_sending_cmd),
      .value(bits_sent)
  );

  wire [47:0] cmd_reg;

  // TODO: how the hell can we calculate crc7?
  register_d #(
      .N(48),
      .reset_value({48{1'b1}})
  ) cmd (
      .clock(clock),
      .reset(reset),
      .enable(1'b1),
      .D(cmd_valid_pulse ? {1'b0, 1'b1, cmd_index_reg, argument_reg, crc7, 1'b1} : {Q[47:1], 1'b1}),
      .Q(cmd_reg)
  );

  assign mosi = cmd_reg[47];
  assign _sending_cmd = bits_sent != 6'b0;
  assign sending_cmd = _sending_cmd;

endmodule
