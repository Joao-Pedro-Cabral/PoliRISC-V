//
//! @file   uart.v
//! @brief  UART, seguindo o padrão do SiFive FE310-G002
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

module uart #(
    parameter integer CLOCK_FREQ_HZ = 10000000
) (
    input  wire        clock,
    input  wire        reset,
    input  wire        rd_en,
    input  wire        wr_en,
    input  wire [ 4:0] addr,     // 0x00 a 0x18
    input  wire        rxd,      // dado serial
    input  wire [31:0] wr_data,
    output wire        txd,      // dado de transmissão
    output wire [31:0] rd_data,
    output reg         busy
);

  localparam integer DIV_INIT = CLOCK_FREQ_HZ / (115200) - 1;

  // Internal read & write enable
  reg _rd_en;
  reg _wr_en;

  // Read-only register signals
  // Receive Data Register
  wire [7:0] rxdata;
  wire rx_data_en;
  // Interrupt Pending Register
  wire p_txwm;
  wire p_rxwm;

  // Read-write register signals
  // Transmit Data Register
  wire [7:0] txdata;
  // Transmit Control Register
  wire txen;
  wire nstop;
  wire [2:0] txcnt;
  // Receive Control Register
  wire rxen;
  wire [2:0] rxcnt;
  // Interrupt Enable Register
  wire e_txwm;
  wire e_rxwm;
  // Baud Rate Divisor Register
  wire [15:0] div;

  // Tx Fifo
  wire tx_fifo_rd_en;
  wire tx_fifo_wr_en;
  wire [7:0] tx_fifo_rd_data;
  wire tx_fifo_empty;
  wire tx_fifo_full;
  wire tx_fifo_less_than_watermark;
  wire tx_fifo_ed_rst;

  // Rx Fifo
  wire rx_fifo_rd_en;
  wire rx_fifo_wr_en;
  wire [7:0] rx_fifo_rd_data;
  wire [7:0] rx_fifo_wr_data;
  wire rx_fifo_empty;
  wire rx_fifo_full;
  wire rx_fifo_greater_than_watermark;
  wire rx_fifo_ed_rst;

  // UART Tx
  wire tx_clock;
  wire tx_data_valid;
  wire tx_rdy;
  wire [15:0] tx_counter;
  wire [15:0] tx_data_valid_count;

  // UART Rx
  wire rx_clock;
  wire rx_data_valid;
  wire [11:0] rx_counter;

  register_d #(
      .N(1),
      .reset_value(0)
  ) tx_fifo_wr_en_reg (
      .clock(clock),
      .reset(reset),
      .enable(1'b1),
      .D(_wr_en & (addr[4:2] == 3'b0)),
      .Q(tx_fifo_wr_en)
  );

  register_d #(
      .N(1),
      .reset_value(0)
  ) rx_fifo_rd_en_reg (
      .clock(clock),
      .reset(reset),
      .enable(1'b1),
      .D(_rd_en),
      .Q(rx_data_en)
  );


  // Transmit Data Register
  register_d #(
      .N(8),
      .reset_value(0)
  ) transmit_data_register (
      .clock(clock),
      .reset(reset),
      .enable(_wr_en & (addr[4:2] == 3'b0)),
      .D(wr_data[7:0]),
      .Q(txdata)
  );
  // Receive Data Register
  register_d #(
      .N(8),
      .reset_value(0)
  ) receive_data_register (
      .clock(clock),
      .reset(reset),
      .enable(rx_data_en),
      .D(rx_fifo_rd_data),
      .Q(rxdata)
  );
  // Transmit Control Register
  register_d #(
      .N(5),
      .reset_value(0)
  ) transmit_control_register (
      .clock(clock),
      .reset(reset),
      .enable(_wr_en & (addr[4:2] == 3'b010)),
      .D({wr_data[18:16], wr_data[1:0]}),
      .Q({txcnt, nstop, txen})
  );
  // Receive Control Register
  register_d #(
      .N(4),
      .reset_value(0)
  ) receive_control_register (
      .clock(clock),
      .reset(reset),
      .enable(_wr_en & (addr[4:2] == 3'b011)),
      .D({wr_data[18:16], wr_data[0]}),
      .Q({rxcnt, rxen})
  );

  // Interrupt Enable Register
  register_d #(
      .N(2),
      .reset_value(0)
  ) interrupt_enable_register (
      .clock(clock),
      .reset(reset),
      .enable(_wr_en & (addr[4:2] == 3'b100)),
      .D(wr_data[1:0]),
      .Q({e_rxwm, e_txwm})
  );
  // Interrupt Pending Register
  register_d #(
      .N(2),
      .reset_value(0)
  ) interrupt_pending_register (
      .clock(clock),
      .reset(reset),
      .enable(1'b1),
      .D({rx_fifo_greater_than_watermark & e_rxwm, tx_fifo_less_than_watermark & e_txwm}),
      .Q({p_rxwm, p_txwm})
  );
  // Baud Rate Divisor Register
  register_d #(
      .N(16),
      .reset_value(DIV_INIT)
  ) baud_rate_divisor_register (
      .clock(clock),
      .reset(reset),
      .enable(_wr_en & (addr[4:2] == 3'b110)),
      .D(wr_data[15:0]),
      .Q(div)
  );

  gen_mux #(
      .size(32),
      .N(3)
  ) read_mux (
      .A({
        32'b0,
        {16'b0, div},
        {30'b0, p_rxwm, p_txwm},
        {30'b0, e_rxwm, e_txwm},
        {13'b0, rxcnt, 15'b0, rxen},
        {13'b0, txcnt, 14'b0, nstop, txen},
        {rx_fifo_empty, 23'b0, rxdata},
        {tx_fifo_full, 23'b0, txdata}
      }),
      .S(addr[4:2]),
      .Y(rd_data)
  );

  edge_detector tx_fifo_rd_en_ed (
      .clock(clock),
      .reset(reset | tx_fifo_ed_rst),
      .sinal(tx_rdy & ~tx_fifo_empty),
      .pulso(tx_fifo_rd_en)
  );

  register_d #(
      .N(1),
      .reset_value(0)
  ) tx_fifo_rd_en_ed_reg (
      .clock(clock),
      .reset(reset | ~tx_rdy),
      .enable(tx_fifo_rd_en),
      .D(tx_rdy),
      .Q(tx_fifo_ed_rst)
  );

  FIFO #(
      .DATA_SIZE(8),
      .DEPTH(8)
  ) tx_fifo (
      .clock(clock),
      .reset(reset),
      .wr_en(tx_fifo_wr_en),
      .rd_en(tx_fifo_rd_en),
      .watermark_level(txcnt),
      .wr_data(txdata),
      .rd_data(tx_fifo_rd_data),
      .less_than_watermark(tx_fifo_less_than_watermark),
      .empty(tx_fifo_empty),
      .full(tx_fifo_full),
      .greater_than_watermark()
  );

  edge_detector rx_fifo_wr_en_ed (
      .clock(clock),
      .reset(reset | rx_fifo_ed_rst),
      .sinal(rx_data_valid & ~rx_fifo_full),
      .pulso(rx_fifo_wr_en)
  );

  register_d #(
      .N(1),
      .reset_value(0)
  ) rx_fifo_rd_en_ed_reg (
      .clock(clock),
      .reset(reset | ~rx_data_valid),
      .enable(rx_fifo_rd_en),
      .D(rx_data_valid),
      .Q(rx_fifo_ed_rst)
  );

  FIFO #(
      .DATA_SIZE(8),
      .DEPTH(8)
  ) rx_fifo (
      .clock(clock),
      .reset(reset),
      .wr_en(rx_fifo_wr_en),
      .rd_en(_rd_en),
      .watermark_level(rxcnt),
      .wr_data(rx_fifo_wr_data),
      .rd_data(rx_fifo_rd_data),
      .greater_than_watermark(rx_fifo_greater_than_watermark),
      .empty(rx_fifo_empty),
      .full(rx_fifo_full),
      .less_than_watermark()
  );

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

  sync_parallel_counter #(
      .size(16),
      .init_value(0)
  ) tx_baud_rate_generator (
      .clock(clock),
      .load(tx_counter == div),
      .load_value(16'b0),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(tx_counter)
  );

  assign tx_clock = div == 0 ? clock : tx_counter == div;

  sync_parallel_counter #(
      .size(12),
      .init_value(0)
  ) rx_baud_rate_generator (
      .clock(clock),
      .load(rx_counter == div[15:4]),
      .load_value(12'b0),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(rx_counter)
  );

  assign rx_clock = div[15:4] == 0 ? clock : (rx_counter == div[15:4]);

  sync_parallel_counter #(
      .size(16),
      .init_value(0)
  ) tx_data_valid_counter (
      .clock(clock),
      .load(~tx_rdy | (tx_rdy & ~tx_fifo_empty)),
      .load_value({15'b0, tx_rdy}),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(tx_data_valid_count)
  );

  assign tx_data_valid = |tx_data_valid_count;

  // Lógica do busy
  reg [1:0] present_state, next_state;  // Estado da transmissão

  // Estados possíveis
  localparam reg [1:0] Idle = 2'b0, Read = 2'b01, Write = 2'b10, Nop = 2'b11;

  // Transição de Estado
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end


  always @(*) begin
    busy   = 0;
    _rd_en = 0;
    _wr_en = 0;
    case (present_state)
      default: begin
        if (rd_en) next_state = Read;
        else if (wr_en) next_state = Write;
        else next_state = Idle;
      end
      Read: begin
        busy = 1'b1;
        _rd_en = 1'b1;
        next_state = Nop;
      end
      Write: begin
        busy = 1'b1;
        _wr_en = 1'b1;
        next_state = Nop;
      end
      Nop: begin
        busy = 1'b1;
        next_state = Idle;
      end
    endcase
  end
endmodule
