
module uart_tb ();

  import macros_pkg::*;
  import board_pkg::*;
  import uart_tb_pkg::*;
  import uart_pkg::*;
  import uart_phy_pkg::uart_phy_fsm_t;

  localparam integer FifoDepth = LitexArch ? 16 : 8;
  localparam integer AmntOfTests = 500;
  localparam integer ClockPeriod = 20;
  localparam integer Seed = 133;

  localparam reg Nstop = LitexArch ? 1'b0 : 1'b1;
  localparam integer TxClockPeriod = 32 * 20;
  localparam integer RxClockPeriod = TxClockPeriod / 16;

  event                         init;
  event                         initClocks;

  // Sinais do DUT
  reg                           clock;
  reg                           rx_clock;
  reg                           tx_clock;
  reg                           reset;
  reg                           cyc_o;
  reg                           stb_o;
  reg                           wr_o;
  reg   [                  2:0] addr;
  reg                           rxd;
  reg   [                 31:0] wr_data;
  wire                          txd;
  wire  [                 31:0] rd_data;
  wire                          ack_i;
  wire                          interrupt;
  wishbone_if #(.DATA_SIZE(32), .BYTE_SIZE(8), .ADDR_SIZE(3)) wb_if (.*);
  ////

  // Sinais Auxiliares
  // Interrupt Check
  wire                          tx_pending;
  wire                          rx_pending;
  reg                           tx_pending_d;
  reg                           rx_pending_d;
  reg                           tx_full_d;
  reg                           rx_empty_d;
  reg                           clear_irq;
  reg   [$clog2(FifoDepth)-1:0] tx_watermark_level;
  reg   [$clog2(FifoDepth)-1:0] rx_watermark_level;
  reg   [$clog2(FifoDepth)-1:0] rx_watermark_reg;
  reg   [$clog2(FifoDepth)-1:0] tx_watermark_reg;
  //
  // Rx Operation
  reg   [                  7:0] rx_fifo            [FifoDepth-1:0];
  reg   [$clog2(FifoDepth)-1:0] rx_read_ptr;
  reg   [$clog2(FifoDepth)-1:0] rx_write_ptr;
  wire                          rx_empty;
  reg                           expected_rx_empty;
  reg                           rd_rx_empty;
  wire                          rx_full;
  //
  // Tx Operation
  reg   [                  7:0] tx_fifo            [FifoDepth-1:0];
  reg   [$clog2(FifoDepth)-1:0] tx_read_ptr;
  reg   [$clog2(FifoDepth)-1:0] tx_write_ptr;
  wire                          tx_empty;
  wire                          tx_full;
  reg                           rd_tx_full;
  reg                           expected_tx_full;
  //
  ////
  // Rx block
  reg   [                  7:0] rx_data;
  ////
  // Tx block
  reg   [                  7:0] tx_data;
  ////
  // Sinais dos initial blocks
  processor_task_t              processor_task;
  rx_task_t                     rx_task;
  tx_task_t                     tx_task;
  // Sinais de fim dos testbenches
  reg                           end_proc;
  reg                           end_rx;
  reg                           end_tx;

  // DUT
  uart #(
      .LITEX_ARCH(LitexArch),
      .FIFO_DEPTH(FifoDepth),
      .CLOCK_FREQ_HZ(115200 * 32)
  ) DUT (
      .wb_if_s  (wb_if),
      .rxd      (rxd),       // dado serial
      .txd      (txd),       // dado de transmissão
      .interrupt(interrupt),
      .div_db(),
      .rx_pending_db(),
      .tx_pending_db(),
      .rx_pending_en_db(),
      .tx_pending_en_db(),
      .txcnt_db(),
      .rxcnt_db(),
      .txen_db(),
      .rxen_db(),
      .nstop_db(),
      .rx_fifo_empty_db(),
      .rxdata_db(),
      .tx_fifo_full_db(),
      .txdata_db(),
      .present_state_db(),
      .addr_db(),
      .wr_data_db(),
      .rx_data_valid_db(),
      .tx_data_valid_db(),
      .tx_rdy_db(),
      .rx_watermark_reg_db(),
      .tx_watermark_reg_db(),
      .tx_status_db(),
      .rx_status_db()
  );

  // Wishbone
  assign wb_if.cyc = cyc_o;
  assign wb_if.stb = stb_o;
  assign wb_if.we = wr_o;
  assign wb_if.addr = addr;
  assign wb_if.dat_o_p = wr_data;
  assign rd_data = wb_if.dat_i_p;
  assign ack_i = wb_if.ack;

  // Sinais da fifo/interrupts
  assign tx_pending = LitexArch ? tx_pending_d : (tx_watermark_reg < tx_watermark_level);
  assign rx_pending = LitexArch ? rx_pending_d : (rx_watermark_reg > rx_watermark_level);

  assign rx_full = (rx_watermark_reg == FifoDepth - 1);
  assign rx_empty = (rx_watermark_reg == 0);

  assign tx_full = (tx_watermark_reg == FifoDepth - 1);
  assign tx_empty = (tx_watermark_reg == 0);

  // Litex Pending
  always @(posedge clock) begin
    tx_full_d  <= tx_full;
    rx_empty_d <= rx_empty;
  end

  always @(posedge clock, posedge reset) begin
    if (reset) {rx_pending_d, tx_pending_d} <= 2'b00;
    else if (clear_irq) {rx_pending_d, tx_pending_d} <= wr_data[1:0];
    else begin
      if (!tx_full && tx_full_d) tx_pending_d <= 1'b1;
      if (!rx_empty && rx_empty_d) rx_pending_d <= 1'b1;
    end
  end

  // Geração de clocks
  // Clock Principal
  always #(ClockPeriod / 2) clock = ~clock;

  // RX Clock (Tick)
  initial begin
    rx_clock = 0;
    @(initClocks);
    @(posedge DUT.PHY.rx_clock);  // Sincronizando
    forever begin
      rx_clock = 1;
      #(RxClockPeriod / 2);
      rx_clock = 0;
      #(RxClockPeriod / 2);
    end
  end

  // TX Clock (Tick)
  initial begin
    tx_clock = 0;
    @(initClocks);
    @(posedge DUT.PHY.tx_clock);  // Sincronizando
    forever begin
      tx_clock = 1;
      #(TxClockPeriod / 32);
      tx_clock = 0;
      #(31 * TxClockPeriod / 32);
    end
  end

  task automatic InitLitex;
    begin
      // Configurando Interrupt Enable Register
      {cyc_o, stb_o, wr_o} = 3'h7;
      addr    = LitexInterruptEn;
      wr_data[1:0] = 2'b11;
      @(posedge ack_i);
      {cyc_o, stb_o, wr_o} = 3'h0;
    end
  endtask

  task automatic InitSiFive;
    begin
      // Configurando Receive Control Register
      {cyc_o, stb_o, wr_o} = 3'h7;
      addr                 = SiFiveRxControl;
      wr_data[18:16]       = $urandom(Seed);
      rx_watermark_level   = wr_data[18:16];
      wr_data[0]           = 1'b1;
      @(posedge ack_i);

      // Configurando Transmit Control Register
      addr               = SiFiveTxControl;
      wr_data[18:16]     = $urandom;
      tx_watermark_level = wr_data[18:16];
      wr_data[1:0]       = {Nstop, 1'b1};
      @(posedge ack_i);

      // Configurando Interrupt Enable Register
      addr    = SiFiveInterruptEn;
      wr_data[1:0] = 2'b11;
      @(posedge ack_i);

      // Configurando baud rate
      addr          = SiFiveClockDiv;
      wr_data[15:0] = $urandom;
      @(posedge ack_i);

      // Configurando baud rate
      addr          = SiFiveClockDiv;
      wr_data[15:0] = 16'h001F;
      @(posedge ack_i);
      {cyc_o, stb_o, wr_o} = 3'h0;
    end
  endtask

  // Tasks para checar a interação UART <-> Processador
  task automatic InterruptCheck;
    begin
      // Don't read interrupt during Fifo Operations
      wait ((rx_task !== RxTaskEnd) && (tx_task !== TxTaskStart));
      // Ler Interrupt Pending Register
      {cyc_o, stb_o, wr_o} = 3'h6;
      addr = (LitexArch ? LitexPending : SiFivePending);
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      CHK_INTERRUPT_TX_PENDING: assert(rd_data[0] === tx_pending);

      CHK_INTERRUPT_RX_PENDING: assert(rd_data[1] === rx_pending);

      if (LitexArch) begin
        // Limpar Interrupção
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h7;
        wr_data = 0;
        addr = LitexPending;
        @(negedge clock);
        clear_irq = 1'b1;
        {cyc_o, stb_o, wr_o} = 3'h0;
        @(posedge ack_i);
        @(negedge clock);
        clear_irq = 1'b0;
      end
    end
  endtask

  task automatic StatusCheck;
    begin
      // Don't read status during Fifo Operations
      wait ((rx_task !== RxTaskEnd) && (tx_task !== TxTaskStart));
      // Read Status
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = LitexStatus;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);
      CHK_STATUS_TX_FULL: assert(rd_data[0] === !tx_full);
      CHK_STATUS_RX_EMPTY: assert(rd_data[1] === !rx_empty);
      CHK_STATUS_INTERRUPT: assert(interrupt === (tx_pending || rx_pending));
    end
  endtask

  task automatic ReadOp;
    begin
      wait (rx_task !== RxTaskEnd);  // Don't read during writing in Rx Fifo
      // Operação de leitura:
      //  checa por empty antes
      //  Lê (aleatório)
      {cyc_o, stb_o, wr_o} = 3'h6;
      addr = LitexArch ? LitexRxEmpty : SiFiveRxData;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge clock);
      expected_rx_empty = (rx_watermark_reg == 0);
      @(posedge ack_i);
      @(negedge clock);

      rd_rx_empty = LitexArch ? rd_data[0] : rd_data[31];

      if (LitexArch) begin  // More 1 access to get the rx data
        wait (rx_task !== RxTaskEnd);
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h6;
        addr = LitexData;
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h0;
        @(posedge ack_i);
        @(negedge clock);
      end

      if (!rx_empty) begin
        rx_read_ptr = rx_read_ptr + 1'b1;
        rx_watermark_reg = rx_watermark_reg - 1'b1;
      end

      CHK_RD_OP_RX_EMPTY: assert(expected_rx_empty === rd_rx_empty);
      CHK_RD_OP_RX_DATA: assert(rx_fifo[rx_read_ptr] === rd_data[7:0]);
      CHK_RD_OP_RX_PTR: assert(rx_read_ptr === DUT.PHY.rx_fifo.rd_reg);
      CHK_RD_OP_RX_WATERMARK: assert(rx_watermark_reg === DUT.PHY.rx_fifo.watermark_reg);

    end
  endtask

  task automatic WriteOp;
    begin
      wait (tx_task !== TxTaskStart);  // Don't read during reading in Tx Fifo
      // Operação de escrita:
      //  checa por full antes
      //  escreve (aleatório)
      {cyc_o, stb_o, wr_o} = 3'h7;
      addr = LitexArch ? LitexTxFull : SiFiveTxData;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      rd_tx_full = LitexArch ? rd_data[0] : rd_data[31];
      expected_tx_full = tx_full;

      // More 1 access to write tx data
      if (LitexArch && !tx_full) begin
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h7;
        addr = LitexData;
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h0;
        @(posedge ack_i);
        @(negedge clock);
      end

      if (!tx_full) begin
        tx_fifo[tx_write_ptr] = wr_data[7:0];
        tx_write_ptr = tx_write_ptr + 1;
        tx_watermark_reg = tx_watermark_reg + 1'b1;
      end

      CHK_WR_OP_TX_FULL: assert((LitexArch ? expected_tx_full :
                                (tx_watermark_reg === FifoDepth - 1)) === rd_tx_full);
      CHK_WR_OP_TX_PTR: assert(tx_write_ptr === DUT.PHY.tx_fifo.wr_reg);
      CHK_WR_OP_TX_WATERMARK: assert(tx_watermark_reg === DUT.PHY.tx_fifo.watermark_reg);
      CHK_WR_OP_TX_DATA: assert(tx_fifo[tx_write_ptr-1] ===
                                DUT.PHY.tx_fifo.fifo_memory[DUT.PHY.tx_fifo.wr_reg-1]);
    end
  endtask

  task automatic TxEmptyCheck;
    begin
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = LitexTxEmpty;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      CHK_TX_EMPTY: assert((tx_watermark_reg == 0) === rd_data[0]);
    end
  endtask

  task automatic RxFullCheck;
    begin
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = LitexRxFull;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      CHK_RX_FULL: assert((rx_watermark_reg == FifoDepth - 1) === rd_data[0]);
    end
  endtask

  integer i1, i2, i3;

  // Processor's Initial Block
  initial begin
    // Inicializando
    {clock, reset, cyc_o, stb_o, wr_o, addr, wr_data, tx_watermark_level, clear_irq,
    tx_watermark_reg, rx_watermark_level, rx_watermark_reg, tx_write_ptr} = 0;
    rx_read_ptr = FifoDepth - 1;
    end_proc = 1'b0;

    // Reset
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;

    if (LitexArch) begin
      InitLitex();
    end else begin
      InitSiFive();
    end

    ->initClocks;  // iniciar tx(rx) clock

    @(negedge tx_clock);  // sincronizar as seriais
    ->init;

    $display("[%0t] SOT", $time);

    @(negedge clock);
    for (i1 = 0; i1 < 25 * AmntOfTests; i1 = i1 + 1) begin
      processor_task = processor_task_t'($urandom);
      wr_data = $urandom;

      if (processor_task === ProcessorReadOp) ReadOp();
      else if (processor_task === ProcessorWriteOp) WriteOp();
      else if (processor_task === ProcessorInterruptCheck) InterruptCheck();
      else if ((processor_task === ProcessorStatusCheck) && LitexArch) StatusCheck();
      else if ((processor_task === ProcessorTxEmptyCheck) && LitexArch) TxEmptyCheck();
      else if ((processor_task === ProcessorRxFullCheck) && LitexArch) RxFullCheck();
      processor_task = ProcessorIdle;
      // Atraso a execução do loop
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
    end
    end_proc = 1'b1;
    $display("[%0t] EOT processor", $time);
  end

  // Tasks para checar a interação UART <-> Serial RX
  task automatic RxStart;
    begin
      rx_task = RxTaskStart;

      rxd = 0;
      @(negedge tx_clock);

      CHK_RX_START: assert(DUT.PHY.rx.present_state === uart_phy_pkg::Start);

    end
  endtask

  task automatic RxData;
    integer j;
    begin
      rx_task = RxTaskData;

      for (j = 0; j < 8; j = j + 1) begin
        rxd = rx_data[j];
        @(negedge tx_clock);
        CHK_RX_STATE_DATA: assert(DUT.PHY.rx.present_state === uart_phy_pkg::Data);
      end
    end
  endtask

  task automatic RxStop1;
    begin
      rx_task = RxTaskStop1;

      rxd = 1'b1;
      @(negedge tx_clock);

      CHK_RX_STATE_STOP1: assert(DUT.PHY.rx.present_state === uart_phy_pkg::Stop1);

    end
  endtask

  task automatic RxStop2;
    begin
      rx_task = RxTaskStop2;
      rxd = 1'b1;
      @(negedge tx_clock);

      CHK_RX_STATE_STOP2: assert(DUT.PHY.rx.present_state === uart_phy_pkg::Stop2);

    end
  endtask

  task automatic EndRx;
    begin
      rx_task = RxTaskEnd;
      @(negedge tx_clock);

      rx_fifo[rx_write_ptr] = rx_data;
      rx_write_ptr = rx_write_ptr + 1'b1;
      rx_watermark_reg = rx_watermark_reg + 1'b1;

      CHK_RX_DATA_END: assert(rx_fifo[rx_write_ptr-1'b1] ===
                              DUT.PHY.rx_fifo.fifo_memory[DUT.PHY.rx_fifo.wr_reg-1'b1]);
      CHK_RX_PTR_END: assert(rx_write_ptr === DUT.PHY.rx_fifo.wr_reg);
      CHK_RX_WATERMARK_END: assert(rx_watermark_reg === DUT.PHY.rx_fifo.watermark_reg);
    end
  endtask

  // Rx's Initial Block
  initial begin
    rxd = 1'b1;
    rx_task = RxTaskInit;
    rx_write_ptr = 0;
    end_rx = 1'b0;

    @(init);
    @(negedge rx_clock);
    for (i2 = 0; i2 < AmntOfTests; i2 = i2 + 1) begin
      rx_data = $urandom;

      RxStart();

      RxData();

      RxStop1();

      if (Nstop) RxStop2();

      if (~rx_full) EndRx();
      else begin
        rx_task = RxTaskSyncTx;
        @(negedge tx_clock);
      end
    end
    end_rx = 1'b1;
    $display("[%0t] EOT RX", $time);
  end

  // Tasks para checar a interação UART <-> Serial TX
  task automatic TxStart;
    begin
      tx_task = TxTaskStart;
      @(posedge clock);
      tx_read_ptr = tx_read_ptr + 1;
      tx_data = tx_fifo[tx_read_ptr];
      tx_watermark_reg = tx_watermark_reg - 1;
      @(negedge clock);
      @(negedge clock);
      @(negedge tx_clock);

      CHK_TX_START: assert(txd === 1'b0);

    end
  endtask

  task automatic TxData;
    integer k;
    begin
      tx_task = TxTaskData;
      @(negedge tx_clock);

      for (k = 0; k < 8; k = k + 1) begin
        CHK_TX_DATA: assert(txd === tx_data[k]);
        @(negedge tx_clock);
      end

    end
  endtask

  task automatic TxStop1;
    begin
      tx_task = TxTaskStop1;

      @(negedge tx_clock);
      CHK_TX_STOP1: assert(txd === 1'b1);

    end
  endtask

  task automatic TxStop2;
    begin
      tx_task = TxTaskStop2;
      @(negedge tx_clock);

      CHK_TX_STOP2: assert(txd === 1'b1);

    end
  endtask

  // Tx's Initial Block
  initial begin
    tx_task = TxTaskInit;
    tx_read_ptr = -1;
    end_tx = 1'b0;

    @(init);
    for (i3 = 0; (i3 < AmntOfTests) || !tx_empty; i3 = i3 + 1) begin
      tx_task = TxTaskInit;
      if (~tx_empty) begin

        TxStart();

        TxData();

        TxStop1();

        if (Nstop) TxStop2();
      end
      @(negedge clock);
    end
    end_tx = 1'b1;
    $display("[%0t] EOT TX", $time);
  end

  // End testbench
  always_comb begin
    if (end_proc && end_rx && end_tx) begin
      $display("[%0t] EOT Sucess!", $time);
      $stop;
    end
  end

endmodule
