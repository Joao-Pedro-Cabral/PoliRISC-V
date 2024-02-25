
`include "macros.vh"
`include "extensions.vh"

module uart #(
    parameter integer LITEX_ARCH = 0,  // 0: SiFive, 1: Litex
    parameter integer FIFO_DEPTH = 8,
    parameter integer CLOCK_FREQ_HZ = 10000000
) (
    input  wire                          CLK_I,
    input  wire                          RST_I,
    input  wire                          CYC_I,
    input  wire                          STB_I,
    input  wire                          WE_I,
    input  wire [                   2:0] ADR_I,              // 0x00 a 0x18
    input  wire                          rxd,                // dado serial
    input  wire [                  31:0] DAT_I,
    output wire                          txd,                // dado de transmissão
    output wire [                  31:0] DAT_O,
    output wire                          interrupt,
`ifdef DEBUG
    output wire [                  15:0] div_,
    output wire                          rx_pending_,
    output wire                          tx_pending_,
    output wire                          rx_pending_en_,
    output wire                          tx_pending_en_,
    output wire [$clog2(FIFO_DEPTH)-1:0] txcnt_,
    output wire [$clog2(FIFO_DEPTH)-1:0] rxcnt_,
    output wire                          txen_,
    output wire                          rxen_,
    output wire                          nstop_,
    output wire                          rx_fifo_empty_,
    output wire [                   7:0] rxdata_,
    output wire                          tx_fifo_full_,
    output wire [                   7:0] txdata_,
    output wire [                   2:0] present_state_,
    output wire [                   2:0] addr_,
    output wire [                  31:0] wr_data_,
    output wire                          rx_data_valid_,
    output wire                          tx_data_valid_,
    output wire                          tx_rdy_,
    output wire [$clog2(FIFO_DEPTH)-1:0] rx_watermark_reg_,
    output wire [$clog2(FIFO_DEPTH)-1:0] tx_watermark_reg_,
    output wire                          tx_status_,
    output wire                          rx_status_,
`endif
    output wire                          ACK_O
);

  // Internal interface signals
  wire                          rd_en;
  wire                          wr_en;
  wire [                   2:0] _addr;
  wire [                  31:0] _wr_data;

  // Read-only register signals
  // Receive Data Register
  wire [                   7:0] rxdata;
  // Interrupt Pending Register
  wire                          p_txwm;
  wire                          p_rxwm;

  // Component's signals
  // BANK
  wire                          txen;
  wire                          rxen;
  wire                          nstop;
  wire [                  15:0] div;
  wire [$clog2(FIFO_DEPTH)-1:0] txcnt;
  wire [$clog2(FIFO_DEPTH)-1:0] rxcnt;
  wire [                   7:0] tx_fifo_wr_data;
  // FSM
  wire                          op;
  wire                          bank_rd_en;
  wire                          bank_wr_en;
  wire                          rxdata_wr_en;
  wire                          tx_fifo_wr_en;
  wire                          rx_fifo_rd_en;
  // PHY
  wire [                   7:0] rx_fifo_rd_data;
  wire                          tx_fifo_full;
  wire                          rx_fifo_full;
  wire                          tx_fifo_empty;
  wire                          rx_fifo_empty;
  wire                          tx_fifo_less_than_watermark;
  wire                          rx_fifo_greater_than_watermark;

  // WISHBONE
  // Determinando o comportamento da UART pelas entradas
  assign wr_en = CYC_I & STB_I & WE_I;
  assign rd_en = CYC_I & STB_I & ~WE_I;

  // Bufferizando entradas
  register_d #(
      .N(3),
      .reset_value(0)
  ) addr_reg (
      .clock(CLK_I),
      .reset(RST_I),
      .enable((rd_en | wr_en) && !op),
      .D(ADR_I),
      .Q(_addr)
  );

  register_d #(
      .N(32),
      .reset_value(0)
  ) wr_data_reg (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(wr_en && !op),
      .D(DAT_I),
      .Q(_wr_data)
  );

  // BANK
  uart_bank #(
      .LITEX_ARCH(LITEX_ARCH),
      .FIFO_DEPTH(FIFO_DEPTH),
      .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ)
  ) BANK (
      // COMMON
      .clock(CLK_I),
      .reset(RST_I),
      .addr(_addr),
      .wr_data(_wr_data),
      .rd_data(DAT_O),
      .interrupt(interrupt),
      // FSM
      .bank_rd_en(bank_rd_en),
      .bank_wr_en(bank_wr_en),
      .rxdata_wr_en(rxdata_wr_en),
      // DEBUG
`ifdef DEBUG
      .tx_pending_(tx_pending_),
      .rx_pending_(rx_pending_),
      .tx_pending_en_(tx_pending_en_),
      .rx_pending_en_(rx_pending_en_),
      .tx_status_(tx_status_),
      .rx_status_(rx_status_),
      .rx_fifo_empty_(rx_fifo_empty_),
      .txdata_(txdata_),
      .rxdata_(rxdata_),
`endif
      // PHY
      .txen(txen),
      .rxen(rxen),
      .nstop(nstop),
      .div(div),
      .txcnt(txcnt),
      .rxcnt(rxcnt),
      .tx_fifo_wr_data(tx_fifo_wr_data),
      .rx_fifo_rd_data(rx_fifo_rd_data),
      .tx_fifo_full(tx_fifo_full),
      .rx_fifo_full(rx_fifo_full),
      .tx_fifo_empty(tx_fifo_empty),
      .rx_fifo_empty(rx_fifo_empty),
      .tx_fifo_less_than_watermark(tx_fifo_less_than_watermark),
      .rx_fifo_greater_than_watermark(rx_fifo_greater_than_watermark)
  );

  // FSM
  uart_fsm #(
      .LITEX_ARCH(LITEX_ARCH)
  ) FSM (
      // COMMON
      .clock(CLK_I),
      .reset(RST_I),
      .rd_en(rd_en),
      .wr_en(wr_en),
      .addr(_addr),
      .op(op),
      .ack(ACK_O),
      // BANK
      .bank_rd_en(bank_rd_en),
      .bank_wr_en(bank_wr_en),
      .rxdata_wr_en(rxdata_wr_en),
      // DEBUG
`ifdef DEBUG
      .present_state_(present_state_),
`endif
      // PHY
      .tx_fifo_wr_en(tx_fifo_wr_en),
      .rx_fifo_rd_en(rx_fifo_rd_en)
  );

  // PHY
  uart_phy #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) PHY (
      // COMMON
      .clock(CLK_I),
      .reset(RST_I),
      // BANK
      .txen(txen),
      .rxen(rxen),
      .nstop(nstop),
      .div(div),
      .txcnt(txcnt),
      .rxcnt(rxcnt),
      .tx_fifo_wr_data(tx_fifo_wr_data),
      .rx_fifo_rd_data(rx_fifo_rd_data),
      .tx_fifo_full(tx_fifo_full),
      .rx_fifo_full(rx_fifo_full),
      .tx_fifo_empty(tx_fifo_empty),
      .rx_fifo_empty(rx_fifo_empty),
      .tx_fifo_less_than_watermark(tx_fifo_less_than_watermark),
      .rx_fifo_greater_than_watermark(rx_fifo_greater_than_watermark),
      // FSM
      .tx_fifo_wr_en(tx_fifo_wr_en),
      .rx_fifo_rd_en(rx_fifo_rd_en),
      // DEBUG
`ifdef DEBUG
      .rx_data_valid_(rx_data_valid_),
      .tx_data_valid_(tx_data_valid_),
      .tx_rdy_(tx_rdy_),
      .tx_watermark_reg_(tx_watermark_reg_),
      .rx_watermark_reg_(rx_watermark_reg_),
`endif
      // SERIAL
      .txd(txd),
      .rxd(rxd)
  );

`ifdef DEBUG
  assign addr_ = _addr;
  assign wr_data_ = _wr_data;
  // BANK
  assign div_ = div;
  assign txcnt_ = txcnt;
  assign rxcnt_ = rxcnt;
  assign txen_ = txen;
  assign rxen_ = rxen;
  assign nstop_ = nstop;
  // PHY
  assign tx_fifo_full_ = tx_fifo_full;
`endif

endmodule
