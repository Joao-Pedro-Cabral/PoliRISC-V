
`include "macros.vh"
`include "boards.vh"

module uart_bank #(
    parameter integer LITEX_ARCH = 0,
    parameter integer FIFO_DEPTH = 8,
    parameter integer CLOCK_FREQ_HZ = 10000000
) (
    // COMMON
    input  wire                          clock,
    input  wire                          reset,
    input  wire [                   2:0] addr,
    input  wire [                  31:0] wr_data,
    output wire [                  31:0] rd_data,
    output wire                          interrupt,
    // FSM
    input  wire                          bank_rd_en,
    input  wire                          bank_wr_en,
    input  wire                          rxdata_wr_en,
    // DEBUG
`ifdef DEBUG
    output wire                          tx_pending_,
    output wire                          rx_pending_,
    output wire                          tx_pending_en_,
    output wire                          rx_pending_en_,
    output wire                          tx_status_,
    output wire                          rx_status_,
    output wire                          rx_fifo_empty_,
    output wire [                   7:0] txdata_,
    output wire [                   7:0] rxdata_,
`endif
    // PHY
    output wire                          txen,
    output wire                          rxen,
    output wire                          nstop,
    output wire [                  15:0] div,
    output wire [$clog2(FIFO_DEPTH)-1:0] txcnt,
    output wire [$clog2(FIFO_DEPTH)-1:0] rxcnt,
    output wire [                   7:0] tx_fifo_wr_data,
    input  wire [                   7:0] rx_fifo_rd_data,
    input  wire                          tx_fifo_full,
    input  wire                          rx_fifo_full,
    input  wire                          tx_fifo_empty,
    input  wire                          rx_fifo_empty,
    input  wire                          tx_fifo_less_than_watermark,
    input  wire                          rx_fifo_greater_than_watermark
);

  localparam integer DivInit = CLOCK_FREQ_HZ / (115200) - 1;

  // Transmit Data Register
  wire [7:0] _txdata;
  // Receive Data Register
  wire [7:0] _rxdata;
  // Transmit Control Register
  wire _txen;
  wire _nstop;
  wire [2:0] _txcnt;
  // Receive Control Register
  wire _rxen;
  wire [2:0] _rxcnt;
  // Receive Empty Register
  wire _rx_fifo_empty;
  // Interrupt Status Register
  wire tx_status;
  wire rx_status;
  // Interrupt Pending Register
  wire tx_pending;
  wire rx_pending;
  // Interrupt Enable Register
  wire tx_pending_en;
  wire rx_pending_en;
  // Baud Rate Divisor Register
  wire [15:0] _div;

  // ADDR-TYPE
  localparam reg [3:0] TxData = 4'h0,
                       RxData = 4'h1,
                       TxFull = 4'h2,
                       TxEmpty = 4'h3,
                       RxFull = 4'h4,
                       RxEmpty = 4'h5,
                       InterruptEn = 4'h6,
                       Pending = 4'h7,
                       Status = 4'h8,
                       TxControl = 4'h9,
                       RxControl = 4'hA,
                       ClockDiv = 4'hB;

  function automatic addr_en(input integer litex_arch, input reg [2:0] addr,
                             input reg [3:0] addr_type);
    begin
      case (addr_type)
        TxData: addr_en = (addr == 3'b000);
        RxData: addr_en = litex_arch ? (addr == 3'b000) : (addr == 3'b001);
        TxFull: addr_en = litex_arch ? (addr == 3'b001) : (addr == 3'b000);
        TxEmpty: addr_en = litex_arch ? (addr == 3'b110) : 1'b0;
        RxFull: addr_en = litex_arch ? (addr == 3'b111) : 1'b0;
        RxEmpty: addr_en = litex_arch ? (addr == 3'b010) : (addr == 3'b001);
        InterruptEn: addr_en = litex_arch ? (addr == 3'b101) : (addr == 3'b100);
        Pending: addr_en = litex_arch ? (addr == 3'b100) : (addr == 3'b101);
        Status: addr_en = litex_arch ? (addr == 3'b011) : 1'b0;
        TxControl: addr_en = litex_arch ? 1'b0 : (addr == 3'b010);
        RxControl: addr_en = litex_arch ? 1'b0 : (addr == 3'b011);
        ClockDiv: addr_en = litex_arch ? 1'b0 : (addr == 3'b110);
        default: addr_en = 1'b0;  // Reserved
      endcase
    end
  endfunction

  // Registradores Mapeados em Memória
  // Transmit Data Register
  register_d #(
      .N(8),
      .reset_value(0)
  ) transmit_data_register (
      .clock(clock),
      .reset(reset),
      .enable(bank_wr_en & addr_en(LITEX_ARCH, addr, TxData)),
      .D(wr_data[7:0]),
      .Q(_txdata)
  );
  // Receive Data Register
  register_d #(
      .N(8),
      .reset_value(0)
  ) receive_data_register (
      .clock(clock),
      .reset(reset),
      .enable(rxdata_wr_en),
      .D(rx_fifo_rd_data),
      .Q(_rxdata)
  );
  // Interrupt Enable Register
  register_d #(
      .N(2),
      .reset_value(0)
  ) interrupt_enable_register (
      .clock(clock),
      .reset(reset),
      .enable(bank_wr_en & addr_en(LITEX_ARCH, addr, InterruptEn)),
      .D(wr_data[1:0]),
      .Q({rx_pending_en, tx_pending_en})
  );
  // Obter empty antes da leitura ser feita
  generate
    if (LITEX_ARCH) begin : gen_litex_regs
      reg tx_fifo_full_d, rx_fifo_empty_d;
      reg [1:0] uart_pending;
      always @(posedge clock) begin
        tx_fifo_full_d  <= tx_fifo_full;
        rx_fifo_empty_d <= rx_fifo_empty;
      end
      always @(posedge clock, posedge reset) begin
        if (reset) uart_pending <= 2'b00;
        else if (bank_wr_en & addr_en(LITEX_ARCH, addr, Pending)) uart_pending <= wr_data[1:0];
        else begin
          if (tx_fifo_full_d && !tx_fifo_full) uart_pending[0] <= 1'b1;
          if (rx_fifo_empty_d && !rx_fifo_empty) uart_pending[1] <= 1'b1;
        end
      end
      assign {rx_pending, tx_pending} = uart_pending;
      assign tx_status = ~tx_fifo_full;
      assign rx_status = ~rx_fifo_empty;
      assign _rx_fifo_empty = rx_fifo_empty;
      assign {_txcnt, _nstop, _txen} = 5'h01;
      assign {_rxcnt, _rxen} = 4'h1;
      assign _div = DivInit;
    end else begin : gen_sifive_regs
      register_d #(
          .N(1),
          .reset_value(0)
      ) receive_empty_register (
          .clock(clock),
          .reset(reset),
          .enable(bank_rd_en & addr_en(LITEX_ARCH, addr, RxEmpty)),
          .D(rx_fifo_empty),
          .Q(_rx_fifo_empty)
      );
      // Transmit Control Register
      register_d #(
          .N(5),
          .reset_value(0)
      ) transmit_control_register (
          .clock(clock),
          .reset(reset),
          .enable(bank_wr_en & addr_en(LITEX_ARCH, addr, TxControl)),
          .D({wr_data[18:16], wr_data[1:0]}),
          .Q({_txcnt, _nstop, _txen})
      );
      // Receive Control Register
      register_d #(
          .N(4),
          .reset_value(0)
      ) receive_control_register (
          .clock(clock),
          .reset(reset),
          .enable(bank_wr_en & addr_en(LITEX_ARCH, addr, RxControl)),
          .D({wr_data[18:16], wr_data[0]}),
          .Q({_rxcnt, _rxen})
      );
      // Interrupt Pending Register
      assign rx_pending = rx_fifo_greater_than_watermark;
      assign tx_pending = tx_fifo_less_than_watermark;
      // Baud Rate Divisor Register
      register_d #(
          .N(16),
          .reset_value(DivInit)
      ) baud_rate_divisor_register (
          .clock(clock),
          .reset(reset),
          .enable(bank_wr_en & addr_en(LITEX_ARCH, addr, ClockDiv)),
          .D(wr_data[15:0]),
          .Q(_div)
      );
      assign {rx_status, tx_status} = 2'b00;
    end
  endgenerate

  // Saídas
  generate
    if (LITEX_ARCH) begin : gen_litex_rd_data
      gen_mux #(
          .size(32),
          .N(3)
      ) read_mux (
          .A({
            {31'b0, rx_fifo_full},
            {31'b0, tx_fifo_empty},
            {30'b0, rx_pending_en, tx_pending_en},
            {30'b0, rx_pending, tx_pending},
            {30'b0, rx_status, tx_status},
            {31'b0, rx_fifo_empty},
            {31'b0, tx_fifo_full},
            {24'b0, _rxdata}
          }),
          .S(addr),
          .Y(rd_data)
      );
    end else begin : gen_sifive_rd_data
      gen_mux #(
          .size(32),
          .N(3)
      ) read_mux (
          .A({
            32'b0,
            {16'b0, _div},
            {30'b0, rx_pending, tx_pending},
            {30'b0, rx_pending_en, tx_pending_en},
            {13'b0, _rxcnt, 15'b0, _rxen},
            {13'b0, _txcnt, 14'b0, _nstop, _txen},
            {_rx_fifo_empty, 23'b0, _rxdata},
            {tx_fifo_full, 23'b0, _txdata}
          }),
          .S(addr),
          .Y(rd_data)
      );
    end
  endgenerate

  assign tx_fifo_wr_data = _txdata;
  assign txcnt = _txcnt;
  assign nstop = _nstop;
  assign txen = _txen;
  assign rxen = _rxen;
  assign rxcnt = _rxcnt;
  assign div = _div;
  assign interrupt = (tx_pending & tx_pending_en) | (rx_pending & rx_pending_en);

`ifdef DEBUG
  assign rx_pending_ = rx_pending;
  assign tx_pending_ = tx_pending;
  assign tx_pending_en_ = tx_pending_en;
  assign rx_pending_en_ = rx_pending_en;
  assign tx_status_ = tx_status;
  assign rx_status_ = rx_status;
  assign rx_fifo_empty_ = _rx_fifo_empty;
  assign rxdata_ = _rxdata;
  assign txdata_ = _txdata;
`endif

endmodule
