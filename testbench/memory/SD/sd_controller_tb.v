
`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module sd_controller_tb ();

  // Parâmetros do testbench
  localparam integer AmntOfTests = 10;
  localparam integer Clock400KPeriod = 10;
  localparam integer Clock50MPeriod = 4;
  localparam integer Seed = 103;
  localparam integer SDSC = 1;

  // Sinais do DUT
  reg clock_400K;
  reg clock_50M;
  reg reset;
  reg wr_en;
  reg rd_en;
  reg [31:0] addr;
  wire [4095:0] read_data;
  reg [4095:0] write_data;
  wire miso;
  wire cs;
  wire sck;
  wire mosi;
  wire busy;
  // Sinais do modelo do cartão
  wire cmd_error;
  // Sinais auxiliares
  reg generate_write_data;

  integer i;


  sd_controller #(
      .SDSC(SDSC)
  ) DUT (
      .clock_400K(clock_400K),
      .clock_50M(clock_50M),
      .reset(reset),
      .wr_en(wr_en),
      .rd_en(rd_en),
      .addr(addr),
      .write_data(write_data),
      .read_data(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .busy(busy)
  );

  sd_model #(
      .SDSC(SDSC)
  ) sd_card (
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .miso(miso),
      .expected_addr(addr),
      .cmd_error(cmd_error)
  );

  always #(Clock400KPeriod / 2) clock_400K = ~clock_400K;
  always #(Clock50MPeriod / 2) clock_50M = ~clock_50M;

  task CheckInitialization;
    begin
      // Inicialização do cartão SD
      // Checo no clock mais rápido para não perder a mudança de estado do DUT
      // Pois quando ele muda para Idle, o clock muda
      while (DUT.state != DUT.Idle) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock_50M);
        // Checar se não há erro de CRC7
        `ASSERT(cmd_error === 1'b0);
        @(negedge clock_50M);
      end
    end
  endtask

  task CheckRead;
    begin
      if (!busy) @(posedge busy);
      @(negedge clock_50M);
      while (busy == 1'b1) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock_50M);
        // Checar se não há erro
        `ASSERT(cmd_error === 1'b0);
        // Confiro busy na borda de descida
        @(negedge clock_50M);
        // Enables não são mais relevantes
        rd_en = $urandom;
        wr_en = $urandom;
      end
      rd_en = 1'b0;
      wr_en = 1'b0;
      // Após leitura checa o dado lido e se houve algum erro
      `ASSERT(cmd_error === 1'b0);
      if (!sd_card.random_error_flag) `ASSERT(read_data === sd_card.data_block);
      $display(" Leu: [%0t]", $time);
    end
  endtask

  event   write_data_event;
  integer j;
  always @(write_data_event) begin
    for (j = 0; j < 128; j = j + 1) begin
      write_data[32*j+:32] <= $urandom;
    end
  end

  task CheckWrite;
    begin
      if (!busy) @(posedge busy);
      @(negedge clock_50M);
      while (busy == 1'b1) begin
        @(posedge clock_50M);
        // Checar se não há erro
        `ASSERT(cmd_error === 1'b0);
        // Confiro busy na borda de descida
        @(negedge clock_50M);
        // Enables não são mais relevantes
        rd_en = $urandom;
        wr_en = $urandom;
      end
      rd_en = 1'b0;
      wr_en = 1'b0;
      // Após leitura checa o dado lido e se houve algum erro
      `ASSERT(cmd_error === 1'b0);
      if (!sd_card.random_error_flag) `ASSERT(write_data === sd_card.received_data_block);
      $display(" Escreveu: [%0t]", $time);
    end
  endtask

  // Initial para estimular o DUT
  initial begin
    {clock_400K, clock_50M, reset, rd_en, addr, generate_write_data} = 0;
    // Reset inicial
    @(negedge clock_400K);
    reset = 1'b1;
    @(negedge clock_400K);
    reset = 1'b0;
    rd_en = $urandom(Seed);
    wr_en = ~rd_en;
    addr  = $urandom;
    ->write_data_event;
    @(negedge clock_400K);

    $display(" SOT: [%0t]", $time);

    CheckInitialization;  // Confere Inicialização do cartão

    $display(" Initialization Complete: [%0t]", $time);

    @(negedge clock_50M);

    // Realizar leituras
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      if (rd_en) begin
        CheckRead;  // Confere a leitura
      end else begin
        CheckWrite;  // Confere a escrita
      end

      rd_en = $urandom;
      wr_en = ~rd_en;
      addr  = $urandom;
      if (wr_en) begin
        ->write_data_event;
      end

      @(negedge clock_50M);
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
