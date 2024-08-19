
module uart_rx_tb ();

  import macros_pkg::*;
  import uart_phy_pkg::*;

  // sinais do DUT
  reg clock, clock_r;
  reg reset;
  reg rx_en;
  reg [1:0] parity_type;
  reg nstop;
  reg rxd;
  wire [7:0] data_out;
  wire data_valid;
  wire frame_error;
  wire parity_error;

  // Sinais auxiliares
  reg [7:0] data_in;
  wire parity;
  reg correct_parity;  // 1: enviar paridade correta
  reg [1:0] correct_stop;  // 1: enviar respectivo stop bit corretamente
  reg data_valid_;
  wire end_of_receive;  // Indicação do RX que a recepção acabou
  integer amount_of_tests = 1000;
  integer i, j;

  // DUT
  uart_rx DUT (
      .clock(clock_r),
      .reset(reset),
      .rx_en(rx_en),
      .parity_type(parity_type),
      .nstop(nstop),
      .rxd(rxd),
      .data_out(data_out),
      .data_valid(data_valid),
      .parity_error(parity_error),
      .frame_error(frame_error)
  );

  always #16 clock = ~clock;  // geração do clock da transmissão
  always #1 clock_r = ~clock_r;  // geração do clock do RX

  // Atribuições auxiliares
  assign parity = (^data_in) ^ parity_type[0];
  // Sempre que uma recepção acaba, um desses sinais levanta
  assign end_of_receive = data_valid | frame_error | parity_error;

  // testa o DUT
  initial begin

    // inicializando as entradas
    {clock, clock_r, reset, rx_en, parity_type, nstop, data_in} = 0;
    correct_parity = 1'b1;
    correct_stop = 2'b11;
    data_valid_ = 1'b0;
    rxd = 1'b1;
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    CHK_INIT: assert(end_of_receive === 1'b0 || DUT.present_state === Idle) $display("SOT!");

    @(negedge clock);
    for (i = 0; i < amount_of_tests; i = i + 1) begin
      // geração aleatório de entradas
      {rxd, rx_en, parity_type, nstop} = $urandom;
      @(negedge clock);
      // Começo de recepção de novo dado
      if (rx_en && (~rxd)) begin
        data_in = $urandom;
        CHK_END_RECEIVE_START: assert(end_of_receive === 1'b0);
        CHK_STATE_START: assert(DUT.present_state === Start);
        // Recebe 8 bits de dado
        for (j = 0; j < 8; j = j + 1) begin
          rx_en = $urandom;  // verifico se abaixar o rx_en afeta na transmissão
          rxd   = data_in[j];
          @(negedge clock);
          CHK_END_RECEIVE_DATA: assert(end_of_receive === 1'b0);
          CHK_STATE_DATA: assert(DUT.present_state === Data);
        end
        // Envio da paridade(se há)
        if (parity_type[1]) begin
          rx_en = $urandom;
          correct_parity = $urandom;
          // uso correct_parity para escolher entre mandar a pariadade correta ou não
          if (correct_parity) rxd = parity;
          else rxd = ~parity;
          @(negedge clock);
          CHK_END_RECEIVE_PARITY: assert(end_of_receive === 1'b0);
          CHK_STATE_PARITY: assert(DUT.present_state === Parity);
        end else correct_parity = 1'b1;
        // 2 Stop bits
        if (nstop) begin
          // Stop bit 1
          rx_en = $urandom;
          correct_stop[0] = $urandom;
          // uso correct_stop para escolher entre mandar o stop bit correto ou não
          if (correct_stop[0]) rxd = 1'b1;
          else rxd = 1'b0;
          @(negedge clock);
          CHK_END_RECEIVE_STOP1: assert(end_of_receive === 1'b0);
          CHK_STATE_STOP1: assert(DUT.present_state === Stop1);
          // Stop bit 2
          rx_en = $urandom;
          correct_stop[1] = $urandom;
          // uso correct_stop para escolher entre mandar o stop bit correto ou não
          if (correct_stop[1]) rxd = 1'b1;
          else rxd = 1'b0;
          @(negedge clock);
          CHK_END_RECEIVE_STOP2: assert(end_of_receive === 1'b0);
          CHK_STATE_STOP2: assert(DUT.present_state === Stop2);
          // 1 stop bit
        end else begin
          // Stop bit 1
          rx_en = $urandom;
          correct_stop[0] = $urandom;
          correct_stop[1] = 1'b1;
          // uso correct_stop para escolher entre mandar o stop bit correto ou não
          if (correct_stop[0]) rxd = 1'b1;
          else rxd = 1'b0;
          @(negedge clock);
          CHK_END_RECEIVE_STOP1_2: assert(end_of_receive === 1'b0);
          CHK_STATE_STOP1_2: assert(DUT.present_state === Stop1);
        end
        rxd = 1'b1;
        rx_en = 1'b0;
        // dado válido, se não houve erros na transmissão
        data_valid_ = (&correct_stop) & correct_parity;
        @(negedge clock);
        CHK_DATA_OUT_END: assert(data_in === data_out);
        CHK_DATA_VALID_END: assert(data_valid === data_valid_);
        CHK_PARITY_ERRORR_END: assert(parity_error === ~correct_parity);
        CHK_FRAME_ERROR_END: assert(frame_error === ~(&correct_stop));
        CHK_STATE_IDLE_END: assert(DUT.present_state === Idle);
      end else begin
        CHK_DATA_OUT_IDLE: assert(data_in === data_out);
        CHK_DATA_VALID_IDLE: assert(data_valid === data_valid_);
        CHK_PARITY_ERRORR_IDLE: assert(parity_error === ~correct_parity);
        CHK_FRAME_ERROR_IDLE: assert(frame_error === ~(&correct_stop));
        CHK_STATE_IDLE_IDLE: assert(DUT.present_state === Idle);
      end
    end
    $display("EOT!");
    $stop;
  end

endmodule
