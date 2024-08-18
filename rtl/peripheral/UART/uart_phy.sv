module uart_phy #(
    parameter integer FIFO_DEPTH = 8
) (
    // COMMON
    input  wire                          clock,
    input  wire                          reset,
    // BANK
    input  wire                          txen,
    input  wire                          rxen,
    input  wire                          nstop,
    input  wire [                  15:0] div,
    input  wire [$clog2(FIFO_DEPTH)-1:0] txcnt,
    input  wire [$clog2(FIFO_DEPTH)-1:0] rxcnt,
    input  wire [                   7:0] tx_fifo_wr_data,
    output wire [                   7:0] rx_fifo_rd_data,
    output wire                          tx_fifo_full,
    output wire                          rx_fifo_full,
    output wire                          tx_fifo_empty,
    output wire                          rx_fifo_empty,
    output wire                          tx_fifo_less_than_watermark,
    output wire                          rx_fifo_greater_than_watermark,
    // FSM
    input  wire                          tx_fifo_wr_en,
    input  wire                          rx_fifo_rd_en,
    // SERIAL
    output wire                          txd,
    input  wire                          rxd,
    // DEBUG
    output wire                          rx_data_valid_db,
    output wire                          tx_data_valid_db,
    output wire                          tx_rdy_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] tx_watermark_reg_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] rx_watermark_reg_db
);

  // Tx Fifo
  reg tx_fifo_rd_en;
  wire [7:0] tx_fifo_rd_data;
  wire tx_fifo_empty_;

  // Rx Fifo
  reg rx_fifo_wr_en;
  wire [7:0] rx_fifo_wr_data;
  wire rx_fifo_full_;

  // UART Tx
  reg tx_clock;
  reg tx_data_valid;
  wire tx_rdy;

  // UART Rx
  reg rx_clock;
  wire rx_data_valid;

  // FIFOs
  // TX fifo
  fifo #(
      .DATA_SIZE(8),
      .DEPTH(FIFO_DEPTH)
  ) tx_fifo (
      .clock(clock),
      .reset(reset),
      .wr_en(tx_fifo_wr_en),
      .rd_en(tx_fifo_rd_en),
      .watermark_level(txcnt),
      .wr_data(tx_fifo_wr_data),
      .rd_data(tx_fifo_rd_data),
      .less_than_watermark(tx_fifo_less_than_watermark),
      .watermark_reg_db(tx_watermark_reg_db),
      .empty(tx_fifo_empty_),
      .full(tx_fifo_full),
      .greater_than_watermark()
  );

  assign tx_fifo_empty = tx_fifo_empty_;

  reg tx_rdy_aux, tx_fifo_empty_aux;

  // Leitura da fifo -> UART TX pronta (borda de subida)
  // Mantenho o rd_en ativo até que a fifo tenha algum dado para transmitir
  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      tx_fifo_rd_en <= 1'b0;
      tx_fifo_empty_aux <= 1'b0;
    end else if (tx_fifo_rd_en) begin
      // Desabilito o rd_en caso houve leitura agora ou no ciclo da subida do tx_rdy
      if (!tx_fifo_empty_aux || !tx_fifo_empty_) tx_fifo_rd_en <= 1'b0;
      else tx_fifo_rd_en <= 1'b1;
      tx_fifo_empty_aux <= tx_fifo_empty_aux;
    end else if (tx_rdy && !tx_rdy_aux) begin
      tx_fifo_rd_en <= 1'b1;
      // Armazeno tx_fifo_empty_ para averiguar se nesse ciclo houve leitura
      tx_fifo_empty_aux <= tx_fifo_empty_;
    end
  end

  // Para evitar múltiplas leituras por ciclo de clock da UART
  // Detecto a borda de subida do tx_rdy
  // Apenas esse tem reset, pois no estado padrão do transmissor tx_rdy = 1'b1
  // Enquanto no estado padrão do receptor o rx_data_valid = 1'b0
  always_ff @(posedge clock, posedge reset) begin
    if (reset) tx_rdy_aux <= 1'b0;
    else tx_rdy_aux <= tx_rdy;
  end

  // RX fifo
  fifo #(
      .DATA_SIZE(8),
      .DEPTH(FIFO_DEPTH)
  ) rx_fifo (
      .clock(clock),
      .reset(reset),
      .wr_en(rx_fifo_wr_en),
      .rd_en(rx_fifo_rd_en),
      .watermark_level(rxcnt),
      .wr_data(rx_fifo_wr_data),
      .rd_data(rx_fifo_rd_data),
      .greater_than_watermark(rx_fifo_greater_than_watermark),
      .watermark_reg_db(rx_watermark_reg_db),
      .empty(rx_fifo_empty),
      .full(rx_fifo_full_),
      .less_than_watermark()
  );

  assign rx_fifo_full = rx_fifo_full_;

  reg rx_data_valid_aux, rx_fifo_full_aux;

  // Escrita na fifo -> UART RX válido (borda de subida)
  // Mantenho o wr_en ativo até que a fifo tenha espaço sobrando
  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      rx_fifo_wr_en <= 1'b0;
      rx_fifo_full_aux <= 1'b0;
    end else if (rx_fifo_wr_en) begin
      // Desabilito o wr_en caso houve escrita agora ou no ciclo da subida do rx_data_valid
      if (!rx_fifo_full_aux || !rx_fifo_full_) rx_fifo_wr_en <= 1'b0;
      else rx_fifo_wr_en <= 1'b1;
      rx_fifo_full_aux <= rx_fifo_full_aux;
    end else if (rx_data_valid && !rx_data_valid_aux) begin
      rx_fifo_wr_en <= 1'b1;
      // Armazeno rx_fifo_full_ para averiguar se nesse ciclo houve leitura
      rx_fifo_full_aux <= rx_fifo_full_;
    end
  end

  // Para evitar múltiplas escritas por ciclo de clock da UART
  // Detecto a borda de subida do rx_data_valid
  always_ff @(posedge clock) begin
    rx_data_valid_aux <= rx_data_valid;
  end

  // Conversores Serial <-> Paralelo
  // TX
  uart_tx tx (
      .clock(tx_clock),
      .reset(reset),
      .tx_en(txen),
      .parity_type(2'b00),
      .nstop(nstop),
      .txd(txd),
      .data_in(tx_fifo_rd_data),
      .data_valid(tx_data_valid),
      .tx_rdy(tx_rdy)
  );

  // Caso o TX não esteja pronto -> Valid 0
  // Caso TX pronto e houve uma leitura na fifo -> Valid 1
  reg tx_fifo_rd_en_aux;
  always_ff @(posedge clock, posedge reset) begin
    if (reset || !tx_rdy) tx_data_valid <= 1'b0;
    else if (!tx_fifo_rd_en && tx_fifo_rd_en_aux) tx_data_valid <= 1'b1;
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) tx_fifo_rd_en_aux <= 1'b0;
    else tx_fifo_rd_en_aux <= tx_fifo_rd_en;
  end

  // RX
  uart_rx rx (
      .clock(rx_clock),
      .reset(reset),
      .rx_en(rxen),
      .parity_type(2'b00),
      .nstop(nstop),
      .rxd(rxd),
      .data_out(rx_fifo_wr_data),
      .data_valid(rx_data_valid),
      .parity_error(),
      .frame_error()
  );

  // Divisores de clock
  // Caso div mude, reseto os clocks
  wire [15:0] tx_counter;
  wire div_change;
  reg [15:0] old_div;
  // Detector de mudança do div
  always_ff @(posedge clock) begin
    old_div <= div;
  end

  assign div_change = |(div ^ old_div);

  // TX clock
  sync_parallel_counter #(
      .size(16),
      .init_value(0)
  ) tx_baud_rate_generator (
      .clock(clock),
      .load((tx_counter == div) | div_change),
      .load_value(16'b0),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(tx_counter)
  );

  always_ff @(posedge clock, posedge reset) begin
    if (reset | div_change) tx_clock <= 1'b0;
    else if (tx_counter == div) tx_clock <= ~tx_clock;
    else tx_clock <= 1'b0;
  end

  // RX clock
  wire [11:0] rx_counter;
  sync_parallel_counter #(
      .size(12),
      .init_value(0)
  ) rx_baud_rate_generator (
      .clock(clock),
      .load((rx_counter == div[15:4]) | div_change),
      .load_value(12'b0),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(rx_counter)
  );

  always_ff @(posedge clock, posedge reset) begin
    if (reset | div_change) rx_clock <= 1'b0;
    else if (rx_counter == div[15:4]) rx_clock <= 1'b1;
    else rx_clock <= 1'b0;
  end

  // DEBUG
  assign rx_data_valid_db = rx_data_valid;
  assign tx_data_valid_db = tx_data_valid;
  assign tx_rdy_db = tx_rdy;

endmodule
