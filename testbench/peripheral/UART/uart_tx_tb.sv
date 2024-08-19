
module uart_tx_tb ();

  import macros_pkg::*;
  import uart_phy_pkg::*;

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
    CHK_INIT: assert(txd && tx_rdy && DUT.present_state === Idle) $display("SOT!");

    @(negedge clock);
    for (i = 0; i < amount_of_tests; i = i + 1) begin
      // geração aleatório de entradas
      {tx_en, parity_type, nstop, data_in, data_valid} = $urandom;
      @(negedge clock);
      // Começo de envio de novo dado
      if (tx_en && data_valid) begin
        data_valid = 1'b0;  // data_valid normalmente só fica 1 ciclo em alto
        CHK_START_TXD: assert(txd === 1'b0);
        CHK_START_TX_RDY: assert(tx_rdy === 1'b0);
        CHK_START_STATE: assert(DUT.present_state === Start);
        @(negedge clock);
        // Envio dos 8 bits de dado
        for (j = 0; j < 8; j = j + 1) begin
          tx_en = $urandom;  // verifico se abaixar o tx_en afeta na transmissão
          CHK_DATA_TXD: assert(txd === data_in[j]);
          CHK_DATA_TX_RDY: assert(tx_rdy === 1'b0);
          CHK_DATA_STATE: assert(DUT.present_state === Data);
          @(negedge clock);
        end
        tx_en = $urandom;
        // Envio da paridade(se há)
        if (parity_type[1]) begin
          CHK_PARITY_TXD: assert(txd === parity);
          CHK_PARITY_TX_RDY: assert(tx_rdy === 1'b0);
          CHK_PARITY_STATE: assert(DUT.present_state === Parity);
          @(negedge clock);
        end
        // Stop bit 1
          CHK_STOP1_TXD: assert(txd === 1'b1);
          CHK_STOP1_TX_RDY: assert(tx_rdy === 1'b0);
          CHK_STOP1_STATE: assert(DUT.present_state === Stop1);
        @(negedge clock);
        if (nstop) begin
          // Stop bit 2
          CHK_STOP2_TXD: assert(txd === 1'b1);
          CHK_STOP2_TX_RDY: assert(tx_rdy === 1'b0);
          CHK_STOP2_STATE: assert(DUT.present_state === Stop2);
          @(negedge clock);
        end
      end else begin
          CHK_IDLE_TXD: assert(txd === 1'b1);
          CHK_IDLE_TX_RDY: assert(tx_rdy === 1'b1);
          CHK_IDLE_STATE: assert(DUT.present_state === Idle);
      end
    end
    $display("EOT!");
    $stop;
  end

endmodule
