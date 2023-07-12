
`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module sd_controller_tb ();

  localparam integer AmntOfTests = 1;
  localparam integer Clock400KPeriod = 10;
  localparam integer Clock50MPeriod = 4;
  localparam integer Seed = 72;

  reg clock_400K;
  reg clock_50M;
  reg reset;
  reg rd_en;
  reg [31:0] addr;
  wire [4095:0] read_data;
  wire miso;
  wire cs;
  wire sck;
  wire mosi;
  wire busy;
  wire cmd_error;

  integer i;

  sd_controller DUT (
      .clock_400K(clock_400K),
      .clock_50M(clock_50M),
      .reset(reset),
      .rd_en(rd_en),
      .addr(addr),
      .read_data(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .busy(busy)
  );

  sd_model sd_card (
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
      while (busy == 1'b1) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock_400K);
        // Checar se não há erro de CRC7
        `ASSERT(cmd_error === 1'b0);
        // Confiro busy na borda de descida
        @(negedge clock_400K);
      end
    end
  endtask

  task CheckRead;
    begin
      // Enquanto estiver lendo
      while (busy == 1'b1) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock_50M);
        // Checar se não há erro de CRC7
        `ASSERT(cmd_error === 1'b0);
        // Confiro busy na borda de descida
        @(negedge clock_50M);
      end
      // Após leitura checa o dado lido e se houve algum erro
      `ASSERT(cmd_error === 1'b0);
      `ASSERT(read_data === sd_card.data_block);
    end
  endtask

  // Initial para estimular o DUT
  initial begin
    {clock_400K, clock_50M, reset, rd_en, addr} = 0;
    // Reset inicial
    @(negedge clock_400K);
    reset = 1'b1;
    @(negedge clock_400K);
    reset = 1'b0;
    rd_en = 1'b1;  // Forçar busy a levantar
    @(negedge clock_400K);

    $display(" SOT: [%0t]", $time);

    CheckInitialization;  // Confere Inicialização do cartão

    @(negedge clock_50M);

    rd_en = $urandom(Seed);  // Inicializando gerador aleatório

    // Realizar leituras
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      rd_en = $urandom;
      addr  = $urandom;

      if (rd_en) CheckRead;  // Confere leitura

      @(negedge clock_50M);
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
