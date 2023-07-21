//
//! @file   sd_sender.v
//! @brief  Implementação de um expedidor SPI para um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-08
//

module sd_sender (
    input clock,
    input reset,

    input [5:0] cmd_index,
    input [31:0] argument,
    input [4095:0] data,
    input cmd_or_data,  // 0: cmd; 1: data
    input cmd_valid,

    // interface com o cartão SD
    output wire mosi,

    output wire sending_cmd
);

  reg [5:0] cmd_index_reg;
  reg [31:0] argument_reg;
  reg [4095:0] data_reg;
  reg cmd_or_data_reg;

  wire _sending_cmd;
  wire cmd_valid_pulse;
  wire [12:0] bits_sent;
  wire [39:0] cmd_reg;
  wire [6:0] crc7;
  // CRC generate is complete
  wire crc_complete = cmd_or_data_reg ? (bits_sent <= 17) : ((bits_sent <= 8) & _sending_cmd);

  always @(posedge clock) begin
    if (cmd_valid && !_sending_cmd) begin
      cmd_index_reg   <= cmd_index;
      argument_reg    <= argument;
      data_reg        <= data;
      cmd_or_data_reg <= cmd_or_data;
    end
  end

  edge_detector #(
      .RESET_VALUE(0),
      .EDGE_MODE  (0)   // borda de subida
  ) cmd_valid_edge_detector (
      .clock(clock),
      .reset(reset),
      .sinal(cmd_valid),
      .pulso(cmd_valid_pulse)
  );

  sync_parallel_counter #(
      .size(13),
      .init_value(0)
  ) bit_counter (
      .clock(clock),
      .load(cmd_valid_pulse && !_sending_cmd),
      .load_value(cmd_or_data_reg ? 13'd4120 : 13'd48),
      .reset(reset),
      .inc_enable(1'b0),
      .dec_enable(_sending_cmd),
      .value(bits_sent)
  );

  register_d #(
      .N(4104),
      .reset_value({4104{1'b1}})
  ) reg_cmd (
      .clock(clock),
      .reset(reset),
      .enable(1'b1),
      .D((cmd_valid_pulse && !_sending_cmd) ?
            (cmd_or_data_reg ?
                {8'b0, data_reg} : {1'b0, 1'b1, cmd_index_reg, argument_reg, {4064{1'b1}}})
            : {cmd_reg[4102:0], 1'b1}),
      .Q(cmd_reg)
  );

  assign mosi = crc_complete ? (cmd_or_data_reg ? crc16[15] : crc7[6]) : cmd_reg[39];
  assign _sending_cmd = bits_sent != 13'b0;
  // OR: garantir q sending_cmd suba no ciclo seguinte a subida do cmd_valid
  assign sending_cmd = _sending_cmd | cmd_valid_pulse;

  // LFSR + shift reg para calcular e amostrar o CRC7
  // TODO: adicionar cálculo do crc16
  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : g_crc
      if (i == 0) begin : g_crc_0
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg_0 (
            .clock(clock),
            .reset(cmd_valid_pulse && !_sending_cmd),
            .enable(1'b1),
            // Quando o CRC está completo, realiza-se shift
            .D(crc_complete ? 1'b1 : crc7[6] ^ cmd_reg[39]),
            .Q(crc7[0])
        );
      end else if (i == 3) begin : g_crc_3
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg_3 (
            .clock(clock),
            .reset(cmd_valid_pulse && !_sending_cmd),
            .enable(1'b1),
            // Quando o CRC está completo, realiza-se shift
            .D(crc_complete ? crc7[2] : crc7[6] ^ cmd_reg[39] ^ crc7[2]),
            .Q(crc7[3])
        );
      end else begin : g_crc_i
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg (
            .clock(clock),
            .reset(cmd_valid_pulse && !_sending_cmd),
            .enable(1'b1),
            .D(crc7[i-1]),  // Sempre faz shift
            .Q(crc7[i])
        );
      end
    end
  endgenerate

endmodule
