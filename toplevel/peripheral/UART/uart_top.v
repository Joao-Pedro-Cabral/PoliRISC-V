//
//! @file   uart_top.v
//! @brief  Top para testar a UART
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

`include "macros.vh"

module uart_top (
    // Comum
    input wire clock,
    input wire reset,
    // PC
    input wire rxd,
    output wire txd,
    // Depuração
    input wire [3:0] sw,
`ifdef NEXYS4
    output reg [15:0] leds
`else
    output reg [9:0] leds
`endif
);

  // Sinais para controlar o DUT
  reg         rd_en;
  reg         wr_en;
  reg         CYC_O;
  reg         STB_O;
  reg         WR_O;
  reg  [ 2:0] addr;
  reg  [31:0] wr_data;
  wire [31:0] rd_data;
  wire        busy;
  // Depuração
  wire [15:0] div_;
  wire        p_rxwm_;
  wire        p_txwm_;
  wire        e_rxwm_;
  wire        e_txwm_;
  wire [ 2:0] rxcnt_;
  wire        rxen_;
  wire [ 2:0] txcnt_;
  wire        txen_;
  wire        nstop_;
  wire        rx_fifo_empty_;
  wire [ 7:0] rxdata_;
  wire        tx_fifo_full_;
  wire [ 7:0] txdata_;
  wire [ 1:0] present_state_;
  wire [ 2:0] addr_;
  wire [31:0] wr_data_;
  wire        rx_data_valid_;
  wire        tx_data_valid_;
  wire        tx_rdy_;
  wire [ 2:0] rx_watermark_reg_;
  wire [ 2:0] tx_watermark_reg_;

  localparam reg Nstop = 1'b0;  // Numero de stop bits

  // FSM
  reg [3:0] present_state, next_state;
  localparam reg [3:0]  Idle = 4'h0,
                        ConfReceiveControl = 4'h1,
                        ConfTransmitControl = 4'h2,
                        ConfInterruptEn = 4'h3,
                        WaitReceivePending = 4'h4,
                        ReadingData = 4'h5,
                        InitWritingData = 4'h6,
                        WritingData = 4'h7;

  uart #(
      .CLOCK_FREQ_HZ(100000000)  // 100 MHz
  ) DUT (
      .CLK_I            (clock),
      .RST_I            (reset),
      .CYC_I            (CYC_O),
      .STB_I            (STB_O),
      .WR_I             (WR_O),
      .ADR_I            (addr),
      .rxd              (rxd),
      .DAT_I            (wr_data),
      .txd              (txd),
      .DAT_O            (rd_data),
      .ACK_O            (ack),
      .div_             (div_),
      .p_rxwm_          (p_rxwm_),
      .p_txwm_          (p_txwm_),
      .e_txwm_          (e_txwm_),
      .e_rxwm_          (e_rxwm_),
      .rxcnt_           (rxcnt_),
      .rxen_            (rxen_),
      .txcnt_           (txcnt_),
      .nstop_           (nstop_),
      .txen_            (txen_),
      ._rx_fifo_empty_  (rx_fifo_empty_),
      .rxdata_          (rxdata_),
      .tx_fifo_full_    (tx_fifo_full_),
      .txdata_          (txdata_),
      .present_state_   (present_state_),
      .addr_            (addr_),
      .wr_data_         (wr_data_),
      .rx_data_valid_   (rx_data_valid_),
      .tx_data_valid_   (tx_data_valid_),
      .tx_rdy_          (tx_rdy_),
      .rx_watermark_reg_(rx_watermark_reg_),
      .tx_watermark_reg_(tx_watermark_reg_)
  );

  always @(*) begin
    CYC_O = 1'b0;
    STB_O = 1'b0;
    WR_O  = 1'b0;
    if (wr_en) begin
      CYC_O = 1'b1;
      STB_O = 1'b1;
      WR_O  = 1'b1;
    end else if (rd_en) begin
      CYC_O = 1'b1;
      STB_O = 1'b1;
    end
  end

  // Transição de Estado
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Saída da FSM
  always @(*) begin
    rd_en = 1'b0;
    wr_en = 1'b0;
    addr = 3'b0;
    wr_data = 0;
    case (present_state)
      Idle: begin
        next_state = ConfReceiveControl;
      end
      // Estados de Configuração da UART
      ConfReceiveControl: begin
        wr_en = 1'b1;
        addr = 3'b011;
        wr_data[0] = 1'b1;
        wr_data[18:16] = 3'b101;
        if (ack) next_state = ConfTransmitControl;
        else next_state = ConfReceiveControl;
      end
      ConfTransmitControl: begin
        wr_en = 1'b1;
        addr = 3'b010;
        wr_data[1:0] = {Nstop, 1'b1};
        wr_data[18:16] = 3'b010;
        if (ack) next_state = ConfInterruptEn;
        else next_state = ConfTransmitControl;
      end
      ConfInterruptEn: begin
        wr_en = 1'b1;
        addr = 3'b100;
        wr_data[1:0] = 2'b11;
        if (ack) next_state = WaitReceivePending;
        else next_state = ConfInterruptEn;
      end
      // Estados de Operação da UART
      // Espera p_rxwm_ = 1'b1 -> passar rd_data para wr_data
      WaitReceivePending: begin
        addr = 3'b001;
        if (p_rxwm_) begin
          rd_en = 1'b1;
          next_state = ReadingData;
        end else next_state = WaitReceivePending;
      end
      // Realizando a leitura
      ReadingData: begin
        rd_en = 1'b1;
        addr  = 3'b001;
        if (ack) next_state = InitWritingData;
        else next_state = ReadingData;
      end
      // Mandar via TX o dado recebido no RX
      InitWritingData: begin
        wr_en = 1'b1;
        addr = 3'b000;
        wr_data = rd_data;
        next_state = WritingData;
      end
      // Continuar a Escrita
      WritingData: begin
        wr_en = 1'b1;
        addr = 3'b000;
        wr_data = rd_data;
        // Após a Escrita -> Checar rxwm denovo
        if (ack) next_state = WaitReceivePending;
        else next_state = WritingData;
      end
      default: begin
        next_state = Idle;
      end
    endcase
  end

  // Leds de Depuração
`ifdef NEXYS4
  always @(*) begin
    case (sw)
      0: leds = div_;
      1:
      leds = {
        1'b0,
        p_rxwm_,
        p_txwm_,
        e_rxwm_,
        e_txwm_,
        rxcnt_,
        rxen_,
        txcnt_,
        txen_,
        nstop_,
        rx_fifo_empty_,
        tx_fifo_full_
      };
      2: leds = {rxdata_, txdata_};
      3:
      leds = {
        2'b0,
        present_state_,
        addr_,
        rx_data_valid_,
        tx_data_valid_,
        tx_rdy_,
        rx_watermark_reg_,
        tx_watermark_reg_
      };
      4: leds = wr_data_[15:0];
      5: leds = wr_data_[31:16];
      6: leds = {7'b0, rd_en, wr_en, addr, present_state};
      default: leds = wr_data_[15:0];
    endcase
  end
`else
  always @(*) begin
    case (sw)
      0: leds = {2'b00, div_[7:0]};
      1: leds = {2'b00, div_[15:8]};
      2: leds = {p_rxwm_, p_txwm_, e_rxwm_, e_txwm_, rxcnt_, rxen_};
      3: leds = {1'b0, txcnt_, txen_, nstop_, rx_fifo_empty_, tx_fifo_full_};
      4: leds = {2'b00, rxdata_};
      5: leds = {2'b00, txdata_};
      6: leds = {present_state_, addr_, rx_data_valid_, tx_data_valid_, tx_rdy_};
      7: leds = {2'b00, rx_watermark_reg_, tx_watermark_reg_};
      8: leds = {2'b00, wr_data_[7:0]};
      9: leds = {2'b00, wr_data_[15:8]};
      10: leds = {2'b00, wr_data_[23:16]};
      11: leds = {2'b00, wr_data_[31:24]};
      12: leds = {3'b000, rd_en, wr_en, addr};
      13: leds = {4'b0000, present_state};
      default: leds = {2'b00, div_[7:0]};
    endcase
  end
`endif

endmodule
