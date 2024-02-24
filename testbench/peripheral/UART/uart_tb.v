//
//! @file   uart_tb.v
//! @brief  Testbench de uma implementação de UART
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-05-29
//

`include "macros.vh"
`include "boards.vh"

`define ASSERT(condition) if (!(condition)) $stop

module uart_tb ();

`ifdef LITEX_
  localparam integer LitexArch = 1;
`else
  localparam integer LitexArch = 0;
`endif
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
  // Modo de Operação do Processador
  reg   [                  2:0] proc_op;
  ////
  // Sinais dos initial blocks
  reg   [                  2:0] processor_task;
  reg   [                  2:0] rx_task;
  reg   [                  2:0] tx_task;
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
      .CLK_I    (clock),
      .RST_I    (reset),
      .CYC_I    (cyc_o),
      .STB_I    (stb_o),
      .WE_I     (wr_o),
      .ADR_I    (addr),      // 0x00 a 0x18
      .rxd      (rxd),       // dado serial
      .DAT_I    (wr_data),
      .txd      (txd),       // dado de transmissão
      .DAT_O    (rd_data),
      .ACK_O    (ack_i),
      .interrupt(interrupt)
  );

  // Sinais da FIFO/interrupts
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
      addr    = 3'b101;
      wr_data[1:0] = 2'b11;
      @(posedge ack_i);
      {cyc_o, stb_o, wr_o} = 3'h0;
    end
  endtask

  task automatic InitSiFive;
    begin
      // Configurando Receive Control Register
      {cyc_o, stb_o, wr_o} = 3'h7;
      addr                 = 3'b011;
      wr_data[18:16]       = $urandom(Seed);
      rx_watermark_level   = wr_data[18:16];
      wr_data[0]           = 1'b1;
      @(posedge ack_i);

      // Configurando Transmit Control Register
      addr               = 3'b010;
      wr_data[18:16]     = $urandom;
      tx_watermark_level = wr_data[18:16];
      wr_data[1:0]       = {Nstop, 1'b1};
      @(posedge ack_i);

      // Configurando Interrupt Enable Register
      addr    = 3'b100;
      wr_data[1:0] = 2'b11;
      @(posedge ack_i);

      // Configurando baud rate
      addr          = 3'b110;
      wr_data[15:0] = $urandom;
      @(posedge ack_i);

      // Configurando baud rate
      addr          = 3'b110;
      wr_data[15:0] = 16'h001F;
      @(posedge ack_i);
      {cyc_o, stb_o, wr_o} = 3'h0;
    end
  endtask

  // Tasks para checar a interação UART <-> Processador
  task automatic InterruptCheck;
    begin
      processor_task = 3'b000;
      // Don't read interrupt during Fifo Operations
      wait ((rx_task !== 3'b101) && (tx_task !== 3'b001));
      // Ler Interrupt Pending Register
      {cyc_o, stb_o, wr_o} = 3'h6;
      addr = (LitexArch ? 3'b100 : 3'b101);
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      `ASSERT(rd_data[0] === tx_pending);

      `ASSERT(rd_data[1] === rx_pending);

      if (LitexArch) begin
        // Limpar Interrupção
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h7;
        wr_data = 0;
        addr = 3'b100;
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
      processor_task = 3'b001;
      // Don't read status during Fifo Operations
      wait ((rx_task !== 3'b101) && (tx_task !== 3'b001));
      // Read Status
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = 3'b011;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);
      `ASSERT(rd_data[0] === !tx_full);
      `ASSERT(rd_data[1] === !rx_empty);
      `ASSERT(interrupt === (tx_pending || rx_pending));
    end
  endtask

  task automatic ReadOp;
    begin
      processor_task = 3'b010;
      wait (rx_task !== 3'b101);  // Don't read during writing in Rx Fifo
      // Operação de leitura:
      //  checa por empty antes
      //  Lê (aleatório)
      {cyc_o, stb_o, wr_o} = 3'h6;
      addr = LitexArch ? 3'b010 : 3'b001;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge clock);
      expected_rx_empty = (rx_watermark_reg == 0);
      @(posedge ack_i);
      @(negedge clock);

      rd_rx_empty = LitexArch ? rd_data[0] : rd_data[31];

      if (LitexArch) begin  // More 1 access to get the rx data
        wait (rx_task !== 3'b101);
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h6;
        addr = 3'b000;
        @(negedge clock);
        {cyc_o, stb_o, wr_o} = 3'h0;
        @(posedge ack_i);
        @(negedge clock);
      end

      if (!rx_empty) begin
        rx_read_ptr = rx_read_ptr + 1'b1;
        rx_watermark_reg = rx_watermark_reg - 1'b1;
      end

      `ASSERT(expected_rx_empty === rd_rx_empty);
      `ASSERT(rx_fifo[rx_read_ptr] === rd_data[7:0]);
      `ASSERT(rx_read_ptr === DUT.PHY.rx_fifo.rd_reg);
      `ASSERT(rx_watermark_reg === DUT.PHY.rx_fifo.watermark_reg);

    end
  endtask

  task automatic WriteOp;
    begin
      processor_task = 3'b011;
      wait (tx_task !== 3'b001);  // Don't read during reading in Tx Fifo
      // Operação de escrita:
      //  checa por full antes
      //  escreve (aleatório)
      {cyc_o, stb_o, wr_o} = 3'h7;
      addr = LitexArch ? 3'b001 : 3'b000;
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
        addr = 3'b000;
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

      `ASSERT((LitexArch ? expected_tx_full : (tx_watermark_reg === FifoDepth - 1)) === rd_tx_full);
      `ASSERT(tx_write_ptr === DUT.PHY.tx_fifo.wr_reg);
      `ASSERT(tx_watermark_reg === DUT.PHY.tx_fifo.watermark_reg);
      `ASSERT(tx_fifo[tx_write_ptr-1] === DUT.PHY.tx_fifo.fifo_memory[DUT.PHY.tx_fifo.wr_reg-1]);
    end
  endtask

  task automatic TxEmptyCheck;
    begin
      processor_task = 3'b100;
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = 3'b110;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      `ASSERT((tx_watermark_reg == 0) === rd_data[0]);
    end
  endtask

  task automatic RxFullCheck;
    begin
      processor_task = 3'b101;
      {cyc_o, stb_o, wr_o} = 3'h7;  // Tento "escrever"
      addr = 3'b111;
      @(posedge clock);
      @(negedge clock);
      {cyc_o, stb_o, wr_o} = 3'h0;
      @(posedge ack_i);
      @(negedge clock);

      `ASSERT((rx_watermark_reg == FifoDepth - 1) === rd_data[0]);
    end
  endtask

  integer i1, i2, i3;

  // Processor's Initial Block
  initial begin
    // Inicializando
    {clock, reset, cyc_o, stb_o, wr_o, addr, wr_data, tx_watermark_level, clear_irq,
    tx_watermark_reg, rx_watermark_level, rx_watermark_reg, tx_write_ptr, proc_op} = 0;
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
      proc_op = $urandom;
      wr_data = $urandom;

      if (proc_op === 3'b000) ReadOp();
      else if (proc_op === 3'b001) WriteOp();
      else if (proc_op === 3'b010) InterruptCheck();
      else if ((proc_op === 3'b011) && LitexArch) StatusCheck();
      else if ((proc_op === 3'b100) && LitexArch) TxEmptyCheck();
      else if ((proc_op === 3'b101) && LitexArch) RxFullCheck();
      processor_task = 3'b000;
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
      rx_task = 3'b001;

      rxd = 0;
      @(negedge tx_clock);

      `ASSERT(DUT.PHY.rx.present_state === DUT.PHY.rx.Start);

    end
  endtask

  task automatic RxData;
    integer j;
    begin
      rx_task = 3'b010;

      for (j = 0; j < 8; j = j + 1) begin
        rxd = rx_data[j];
        @(negedge tx_clock);
        `ASSERT(DUT.PHY.rx.present_state === DUT.PHY.rx.Data);
      end
    end
  endtask

  task automatic RxStop1;
    begin
      rx_task = 3'b011;

      rxd = 1'b1;
      @(negedge tx_clock);

      `ASSERT(DUT.PHY.rx.present_state === DUT.PHY.rx.Stop1);

    end
  endtask

  task automatic RxStop2;
    begin
      rx_task = 3'b100;
      rxd = 1'b1;
      @(negedge tx_clock);

      `ASSERT(DUT.PHY.rx.present_state === DUT.PHY.rx.Stop2);

    end
  endtask

  task automatic EndRx;
    begin
      rx_task = 3'b101;
      @(negedge tx_clock);

      rx_fifo[rx_write_ptr] = rx_data;
      rx_write_ptr = rx_write_ptr + 1'b1;
      rx_watermark_reg = rx_watermark_reg + 1'b1;

      `ASSERT(
          rx_fifo[rx_write_ptr-1'b1] === DUT.PHY.rx_fifo.fifo_memory[DUT.PHY.rx_fifo.wr_reg-1'b1]);
      `ASSERT(rx_write_ptr === DUT.PHY.rx_fifo.wr_reg);
      `ASSERT(rx_watermark_reg === DUT.PHY.rx_fifo.watermark_reg);
    end
  endtask

  // Rx's Initial Block
  initial begin
    rxd = 1'b1;
    rx_task = 3'b000;
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
        rx_task = 3'b110;
        @(negedge tx_clock);
      end
    end
    end_rx = 1'b1;
    $display("[%0t] EOT RX", $time);
  end

  // Tasks para checar a interação UART <-> Serial TX
  task automatic TxStart;
    begin
      tx_task = 3'b001;
      @(posedge clock);
      tx_read_ptr = tx_read_ptr + 1;
      tx_data = tx_fifo[tx_read_ptr];
      tx_watermark_reg = tx_watermark_reg - 1;
      @(negedge clock);
      @(negedge clock);
      @(negedge tx_clock);

      `ASSERT(txd === 1'b0);

    end
  endtask

  task automatic TxData;
    integer k;
    begin
      tx_task = 3'b010;
      @(negedge tx_clock);

      for (k = 0; k < 8; k = k + 1) begin
        `ASSERT(txd === tx_data[k]);
        @(negedge tx_clock);
      end

    end
  endtask

  task automatic TxStop1;
    begin
      tx_task = 3'b011;

      @(negedge tx_clock);
      `ASSERT(txd === 1'b1);

    end
  endtask

  task automatic TxStop2;
    begin
      tx_task = 3'b100;
      @(negedge tx_clock);

      `ASSERT(txd === 1'b1);

    end
  endtask

  // Tx's Initial Block
  initial begin
    tx_task = 3'b000;
    tx_read_ptr = -1;
    end_tx = 1'b0;

    @(init);
    for (i3 = 0; (i3 < AmntOfTests) || !tx_empty; i3 = i3 + 1) begin
      tx_task = 3'b000;
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
  always @(*) begin
    if (end_proc && end_rx && end_tx) begin
      $display("[%0t] EOT Sucess!", $time);
      $stop;
    end
  end

endmodule
