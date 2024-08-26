
import board_pkg::*;

module uart_top (
    // Comum
    input wire clock,
    input wire reset,
    // PC
    input wire rxd,
    output wire txd,
    // Depuração
    input wire [3:0] sw,
    output reg [LedSize-1:0] leds
);

  import uart_top_pkg::*;

  localparam integer FifoDepth = LitexArch ? 16 : 8;
  localparam reg Nstop = 1'b0;  // Numero de stop bits

  // Sinais para controlar o DUT
  wishbone_if #(.DATA_SIZE(32), .BYTE_SIZE(8), .ADDR_SIZE(5)) wb_if (.*);
  reg                          rd_en;
  reg                          wr_en;
  reg  [                  2:0] addr;
  reg  [                 31:0] wr_data;
  wire [                 31:0] rd_data;
  wire                         ack;
  wire                         interrupt;
  // Depuração
  wire [                 15:0] div_db;
  wire                         rx_pending_db;
  wire                         tx_pending_db;
  wire                         rx_pending_en_db;
  wire                         tx_pending_en_db;
  wire [$clog2(FifoDepth)-1:0] rxcnt_db;
  wire                         rxen_db;
  wire [$clog2(FifoDepth)-1:0] txcnt_db;
  wire                         txen_db;
  wire                         nstop_db;
  wire                         rx_fifo_empty_db;
  wire [                  7:0] rxdata_db;
  wire                         tx_fifo_full_db;
  wire [                  7:0] txdata_db;
  wire [                  2:0] present_state_db;
  wire [                  2:0] addr_db;
  wire [                 31:0] wr_data_db;
  wire                         rx_data_valid_db;
  wire                         tx_data_valid_db;
  wire                         tx_rdy_db;
  wire [$clog2(FifoDepth)-1:0] rx_watermark_reg_db;
  wire [$clog2(FifoDepth)-1:0] tx_watermark_reg_db;
  wire                         tx_status_db;
  wire                         rx_status_db;

  // FSM
  uart_top_fsm_t present_state, next_state;

  uart #(
      .LITEX_ARCH(LitexArch),
      .FIFO_DEPTH(FifoDepth),
      .CLOCK_FREQ_HZ(100000000)  // 100 MHz
  ) DUT (
      .wb_if_s            (wb_if),
      .rxd                (rxd),
      .txd                (txd),
      .interrupt          (interrupt),
      .div_db             (div_db),
      .rx_pending_db      (rx_pending_db),
      .tx_pending_db      (tx_pending_db),
      .tx_pending_en_db   (tx_pending_en_db),
      .rx_pending_en_db   (rx_pending_en_db),
      .rxcnt_db           (rxcnt_db),
      .rxen_db            (rxen_db),
      .txcnt_db           (txcnt_db),
      .nstop_db           (nstop_db),
      .txen_db            (txen_db),
      .rx_fifo_empty_db   (rx_fifo_empty_db),
      .rxdata_db          (rxdata_db),
      .tx_fifo_full_db    (tx_fifo_full_db),
      .txdata_db          (txdata_db),
      .present_state_db   (present_state_db),
      .addr_db            (addr_db),
      .wr_data_db         (wr_data_db),
      .rx_data_valid_db   (rx_data_valid_db),
      .tx_data_valid_db   (tx_data_valid_db),
      .tx_rdy_db          (tx_rdy_db),
      .rx_watermark_reg_db(rx_watermark_reg_db),
      .tx_watermark_reg_db(tx_watermark_reg_db),
      .tx_status_db       (tx_status_db),
      .rx_status_db       (rx_status_db)
  );

  // Wishbone
  always_comb begin
    wb_if.cyc = 1'b0;
    wb_if.stb = 1'b0;
    wb_if.we  = 1'b0;
    if (wr_en) begin
      wb_if.cyc = 1'b1;
      wb_if.stb = 1'b1;
      wb_if.we  = 1'b1;
    end else if (rd_en) begin
      wb_if.cyc = 1'b1;
      wb_if.stb = 1'b1;
    end
  end
  assign wb_if.addr = {addr, 2'b00};
  assign wb_if.dat_o_p = wr_data;
  assign rd_data = wb_if.dat_i_p;
  assign ack = wb_if.ack;

  // Transição de Estado
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Saída da FSM
  always_comb begin
    rd_en = 1'b0;
    wr_en = 1'b0;
    addr = 3'b0;
    wr_data = 0;
    unique case (present_state)
      Idle: begin
        next_state = LitexArch ? ConfInterruptEn : ConfReceiveControl;
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
        addr = LitexArch ? 3'b101 : 3'b100;
        wr_data[1:0] = 2'b11;
        if (ack) next_state = WaitInterrupt;
        else next_state = ConfInterruptEn;
      end
      // Estados de Operação da UART
      // Espera uma interrupção
      WaitInterrupt: begin
        addr = LitexArch ? 3'b000 : 3'b001;
        if (interrupt) begin
          rd_en = 1'b1;
          next_state = ReadingData;
        end else next_state = WaitInterrupt;
      end
      // Realizando a leitura
      ReadingData: begin
        rd_en = 1'b1;
        addr  = LitexArch ? 3'b000 : 3'b001;
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
        if (ack) next_state = LitexArch ? ClearInterrupt : WaitInterrupt;
        else next_state = WritingData;
      end
      default: begin
        next_state = Idle;
      end
      ClearInterrupt: begin
        wr_en = 1'b1;
        addr = 3'b100;
        wr_data = 0;
        if (ack) next_state = WaitInterrupt;
        else next_state = ClearInterrupt;
      end
    endcase
  end

  // Leds de Depuração
  generate;
    if(LitexArch) begin: gen_debug_nexys
      always_comb begin
        unique case (sw)
          0: leds = div_db;
          1:
          leds = {
            present_state_db,
            rx_pending_db,
            tx_pending_db,
            rx_pending_en_db,
            tx_pending_en_db,
            rxcnt_db,
            rxen_db,
            txcnt_db,
            txen_db,
            nstop_db
          };
          2: leds = {rxdata_db, txdata_db};
          3:
          leds = {
            2'b00,
            rx_status_db,
            tx_status_db,
            addr_db,
            rx_data_valid_db,
            tx_data_valid_db,
            tx_rdy_db,
            rx_watermark_reg_db,
            tx_watermark_reg_db
          };
          4: leds = wr_data_db[15:0];
          5: leds = wr_data_db[31:16];
          6: leds = {6'b0, rx_fifo_empty_db, tx_fifo_full_db, rd_en, wr_en, addr, present_state};
          default: leds = wr_data_db[15:0];
        endcase
      end
    end else begin: gen_debug_de10
      always_comb begin
        unique case (sw)
          0: leds = {2'b00, div_db[7:0]};
          1: leds = {2'b00, div_db[15:8]};
          2: leds = {rx_pending_db, tx_pending_db, rx_pending_en_db,
                     tx_pending_en_db, rxcnt_db, rxen_db};
          3: leds = {1'b0, txcnt_db, txen_db, nstop_db, rx_fifo_empty_db, tx_fifo_full_db};
          4: leds = {1'b0, rx_status_db, rxdata_db};
          5: leds = {1'b0, tx_status_db, txdata_db};
          6: leds = {1'b0, present_state_db, addr_db, rx_data_valid_db,
                     tx_data_valid_db, tx_rdy_db};
          7: leds = {2'b00, rx_watermark_reg_db, tx_watermark_reg_db};
          8: leds = {2'b00, wr_data_db[7:0]};
          9: leds = {2'b00, wr_data_db[15:8]};
          10: leds = {2'b00, wr_data_db[23:16]};
          11: leds = {2'b00, wr_data_db[31:24]};
          12: leds = {3'b000, rd_en, wr_en, addr};
          13: leds = {4'b0000, present_state};
          default: leds = {2'b00, div_db[7:0]};
        endcase
      end
    end
  endgenerate
endmodule
