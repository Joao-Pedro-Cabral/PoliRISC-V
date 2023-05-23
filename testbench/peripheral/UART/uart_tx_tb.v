//
//! @file   uart_tx_tb.v
//! @brief  Testbench do Transmissor da UART
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-22
//

`timescale 1ns / 100ps

module uart_tx_tb ();

  // sinais do DUT
  reg clock;
  reg reset;
  reg tx_en;
  reg [1:0] parity_type;
  reg nstop;
  wire txd;
  reg [7:0] data_in;
  reg data_valid;
  wire tx_rdy;

  // Sinais auxiliares
  wire parity;
  integer amount_of_tests = 1000;
  integer i, j;

  // Estados possíveis
  localparam reg [2:0] Idle = 3'h0, Start = 3'h1, Data = 3'h2,
    Parity = 3'h3, Stop1 = 3'h4, Stop2 = 3'h5;

  // DUT
  uart_tx DUT (
      .clock(clock),
      .reset(reset),
      .tx_en(tx_en),
      .parity_type(parity_type),
      .nstop(nstop),
      .txd(txd),
      .data_in(data_in),
      .data_valid(data_valid),
      .tx_rdy(tx_rdy)
  );

  always #6 clock = ~clock;  // geração do clock

  // Atribuições auxiliares
  assign parity = (^data_in) ^ parity_type[0];

  // testa o DUT
  initial begin

    // inicializando as entradas
    {clock, reset, tx_en, parity_type, nstop, data_in, data_valid} = 0;
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    if (txd !== 1'b1 || tx_rdy !== 1'b1 || DUT.present_state !== Idle)
      $fatal("Reset Error! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
    else $display("SOT!");

    @(negedge clock);
    for (i = 0; i < amount_of_tests; i = i + 1) begin
      // geração aleatório de entradas
      {tx_en, parity_type, nstop, data_in, data_valid} = $urandom;
      @(negedge clock);
      // Começo de envio de novo dado
      if (tx_en && data_valid) begin
        data_valid = 1'b0;  // data_valid normalmente só fica 1 ciclo em alto
        if (txd !== 1'b0 || tx_rdy !== 1'b0 || DUT.present_state !== Start)
          $fatal("Erro Start! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
        @(negedge clock);
        // Envio dos 8 bits de dado
        for (j = 0; j < 8; j = j + 1) begin
          tx_en = $urandom;  // verifico se abaixar o tx_en afeta na transmissão
          if (txd !== data_in[j] || tx_rdy !== 1'b0 || DUT.present_state !== Data)
            $fatal("Erro Data! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
          @(negedge clock);
        end
        tx_en = $urandom;
        // Envio da paridade(se há)
        if (parity_type[1]) begin
          if (txd !== parity || tx_rdy !== 1'b0 || DUT.present_state !== Parity)
            $fatal(
                "Erro Parity! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state
            );
          @(negedge clock);
        end
        // Stop bit 1
        if (txd !== 1'b1 || tx_rdy !== 1'b0 || DUT.present_state !== Stop1)
          $fatal("Erro Stop1! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
        @(negedge clock);
        if (nstop) begin
          // Stop bit 2
          if (txd !== 1'b1 || tx_rdy !== 1'b0 || DUT.present_state !== Stop2)
            $fatal("Erro Stop2! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
          @(negedge clock);
        end
      end else if (txd !== 1'b1 || tx_rdy !== 1'b1 || DUT.present_state !== Idle)
        $fatal("Erro Idle! txd = %b, tx_rdy = %b, state = %h", txd, tx_rdy, DUT.present_state);
    end
    $display("EOT!");
    $stop;
  end

endmodule
