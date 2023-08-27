//
//! @file   uart_tb.v
//! @brief  Testbench de uma implementação de UART
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-05-29
//

`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module uart_tb ();

  localparam integer AmntOfTests = 500;
  localparam integer ClockPeriod = 20;
  localparam integer Seed = 133;

  localparam reg Nstop = 1'b1;
  localparam integer TxClockPeriod = 32 * 20;
  localparam integer RxClockPeriod = TxClockPeriod / 16;

  event        init;
  event        initClocks;

  // Sinais do DUT
  reg          clock;
  reg          rx_clock;
  reg          tx_clock;
  reg          reset;
  reg          rd_en;
  reg          wr_en;
  reg   [ 2:0] addr;
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
  // Rx Operation
  reg   [ 7:0] rx_fifo            [7:0];
  reg   [ 2:0] rx_read_ptr;
  reg   [ 2:0] rx_write_ptr;
  wire         rx_empty;
  reg          rx_empty_;
  wire         rx_full;
  //
  // Tx Operation
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
  // Sinais dos initial blocks
  reg   [ 1:0] processor_initial;
  reg   [ 2:0] rx_initial;
  reg   [ 1:0] tx_initial;

  // DUT
  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
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

  // Sinais da FIFO/interrupts
  assign txwm = (tx_watermark_reg < tx_watermark_level);
  assign rxwm = (rx_watermark_reg > rx_watermark_level);

  assign rx_full = (rx_watermark_reg == 3'b111);
  assign rx_empty = (rx_watermark_reg == 3'b000);

  assign tx_full = (tx_watermark_reg == 3'b111);
  assign tx_empty = (tx_watermark_reg == 3'b000);

  // Geração de clocks
  // Clock Principal
  always #(ClockPeriod / 2) clock = ~clock;

  // RX Clock (Tick)
  initial begin
    rx_clock = 0;
    @(initClocks);
    @(posedge DUT.rx_clock);  // Sincronizando
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
    @(posedge DUT.tx_clock);  // Sincronizando
    forever begin
      tx_clock = 1;
      #(TxClockPeriod / 32);
      tx_clock = 0;
      #(31 * TxClockPeriod / 32);
    end
  end

  // Simular Escrita na RX FIFO:
  // Após detectar um novo dado válido
  // Espere a FIFO ter espaço
  // Então, no ciclo seguinte escreva
  always @(posedge DUT.rx_data_valid) begin
    @(negedge clock);
    wait (rx_full == 1'b0);
    @(posedge clock);
    @(posedge clock);
    rx_fifo[rx_write_ptr] = rx_data;
    rx_write_ptr = rx_write_ptr + 1'b1;
    rx_watermark_reg = rx_watermark_reg + 1'b1;
  end

  // Simular Leitura no RX FIFO:
  // Caso haja uma leitura no endereço do rxdata
  // Após 1.5 ciclo, leio da FIFO
  always @(posedge rd_en) begin
    if (addr == 3'b001) begin
      @(posedge clock);
      @(posedge clock);
      if (!rx_empty) begin
        rx_read_ptr = rx_read_ptr + 1'b1;
        rx_watermark_reg = rx_watermark_reg - 1'b1;
      end
    end
  end

  // Simular Leitura na TX FIFO:
  // Após detectar um que o Transmissor está pronto
  // Espere a FIFO ter dado
  // Então, no ciclo seguinte lê
  always @(posedge DUT.tx_rdy) begin
    @(negedge clock);
    wait (tx_empty == 1'b0);
    @(posedge clock);
    @(posedge clock);
    tx_read_ptr = tx_read_ptr + 1;
    tx_data = tx_fifo[tx_read_ptr];
    tx_watermark_reg = tx_watermark_reg - 1;
  end

  // Simular Escrita na TX FIFO:
  // Caso haja uma escrita no endereço do txdata
  // Após 2.5 ciclos, escrevo na FIFO
  always @(posedge wr_en) begin
    if (addr == 3'b000) begin
      @(posedge clock);
      @(posedge clock);
      @(posedge clock);
      if (~tx_full) begin
        tx_fifo[tx_write_ptr] = wr_data[7:0];
        tx_write_ptr = tx_write_ptr + 1;
        tx_watermark_reg = tx_watermark_reg + 1'b1;
      end
    end
  end

  // Tasks para checar a interação UART <-> Processador
  task automatic InterruptCheck;
    begin
      processor_initial = 2'b00;
      // Ler Interrupt Pending Register
      addr = 3'b101;
      @(posedge busy);
      @(negedge clock);
      {rd_en, wr_en, addr} = 5'b00100;
      @(negedge busy);
      @(negedge clock);

      `ASSERT(rd_data[0] === txwm);

      `ASSERT(rd_data[1] === rxwm);
    end
  endtask

  task automatic ReadOp;
    begin
      processor_initial = 2'b01;
      // Operação de leitura:
      //  checa por empty antes
      //  Lê (aleatório)
      addr = 3'b001;
      @(posedge busy);
      @(negedge clock);
      {rd_en, wr_en, addr} = 5'b00011;
      @(posedge clock);
      rx_empty_ = (rx_watermark_reg == 3'b000);
      @(negedge busy);
      @(negedge clock);

      `ASSERT(rx_empty_ === rd_data[31]);
      `ASSERT(rx_fifo[rx_read_ptr] === rd_data[7:0]);
      `ASSERT(rx_read_ptr === DUT.rx_fifo.rd_reg);
      `ASSERT(rx_watermark_reg === DUT.rx_fifo.watermark_reg);

    end
  endtask

  task automatic WriteOp;
    begin
      processor_initial = 2'b10;
      // Operação de escrita:
      //  checa por full antes
      //  escreve (aleatório)
      addr = 3'b000;
      @(posedge busy);
      @(negedge clock);
      {rd_en, wr_en, addr} = 5'b00111;
      @(negedge busy);
      @(negedge clock);

      `ASSERT(tx_full === rd_data[31]);
      `ASSERT(tx_write_ptr === DUT.tx_fifo.wr_reg);
      `ASSERT(tx_watermark_reg === DUT.tx_fifo.watermark_reg);
      `ASSERT(tx_fifo[tx_write_ptr-1] === DUT.tx_fifo.fifo_memory[DUT.tx_fifo.wr_reg-1]);
    end
  endtask

  integer i1, i2, i3;

  // Processor's Initial Block
  initial begin
    // Inicializando
    {clock, reset, rd_en, wr_en, addr, wr_data, tx_watermark_level,
    tx_watermark_reg, rx_watermark_level, rx_watermark_reg, tx_write_ptr} = 0;
    rx_read_ptr = 3'b111;

    // Reset
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset              = 1'b0;

    // Configurando Receive Control Register
    wr_en              = 1'b1;
    addr               = 3'b011;
    wr_data[18:16]     = $urandom(Seed);
    rx_watermark_level = wr_data[18:16];
    wr_data[0]         = 1'b1;
    @(negedge busy);

    // Configurando Transmit Control Register
    addr               = 3'b010;
    wr_data[18:16]     = $urandom;
    tx_watermark_level = wr_data[18:16];
    wr_data[1:0]       = {Nstop, 1'b1};
    @(negedge busy);

    // Configurando Interrupt Enable Register
    addr    = 3'b100;
    wr_data[1:0] = 2'b11;
    @(negedge busy);

    // Configurando baud rate
    addr          = 3'b110;
    wr_data[15:0] = $urandom;
    @(negedge busy);

    // Configurando baud rate
    addr          = 3'b110;
    wr_data[15:0] = 16'h001F;
    @(negedge busy);

    ->initClocks;  // iniciar tx(rx) clock

    @(negedge tx_clock);  // sincronizar as seriais
    ->init;

    $display("[%0t] SOT", $time);

    @(negedge clock);
    for (i1 = 0; i1 < 25 * AmntOfTests; i1 = i1 + 1) begin
      rd_en   = 1'b1;
      wr_en   = 1'b0;
      wr_data = $urandom;

      InterruptCheck();

      wr_en = $urandom;
      rd_en = ~wr_en;

      if (rd_en) ReadOp();
      else WriteOp();
      // Atraso a execução do loop
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
      @(posedge rx_clock);
    end
    $display("[%0t] EOT processor", $time);
  end

  // Tasks para checar a interação UART <-> Serial RX
  task automatic RxStart;
    begin
      rx_initial = 3'b000;

      rxd = 0;
      @(negedge tx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Start);

    end
  endtask

  task automatic RxData;
    integer j;
    begin
      rx_initial = 3'b001;

      for (j = 0; j < 8; j = j + 1) begin
        rxd = rx_data[j];
        @(negedge tx_clock);
        `ASSERT(DUT.rx.present_state === DUT.rx.Data);
      end
    end
  endtask

  task automatic RxStop1;
    begin
      rx_initial = 3'b010;

      rxd = 1'b1;
      @(negedge tx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Stop1);

    end
  endtask

  task automatic RxStop2;
    begin
      rx_initial = 3'b011;
      rxd = 1'b1;
      @(negedge tx_clock);

      `ASSERT(DUT.rx.present_state === DUT.rx.Stop2);

    end
  endtask

  task automatic EndRx;
    begin
      rx_initial = 3'b100;
      @(negedge tx_clock);

      `ASSERT(rx_fifo[rx_write_ptr-1'b1] === DUT.rx_fifo.fifo_memory[DUT.rx_fifo.wr_reg-1'b1]);
      `ASSERT(rx_write_ptr === DUT.rx_fifo.wr_reg);
      `ASSERT(rx_watermark_reg === DUT.rx_fifo.watermark_reg);
    end
  endtask

  // Rx's Initial Block
  initial begin
    rxd = 1'b1;
    rx_write_ptr = 3'b000;


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
        rx_initial = 3'b101;
        @(negedge tx_clock);
      end
    end
    $display("[%0t] EOT RX", $time);
    $stop;
  end

  // Tasks para checar a interação UART <-> Serial TX
  task automatic TxStart;
    begin
      tx_initial = 2'b0;
      @(negedge tx_clock);

      `ASSERT(txd === 1'b0);

    end
  endtask

  task automatic TxData;
    integer k;
    begin
      tx_initial = 2'b01;
      @(negedge tx_clock);

      for (k = 0; k < 8; k = k + 1) begin
        `ASSERT(txd === tx_data[k]);
        @(negedge tx_clock);
      end

    end
  endtask

  task automatic TxStop1;
    begin
      tx_initial = 2'b10;

      @(negedge tx_clock);
      `ASSERT(txd === 1'b1);

    end
  endtask

  task automatic TxStop2;
    begin
      tx_initial = 2'b11;
      @(negedge tx_clock);

      `ASSERT(txd === 1'b1);

    end
  endtask

  // Tx's Initial Block
  initial begin
    tx_read_ptr = -3'b001;

    @(init);
    for (i3 = 0; i3 < AmntOfTests; i3 = i3 + 1) begin
      if (~tx_empty) begin

        TxStart();

        TxData();

        TxStop1();

        if (Nstop) TxStop2();
      end
      @(negedge clock);
    end
    $display("[%0t] EOT TX", $time);
  end

endmodule
