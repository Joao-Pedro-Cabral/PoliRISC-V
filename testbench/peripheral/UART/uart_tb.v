//
//! @file   uart_tb.v
//! @brief  Testbench de uma implementação de UART
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-05-29
//

`timescale 1 ns / 100 ps

`define ASSERT(condition) if (!(condition)) $stop

module uart_tb ();

  localparam integer AmntOfTests = 1000;
  localparam integer ClockPeriod = 20;
  localparam integer Seed = 106278;

  localparam reg Nstop = 1'b1;
  localparam integer TxClockPeriod = 32 * 20;
  localparam integer RxClockPeriod = TxClockPeriod / 16;

  event        init;

  // Sinais do DUT
  reg          clock;
  reg          rx_clock;
  reg          rx_clock_en;
  reg          tx_clock;
  reg          tx_clock_en;
  reg          reset;
  reg          rd_en;
  reg          wr_en;
  reg   [ 4:0] addr;
  reg          rxd;
  reg   [31:0] wr_data;
  wire         txd;
  wire  [31:0] rd_data;
  wire         busy;
  ////

  // Sinais Auxiliares
  // Interrupt Check
  wire         txwm;
  wire         rxwm;
  reg   [ 2:0] tx_watermark_level;
  reg   [ 2:0] rx_watermark_level;
  reg   [ 2:0] rx_watermark_reg;
  reg   [ 2:0] tx_watermark_reg;
  //
  // Read Operation
  reg   [ 7:0] rx_fifo            [7:0];
  reg   [ 2:0] rx_read_ptr;
  reg   [ 2:0] rx_write_ptr;
  wire         rx_empty;
  wire         rx_full;
  //
  // Write Operation
  reg   [ 7:0] tx_fifo            [7:0];
  reg   [ 2:0] tx_read_ptr;
  reg   [ 2:0] tx_write_ptr;
  wire         tx_empty;
  wire         tx_full;
  //
  ////
  // Rx block
  reg   [ 7:0] rx_data;
  ////
  // Tx block
  reg   [ 7:0] tx_data;
  ////

  uart #(
      .CLOCK_FREQ_HZ(115200 * 20)
  ) DUT (
      .clock  (clock),
      .reset  (reset),
      .rd_en  (rd_en),
      .wr_en  (wr_en),
      .addr   (addr),     // 0x00 a 0x18
      .rxd    (rxd),      // dado serial
      .wr_data(wr_data),
      .txd    (txd),      // dado de transmissão
      .rd_data(rd_data),
      .busy   (busy)
  );

  task automatic InterruptCheck;
    begin
      // Ler Interrupt Pending Register
      //  Se houver interrupt de leitura, o serve
      //  Se houver interrupt de escrita, o serve
      addr[4:2] = 3'b101;
      @(negedge clock);

      `ASSERT(rd_data[0] === txwm);

      `ASSERT(rd_data[1] === rxwm);
    end
  endtask

  task automatic ReadOp;
    begin
      // Operação de leitura:
      //  checa por empty antes
      //  Lê (aleatório)
      addr[4:2] = 3'b001;
      @(posedge busy);
      @(negedge busy);

      `ASSERT(rx_empty === rd_data[31]);

      if (~rx_empty) begin
        `ASSERT(rx_fifo[rx_read_ptr] === rd_data[7:0]);
        rx_read_ptr = rx_read_ptr + 1'b1;
        rx_watermark_reg = rx_watermark_reg - 1'b1;
        `ASSERT(rx_read_ptr == DUT.rx_fifo.rd_reg);
        `ASSERT(rx_watermark_reg == DUT.rx_fifo.watermark_reg);
      end
      @(negedge clock);
    end
  endtask

  task automatic WriteOp;
    begin
      // Operação de escrita:
      //  checa por full antes
      //  escreve (aleatório)
      addr[4:2] = 3'b000;
      @(posedge busy);
      @(negedge busy);

      `ASSERT(tx_full === rd_data[31]);

      if (~tx_full) begin
        tx_fifo[tx_write_ptr] = wr_data[7:0];
        tx_write_ptr = tx_write_ptr + 1;
        tx_watermark_reg = tx_watermark_reg + 1'b1;
        `ASSERT(tx_fifo[tx_write_ptr-1] === DUT.tx_fifo.fifo_memory[DUT.tx_fifo.wr_reg-1]);
        `ASSERT(tx_write_ptr == DUT.tx_fifo.wr_reg);
        `ASSERT(tx_watermark_reg == DUT.tx_fifo.watermark_reg);
      end

      @(negedge clock);
    end
  endtask

  assign txwm = (tx_watermark_reg < tx_watermark_level);
  assign rxwm = (rx_watermark_reg > rx_watermark_level);

  assign rx_full = (rx_watermark_reg == 3'b111);
  assign rx_empty = (rx_watermark_reg == 3'b000);

  assign tx_full = (tx_watermark_reg == 3'b111);
  assign tx_empty = (tx_watermark_reg == 3'b000);

  always #(ClockPeriod / 2) clock = ~clock;

  initial begin
    while (1) begin
      if (rx_clock_en) begin
        rx_clock = 0;
        #(RxClockPeriod / 2);
        rx_clock = 1;
        #(RxClockPeriod / 2);
      end
    end
  end

  initial begin
    while (1) begin
      if (tx_clock_en) begin
        tx_clock = 0;
        #(TxClockPeriod / 2);
        tx_clock = 1;
        #(TxClockPeriod / 2);
      end
      else 
    end
  end


  integer i;

  // Processor's Initial Block
  initial begin
    {clock, reset, rd_en, wr_en, addr, wr_data, tx_watermark_level,
      tx_watermark_reg, rx_watermark_level, rx_watermark_reg, tx_write_ptr} = 0;
    rx_read_ptr = -3'b001;

    fork
      begin
        @(negedge clock);
        @(posedge clock);
        {tx_clock_en, rx_clock_en} = 0;
      end
      begin
        @(negedge clock);
        reset = 1'b1;
        @(negedge clock);
        reset = 1'b0;
      end
    join


    // Configurando Receive Control Register
    wr_en              = 1'b1;
    addr[4:2]          = 3'b011;
    wr_data[18:16]     = $urandom(Seed);
    rx_watermark_level = wr_data[18:16];
    wr_data[0]         = 1'b1;
    @(posedge busy);
    @(negedge busy);

    // Configurando Transmit Control Register
    addr[4:2]          = 3'b010;
    wr_data[18:16]     = $urandom;
    tx_watermark_level = wr_data[18:16];
    wr_data[1:0]       = {Nstop, 1'b1};
    @(posedge busy);
    @(negedge busy);

    // Configurando Interrupt Enable Register
    addr[4:2]    = 3'b100;
    wr_data[1:0] = 2'b11;
    @(posedge busy);
    @(negedge busy);
    ->init;

    //  baud rate

    $display("[%0t] SOT", $time);

    // Entradas randômicas:
    //  rd_en
    //  wr_en
    //  wr_data

    @(negedge clock);
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      rd_en   = 1'b1;
      wr_en   = $urandom;
      wr_data = $urandom;

      InterruptCheck();

      rd_en = ~wr_en;

      if (rd_en) ReadOp();
      else WriteOp();
    end
    $display("[%0t] EOT", $time);
    $stop;
  end

  task automatic RxStart;
    begin
      rxd = 0;
      @(negedge rx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Start);

    end
  endtask

  task automatic RxData;
    integer j;
    begin
      for (j = 0; j < 8; j = j + 1) begin
        rxd = rx_data[j];
        @(negedge rx_clock);
        `ASSERT(DUT.rx.present_state === DUT.rx.Data);
      end
    end
  endtask

  task automatic RxStop1;
    begin
      rxd = 1'b1;
      @(negedge rx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Stop1);

    end
  endtask

  task automatic RxStop2;
    begin
      rxd = 1'b1;
      @(negedge rx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Stop2);

    end
  endtask

  task automatic EndRx;
    begin

      rx_fifo[rx_write_ptr] = rx_data;
      rx_write_ptr = rx_write_ptr + 1'b1;
      rx_watermark_reg = rx_watermark_reg + 1'b1;
      @(negedge rx_clock);

      `ASSERT(rx_fifo[rx_write_ptr-1'b1] === DUT.rx_fifo.fifo_memory[DUT.rx_fifo.wr_reg-1'b1]);
      `ASSERT(rx_write_ptr === DUT.rx_fifo.wr_reg);
      `ASSERT(rx_watermark_reg == DUT.rx_fifo.watermark_reg);
    end
  endtask

  // Rx's Initial Block
  initial begin
    rxd = 1'b1;
    rx_write_ptr = 3'b000;


    @(init);
    @(negedge rx_clock);
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      rx_data = $urandom;

      RxStart();

      RxData();

      RxStop1();

      if (Nstop) RxStop2();

      if (~rx_full) EndRx();
    end
  end

  task automatic TxStart;
    begin
      @(negedge tx_clock);

      `ASSERT(txd == 1'b0);

    end
  endtask

  task automatic TxData;
    integer k;
    begin
      tx_data = tx_fifo[tx_read_ptr];
      tx_read_ptr = tx_read_ptr + 1;
      tx_watermark_reg = tx_watermark_reg - 1;
      @(negedge tx_clock);

      for (k = 0; k < 8; k = k + 1) begin
        `ASSERT(txd == tx_data[k]);
        @(negedge tx_clock);
      end

    end
  endtask

  task automatic TxStop1;
    begin

      `ASSERT(txd == 1'b1);

    end
  endtask

  task automatic TxStop2;
    begin
      @(negedge tx_clock);

      `ASSERT(txd == 1'b1);

    end
  endtask

  // Tx's Initial Block
  initial begin
    tx_read_ptr = -3'b001;

    @(init);
    @(negedge tx_clock);
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      if (~tx_empty) begin

        TxStart();

        TxData();

        TxStop1();

        if (Nstop) TxStop2();
      end
      @(negedge tx_clock);
    end
  end


endmodule

// Transmit Data:
//  full --> indica FIFO cheia
//  txwm --> indica FIFO pouco cheia
// Receive Data:
//  empty --> indica FIFO vazia
//  rxwm  --> indica FIFO pouco vazia
