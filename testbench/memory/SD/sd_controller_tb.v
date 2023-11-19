
`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module sd_controller_tb ();

  // Parâmetros do testbench
  localparam integer AmntOfTests = 40;
  localparam integer Clock50MPeriod = 6;
  localparam integer Seed = 103;
  localparam integer SDSC = 1;

  // Sinais do DUT
  reg clock;
  reg reset;
  reg cyc, stb, wr;
  reg [31:0] addr;
  wire [4095:0] read_data;
  reg [4095:0] write_data;
  wire miso;
  wire cs;
  wire sck;
  wire mosi;
  wire ack;
  // Sinais do modelo do cartão
  wire cmd_error;
  // Sinais auxiliares
  reg generate_write_data;
  reg [1:0] teste;  // 00: Reset, 01: Init, 10: Read, 11: Write

  integer i;

  sd_controller #(
      .SDSC(SDSC)
  ) DUT (
      .CLK_I(clock),
      .RST_I(reset),
      .CYC_I(cyc),
      .STB_I(stb),
      .WR_I(wr),
      .ADR_I(addr),
      .DAT_I(write_data),
      .DAT_O(read_data),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .ACK_O(ack)
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

  always #(Clock50MPeriod / 2) clock = ~clock;

  task automatic CheckInitialization;
    begin
      teste = 2'b01;
      // Inicialização do cartão SD
      while (DUT.state != DUT.Idle) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock);
        // Checar se não há erro de CRC7
        `ASSERT(cmd_error === 1'b0);
        @(negedge clock);
      end
    end
  endtask

  task automatic CheckRead;
    begin
      teste = 2'b10;
      while (!ack) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock);
        // Checar se não há erro
        `ASSERT(cmd_error === 1'b0);
        // Confiro ack na borda de descida
        @(negedge clock);
        // Enables não são mais relevantes
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end
      cyc = 1'b0;
      stb = 1'b0;
      wr  = 1'b0;
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

  task automatic CheckWrite;
    begin
      teste = 2'b11;
      while (!ack) begin
        @(posedge clock);
        // Checar se não há erro
        `ASSERT(cmd_error === 1'b0);
        // Confiro ack na borda de descida
        @(negedge clock);
        // Enables não são mais relevantes
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end
      cyc = 1'b0;
      stb = 1'b0;
      wr  = 1'b0;
      // Após leitura checa o dado lido e se houve algum erro
      `ASSERT(cmd_error === 1'b0);
      if (!sd_card.random_error_flag) `ASSERT(write_data === sd_card.received_data_block);
      $display(" Escreveu: [%0t]", $time);
    end
  endtask

  // Initial para estimular o DUT
  initial begin
    {clock, reset, cyc, stb, wr, addr, generate_write_data, teste} = 0;
    // Reset inicial
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    cyc = $urandom(Seed);
    stb = $urandom;
    wr = $urandom;
    addr = $urandom;
    ->write_data_event;
    @(negedge clock);

    $display(" SOT: [%0t]", $time);

    CheckInitialization;  // Confere Inicialização do cartão

    $display(" Initialization Complete: [%0t]", $time);

    @(negedge clock);

    // Realizar leituras
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      if (cyc && stb && !wr) begin
        CheckRead;  // Confere a leitura
      end else if (cyc && stb && wr) begin
        CheckWrite;  // Confere a escrita
      end

      cyc  = $urandom;
      stb  = $urandom;
      wr   = $urandom;
      addr = $urandom;
      if (cyc && stb && wr) begin
        ->write_data_event;
      end
      teste = 2'b00;
      wait (DUT.state == DUT.Idle);  // Wait handshake between controller and sd card
      @(negedge clock);
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
