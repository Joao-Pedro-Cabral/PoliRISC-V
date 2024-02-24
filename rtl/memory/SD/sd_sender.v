//
//! @file   sd_sender.v
//! @brief  Implementação de um expedidor SPI para um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-08
//

`include "macros.vh"
`include "boards.vh"

module sd_sender (
    input wire clock,
    input wire reset,

    // interface com o controlador
    input wire [5:0] cmd_index,
    input wire [31:0] argument,
    input wire cmd_or_data,  // 0: cmd; 1: data
    output wire ready,
    input wire valid,
    input wire [4095:0] data,

    // interface com o cartão SD
    output wire mosi

`ifdef DEBUG
    ,
    output wire sender_state,
    output reg [15:0] crc16_dbg
`endif

);

  reg cmd_or_data_reg;
  reg _ready;
  wire _mosi;

  wire [12:0] bits_sent;
  wire [4103:0] cmd_reg;

  localparam reg Idle = 1'b0, Sending = 1'b1;
  reg state, new_state;
  reg sending;

  sync_parallel_counter #(
      .size(13),
      .init_value(0)
  ) bit_counter (
      .clock(clock),
      .load(_ready & valid),
      .load_value(cmd_or_data ? 13'd4120 : 13'd48),
      .reset(reset),
      .inc_enable(1'b0),
      .dec_enable(sending),
      .value(bits_sent)
  );

  register_d #(
      .N(4104),
      .reset_value({4104{1'b1}})
  ) reg_cmd (
      .clock(clock),
      .reset(reset),
      .enable((_ready & valid) | sending),
      .D((~sending) ?
            (cmd_or_data ?
                {8'hFE, data} : {1'b0, 1'b1, cmd_index, argument, {4064{1'b1}}})
            : {cmd_reg[4102:0], 1'b1}),
      .Q(cmd_reg)
  );

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      state <= Idle;
      cmd_or_data_reg <= 1'b0;
    end else begin
      state <= new_state;
      cmd_or_data_reg <= (valid & _ready) ? cmd_or_data : cmd_or_data_reg;
    end
  end

  task automatic reset_signals;
    begin
      _ready = 1'b0;
      sending = 1'b0;
    end
  endtask

  always @* begin
    reset_signals;

    case (state)
      Idle: begin
        _ready = 1'b1;
        if (valid) begin
          new_state = Sending;
        end else new_state = state;
      end

      Sending: begin
        sending = |bits_sent;
        if (bits_sent == 0) new_state = Idle;
        else new_state = state;
      end

      default: begin
        new_state = Idle;
      end
    endcase
  end

  wire [6:0] crc7;
  reg [15:0] crc16;
  // CRC generate is complete
  wire crc_complete =
    cmd_or_data_reg ? (bits_sent <= 13'd16 && sending) : (bits_sent <= 13'd8 && sending);

  // CRC16 com LFSR
  always @(posedge clock) begin
    // Limpa quando enviar o start token
    if (bits_sent == 13'd4113) begin
      crc16 <= 16'b0;
    end else if (!crc_complete) begin  // Calcular CRC
      crc16[0] <= crc16[15] ^ _mosi;
      crc16[4:1] <= crc16[3:0];
      crc16[5] <= crc16[4] ^ crc16[15] ^ _mosi;
      crc16[11:6] <= crc16[10:5];
      crc16[12] <= crc16[11] ^ crc16[15] ^ _mosi;
      crc16[15:13] <= crc16[14:12];
    end else begin  // Shift
      crc16 <= {crc16[14:0], 1'b1};
    end
  end

  // LFSR + shift reg para calcular e amostrar o CRC7
  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : g_crc
      if (i == 0) begin : g_crc_0
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg_0 (
            .clock(clock),
            .reset(_ready & valid),
            .enable(1'b1),
            // Quando o CRC está completo, realiza-se shift
            .D(crc_complete ? 1'b1 : crc7[6] ^ _mosi),
            .Q(crc7[0])
        );
      end else if (i == 3) begin : g_crc_3
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg_3 (
            .clock(clock),
            .reset(_ready & valid),
            .enable(1'b1),
            // Quando o CRC está completo, realiza-se shift
            .D(crc_complete ? crc7[2] : crc7[6] ^ _mosi ^ crc7[2]),
            .Q(crc7[3])
        );
      end else begin : g_crc_i
        register_d #(
            .N(1),
            .reset_value(1'b0)
        ) crc_reg (
            .clock(clock),
            .reset(_ready & valid),
            .enable(1'b1),
            .D(crc7[i-1]),  // Sempre faz shift
            .Q(crc7[i])
        );
      end
    end
  endgenerate

  assign ready = _ready;
  assign _mosi = crc_complete ? (cmd_or_data_reg ? crc16[15] : crc7[6]) : cmd_reg[4103];
  assign mosi  = _mosi;
`ifdef DEBUG
  assign sender_state = state;
  always @(posedge clock, posedge reset) begin
    if (reset) begin
      crc16_dbg <= 16'b0;
    end else begin
      if (cmd_or_data_reg && crc_complete && (bits_sent == 13'd16)) begin
        crc16_dbg <= crc16;
      end else begin
        crc16_dbg <= crc16_dbg;
      end
    end
  end
`endif

endmodule
