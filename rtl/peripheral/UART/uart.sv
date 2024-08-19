
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
    output wire                          ACK_O,
    output wire [                  15:0] div_db,
    output wire                          rx_pending_db,
    output wire                          tx_pending_db,
    output wire                          rx_pending_en_db,
    output wire                          tx_pending_en_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] txcnt_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] rxcnt_db,
    output wire                          txen_db,
    output wire                          rxen_db,
    output wire                          nstop_db,
    output wire                          rx_fifo_empty_db,
    output wire [                   7:0] rxdata_db,
    output wire                          tx_fifo_full_db,
    output wire [                   7:0] txdata_db,
    output wire [                   2:0] present_state_db,
    output wire [                   2:0] addr_db,
    output wire [                  31:0] wr_data_db,
    output wire                          rx_data_valid_db,
    output wire                          tx_data_valid_db,
    output wire                          tx_rdy_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] rx_watermark_reg_db,
    output wire [$clog2(FIFO_DEPTH)-1:0] tx_watermark_reg_db,
    output wire                          tx_status_db,
    output wire                          rx_status_db
);

  // Internal interface signals
  wire                          rd_en;
  wire                          wr_en;
  wire [                   2:0] _addr;
  wire [                  31:0] _wr_data;

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
  ) bank (
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
      .tx_pending_db(tx_pending_db),
      .rx_pending_db(rx_pending_db),
      .tx_pending_en_db(tx_pending_en_db),
      .rx_pending_en_db(rx_pending_en_db),
      .tx_status_db(tx_status_db),
      .rx_status_db(rx_status_db),
      .rx_fifo_empty_db(rx_fifo_empty_db),
      .txdata_db(txdata_db),
      .rxdata_db(rxdata_db),
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
      .present_state_db(present_state_db),
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
      .rx_data_valid_db(rx_data_valid_db),
      .tx_data_valid_db(tx_data_valid_db),
      .tx_rdy_db(tx_rdy_db),
      .tx_watermark_reg_db(tx_watermark_reg_db),
      .rx_watermark_reg_db(rx_watermark_reg_db),
      // SERIAL
      .txd(txd),
      .rxd(rxd)
  );

  assign addr_db = _addr;
  assign wr_data_db = _wr_data;
  // BANK
  assign div_db = div;
  assign txcnt_db = txcnt;
  assign rxcnt_db = rxcnt;
  assign txen_db = txen;
  assign rxen_db = rxen;
  assign nstop_db = nstop;
  // PHY
  assign tx_fifo_full_db = tx_fifo_full;

endmodule
