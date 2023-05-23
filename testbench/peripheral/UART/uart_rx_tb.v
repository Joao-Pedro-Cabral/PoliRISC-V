//
//! @file   uart_rx_tb.v
//! @brief  Testbench do Receptor da UART
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-22
//

`timescale 1ns / 100ps

module uart_rx_tb ();

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

  // Estados possíveis
  localparam reg [2:0] Idle = 3'h0, Start = 3'h1, Data = 3'h2,
    Parity = 3'h3, Stop1 = 3'h4, Stop2 = 3'h5;

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
    if (end_of_receive !== 1'b0 || DUT.present_state !== Idle)
      $fatal(
          "Reset Error! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
          data_valid,
          frame_error,
          parity_error,
          DUT.present_state
      );
    else $display("SOT!");

    @(negedge clock);
    for (i = 0; i < amount_of_tests; i = i + 1) begin
      // geração aleatório de entradas
      {rxd, rx_en, parity_type, nstop} = $urandom;
      @(negedge clock);
      // Começo de recepção de novo dado
      if (rx_en && (~rxd)) begin
        data_in = $urandom;
        if (end_of_receive !== 1'b0 || DUT.present_state !== Start)
          $fatal(
              "Error Start! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
              data_valid,
              frame_error,
              parity_error,
              DUT.present_state
          );
        // Recebe 8 bits de dado
        for (j = 0; j < 8; j = j + 1) begin
          rx_en = $urandom;  // verifico se abaixar o rx_en afeta na transmissão
          rxd   = data_in[j];
          @(negedge clock);
          if (end_of_receive !== 1'b0 || DUT.present_state !== Data)
            $fatal(
                "Error Data! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
                data_valid,
                frame_error,
                parity_error,
                DUT.present_state
            );
        end
        // Envio da paridade(se há)
        if (parity_type[1]) begin
          rx_en = $urandom;
          correct_parity = $urandom;
          // uso correct_parity para escolher entre mandar a pariadade correta ou não
          if (correct_parity) rxd = parity;
          else rxd = ~parity;
          @(negedge clock);
          if (end_of_receive !== 1'b0 || DUT.present_state !== Parity)
            $fatal(
                "Error Parity! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
                data_valid,
                frame_error,
                parity_error,
                DUT.present_state
            );
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
          if (end_of_receive !== 1'b0 || DUT.present_state !== Stop1)
            $fatal(
                "Error Stop1! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
                data_valid,
                frame_error,
                parity_error,
                DUT.present_state
            );
          // Stop bit 2
          rx_en = $urandom;
          correct_stop[1] = $urandom;
          // uso correct_stop para escolher entre mandar o stop bit correto ou não
          if (correct_stop[1]) rxd = 1'b1;
          else rxd = 1'b0;
          @(negedge clock);
          if (end_of_receive !== 1'b0 || DUT.present_state !== Stop2)
            $fatal(
                "Error Stop2! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
                data_valid,
                frame_error,
                parity_error,
                DUT.present_state
            );
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
          if (end_of_receive !== 1'b0 || DUT.present_state !== Stop1)
            $fatal(
                "Error Stop1! data_valid = %b, frame_error = %b, parity_error = %b, state = %h",
                data_valid,
                frame_error,
                parity_error,
                DUT.present_state
            );
        end
        rxd = 1'b1;
        rx_en = 1'b0;
        // dado válido, se não houve erros na transmissão
        data_valid_ = (&correct_stop) & correct_parity;
        @(negedge clock);
        if (data_in !== data_out || data_valid !== data_valid_ || parity_error !== ~correct_parity
            || frame_error !== ~(&correct_stop) || DUT.present_state !== Idle)
          $fatal(
              "Error Idle! data_valid = %b, frame_error = %b, parity_error = %b, state = %h, \
              data_in = 0x%h, data_out = 0x%h",
              data_valid,
              frame_error,
              parity_error,
              DUT.present_state,
              data_in,
              data_out
          );
      end else if (data_in !== data_out || data_valid !== data_valid_ ||
                    parity_error !== ~correct_parity || frame_error !== ~(&correct_stop) ||
                    DUT.present_state !== Idle)
        $fatal(
            "Error Idle! data_valid = %b, frame_error = %b, parity_error = %b, state = %h, \
              data_in = 0x%h, data_out = 0x%h",
            data_valid,
            frame_error,
            parity_error,
            DUT.present_state,
            data_in,
            data_out
        );
    end
    $display("EOT!");
    $stop;
  end

endmodule
