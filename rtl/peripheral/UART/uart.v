//
//! @file   uart.v
//! @brief  UART, seguindo o padrão do SiFive FE310-G002
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

`include "macros.vh"

module uart #(
    parameter integer CLOCK_FREQ_HZ = 10000000
) (
    input  wire        CLK_I,
    input  wire        RST_I,
    input  wire        CYC_I,
    input  wire        STB_I,
    input  wire        WE_I,
    input  wire [ 2:0] ADR_I,              // 0x00 a 0x18
    input  wire        rxd,                // dado serial
    input  wire [31:0] DAT_I,
    output wire        txd,                // dado de transmissão
    output wire [31:0] DAT_O,
`ifdef DEBUG
    output wire [15:0] div_,
    output wire        p_rxwm_,
    output wire        p_txwm_,
    output wire        e_txwm_,
    output wire        e_rxwm_,
    output wire [ 2:0] rxcnt_,
    output wire        rxen_,
    output wire [ 2:0] txcnt_,
    output wire        nstop_,
    output wire        txen_,
    output wire        _rx_fifo_empty_,
    output wire [ 7:0] rxdata_,
    output wire        tx_fifo_full_,
    output wire [ 7:0] txdata_,
    output wire [ 1:0] present_state_,
    output wire [ 2:0] addr_,
    output wire [31:0] wr_data_,
    output wire        rx_data_valid_,
    output wire        tx_data_valid_,
    output wire        tx_rdy_,
    output wire [ 2:0] rx_watermark_reg_,
    output wire [ 2:0] tx_watermark_reg_,
`endif
    output wire        ACK_O
);

  localparam integer DivInit = CLOCK_FREQ_HZ / (115200) - 1;

  // Internal interface signals
  wire rd_en;
  wire wr_en;
  reg _rd_en;
  reg _wr_en;
  wire [2:0] _addr;
  wire [31:0] _wr_data;
  // Extra FSM signals
  reg end_rd;
  reg end_wr;
  reg op;
  reg ack;

  // Read-only register signals
  // Receive Data Register
  wire [7:0] rxdata;
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
  reg tx_fifo_rd_en;
  wire [7:0] tx_fifo_rd_data;
  wire tx_fifo_empty;
  wire tx_fifo_full;
  wire tx_fifo_less_than_watermark;

  // Rx Fifo
  wire rx_fifo_rd_en;
  reg rx_fifo_wr_en;
  wire [7:0] rx_fifo_rd_data;
  wire [7:0] rx_fifo_wr_data;
  wire rx_fifo_empty;
  wire rx_fifo_empty_;
  wire rx_fifo_full;
  wire rx_fifo_greater_than_watermark;

  // UART Tx
  reg tx_clock;
  reg tx_data_valid;
  wire tx_rdy;

  // UART Rx
  reg rx_clock;
  wire rx_data_valid;

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

  // Registradores Mapeados em Memória
  // Transmit Data Register
  register_d #(
      .N(8),
      .reset_value(0)
  ) transmit_data_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_wr_en & (_addr == 3'b0)),
      .D(_wr_data[7:0]),
      .Q(txdata)
  );
  // Receive Data Register -> Melhorar!
  register_d #(
      .N(8),
      .reset_value(0)
  ) receive_data_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(end_rd),
      .D(rx_fifo_rd_data),
      .Q(rxdata)
  );
  // Obter empty antes da leitura ser feita
  register_d #(
      .N(1),
      .reset_value(0)
  ) receive_empty_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_rd_en & (_addr == 3'b001)),
      .D(rx_fifo_empty),
      .Q(rx_fifo_empty_)
  );
  // Transmit Control Register
  register_d #(
      .N(5),
      .reset_value(0)
  ) transmit_control_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_wr_en & (_addr == 3'b010)),
      .D({_wr_data[18:16], _wr_data[1:0]}),
      .Q({txcnt, nstop, txen})
  );
  // Receive Control Register
  register_d #(
      .N(4),
      .reset_value(0)
  ) receive_control_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_wr_en & (_addr == 3'b011)),
      .D({_wr_data[18:16], _wr_data[0]}),
      .Q({rxcnt, rxen})
  );

  // Interrupt Enable Register
  register_d #(
      .N(2),
      .reset_value(0)
  ) interrupt_enable_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_wr_en & (_addr == 3'b100)),
      .D(_wr_data[1:0]),
      .Q({e_rxwm, e_txwm})
  );
  // Interrupt Pending Register
  assign p_rxwm = rx_fifo_greater_than_watermark & e_rxwm;
  assign p_txwm = tx_fifo_less_than_watermark & e_txwm;
  // Baud Rate Divisor Register
  register_d #(
      .N(16),
      .reset_value(DivInit)
  ) baud_rate_divisor_register (
      .clock(CLK_I),
      .reset(RST_I),
      .enable(_wr_en & (_addr == 3'b110)),
      .D(_wr_data[15:0]),
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
        {rx_fifo_empty_, 23'b0, rxdata},
        {tx_fifo_full, 23'b0, txdata}
      }),
      .S(_addr),
      .Y(DAT_O)
  );

  // FIFOs
  // TX FIFO
  FIFO #(
      .DATA_SIZE(8),
      .DEPTH(8)
  ) tx_fifo (
      .clock(CLK_I),
      .reset(RST_I),
      .wr_en(end_wr),
      .rd_en(tx_fifo_rd_en),
      .watermark_level(txcnt),
      .wr_data(txdata),
      .rd_data(tx_fifo_rd_data),
      .less_than_watermark(tx_fifo_less_than_watermark),
`ifdef DEBUG
      .watermark_reg_(tx_watermark_reg_),
`endif
      .empty(tx_fifo_empty),
      .full(tx_fifo_full),
      .greater_than_watermark()
  );

  reg tx_rdy_aux, tx_fifo_empty_aux;

  // Leitura da FIFO -> UART TX pronta (borda de subida)
  // Mantenho o rd_en ativo até que a FIFO tenha algum dado para transmitir
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) begin
      tx_fifo_rd_en <= 1'b0;
      tx_fifo_empty_aux <= 1'b0;
    end else if (tx_fifo_rd_en) begin
      // Desabilito o rd_en caso houve leitura agora ou no ciclo da subida do tx_rdy
      if (!tx_fifo_empty_aux || !tx_fifo_empty) tx_fifo_rd_en <= 1'b0;
      else tx_fifo_rd_en <= 1'b1;
      tx_fifo_empty_aux <= tx_fifo_empty_aux;
    end else if (tx_rdy && !tx_rdy_aux) begin
      tx_fifo_rd_en <= 1'b1;
      // Armazeno tx_fifo_empty para averiguar se nesse ciclo houve leitura
      tx_fifo_empty_aux <= tx_fifo_empty;
    end
  end

  // Para evitar múltiplas leituras por ciclo de clock da UART
  // Detecto a borda de subida do tx_rdy
  // Apenas esse tem reset, pois no estado padrão do transmissor tx_rdy = 1'b1
  // Enquanto no estado padrão do receptor o rx_data_valid = 1'b0
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) tx_rdy_aux <= 1'b0;
    else tx_rdy_aux <= tx_rdy;
  end

  // RX FIFO
  FIFO #(
      .DATA_SIZE(8),
      .DEPTH(8)
  ) rx_fifo (
      .clock(CLK_I),
      .reset(RST_I),
      .wr_en(rx_fifo_wr_en),
      .rd_en(rx_fifo_rd_en),
      .watermark_level(rxcnt),
      .wr_data(rx_fifo_wr_data),
      .rd_data(rx_fifo_rd_data),
      .greater_than_watermark(rx_fifo_greater_than_watermark),
`ifdef DEBUG
      .watermark_reg_(rx_watermark_reg_),
`endif
      .empty(rx_fifo_empty),
      .full(rx_fifo_full),
      .less_than_watermark()
  );

  assign rx_fifo_rd_en = _rd_en & (_addr == 3'b001);

  reg rx_data_valid_aux, rx_fifo_full_aux;

  // Escrita na FIFO -> UART RX válido (borda de subida)
  // Mantenho o wr_en ativo até que a FIFO tenha espaço sobrando
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) begin
      rx_fifo_wr_en <= 1'b0;
      rx_fifo_full_aux <= 1'b0;
    end else if (rx_fifo_wr_en) begin
      // Desabilito o wr_en caso houve escrita agora ou no ciclo da subida do rx_data_valid
      if (!rx_fifo_full_aux || !rx_fifo_full) rx_fifo_wr_en <= 1'b0;
      else rx_fifo_wr_en <= 1'b1;
      rx_fifo_full_aux <= rx_fifo_full_aux;
    end else if (rx_data_valid && !rx_data_valid_aux) begin
      rx_fifo_wr_en <= 1'b1;
      // Armazeno rx_fifo_full para averiguar se nesse ciclo houve leitura
      rx_fifo_full_aux <= rx_fifo_full;
    end
  end

  // Para evitar múltiplas escritas por ciclo de clock da UART
  // Detecto a borda de subida do rx_data_valid
  always @(posedge CLK_I) begin
    rx_data_valid_aux <= rx_data_valid;
  end

  // Conversores Serial <-> Paralelo
  // TX
  uart_tx tx (
      .clock(tx_clock),
      .reset(RST_I),
      .tx_en(txen),
      .parity_type(2'b00),
      .nstop(nstop),
      .txd(txd),
      .data_in(tx_fifo_rd_data),
      .data_valid(tx_data_valid),
      .tx_rdy(tx_rdy)
  );

  // Caso o TX não esteja pronto -> Valid 0
  // Caso TX pronto e houve uma leitura na FIFO -> Valid 1
  reg tx_fifo_rd_en_aux;
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I || !tx_rdy) tx_data_valid <= 1'b0;
    else if (!tx_fifo_rd_en && tx_fifo_rd_en_aux) tx_data_valid <= 1'b1;
  end

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) tx_fifo_rd_en_aux <= 1'b0;
    else tx_fifo_rd_en_aux <= tx_fifo_rd_en;
  end

  // RX
  uart_rx rx (
      .clock(rx_clock),
      .reset(RST_I),
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
  always @(posedge CLK_I) begin
    old_div <= div;
  end

  assign div_change = |(div ^ old_div);

  // TX clock
  sync_parallel_counter #(
      .size(16),
      .init_value(0)
  ) tx_baud_rate_generator (
      .clock(CLK_I),
      .load((tx_counter == div) | div_change),
      .load_value(16'b0),
      .reset(RST_I),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(tx_counter)
  );

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I | div_change) tx_clock <= 1'b0;
    else if (tx_counter == div) tx_clock <= ~tx_clock;
    else tx_clock <= 1'b0;
  end

  // RX clock
  wire [11:0] rx_counter;
  sync_parallel_counter #(
      .size(12),
      .init_value(0)
  ) rx_baud_rate_generator (
      .clock(CLK_I),
      .load((rx_counter == div[15:4]) | div_change),
      .load_value(12'b0),
      .reset(RST_I),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(rx_counter)
  );

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I | div_change) rx_clock <= 1'b0;
    else if (rx_counter == div[15:4]) rx_clock <= 1'b1;
    else rx_clock <= 1'b0;
  end

  // FSM
  reg [2:0] present_state, next_state;  // Estado da transmissão

  // Estados possíveis
  localparam reg [2:0] Idle = 3'b000, Read = 3'b001, Write = 3'b010, EndOp = 3'b011, Final = 3'b100;

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Transição de Estado
  always @(*) begin
    next_state = Idle;
    case (present_state)
      Idle: begin
        if (rd_en) next_state = Read;
        else if (wr_en) next_state = Write;
      end
      Read: begin
        if (_addr == 3'b001) next_state = EndOp;
        else next_state = Final;
      end
      Write: begin
        if (_addr == 3'b000) next_state = EndOp;
        else next_state = Final;
      end
      EndOp:   next_state = Final;
      default: next_state = Idle;  // Final
    endcase
  end

  // Lógica de saída
  always @(posedge CLK_I, posedge RST_I) begin
    ack    <= 1'b0;
    op     <= 1'b0;
    _rd_en <= 1'b0;
    _wr_en <= 1'b0;
    end_rd <= 1'b0;
    end_wr <= 1'b0;
    if (RST_I) begin
    end else begin
      case (next_state)
        Read: begin
          op     <= 1'b1;
          _rd_en <= 1'b1;
        end
        Write: begin
          op     <= 1'b1;
          _wr_en <= 1'b1;
        end
        EndOp: begin
          op     <= 1'b1;
          end_rd <= _rd_en & (_addr == 3'b001);
          end_wr <= _wr_en & (_addr == 3'b000);
        end
        Final: begin
          ack <= 1'b1;
        end
        default: begin  // Nothing to do (Idle)
        end
      endcase
    end
  end

  assign ACK_O = ack;

`ifdef DEBUG
  assign div_ = div;
  assign p_rxwm_ = p_rxwm;
  assign p_txwm_ = p_txwm;
  assign e_txwm_ = e_txwm;
  assign e_rxwm_ = e_rxwm;
  assign rxcnt_ = rxcnt;
  assign rxen_ = rxen;
  assign txcnt_ = txcnt;
  assign nstop_ = nstop;
  assign txen_ = txen;
  assign _rx_fifo_empty_ = rx_fifo_empty_;
  assign rxdata_ = rxdata;
  assign tx_fifo_full_ = tx_fifo_full;
  assign txdata_ = txdata;
  assign present_state_ = present_state;
  assign addr_ = _addr;
  assign wr_data_ = _wr_data;
  assign rx_data_valid_ = rx_data_valid;
  assign tx_data_valid_ = tx_data_valid;
  assign tx_rdy_ = tx_rdy;
`endif

endmodule
