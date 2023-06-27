//
//! @file   uart_echo.v
//! @brief  Testa modo echo da UART
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-21
//

module uart_echo_top (
    input wire clock,
    input wire reset,
    // Configuração do Receptor
    input wire rx_en,  // habilita o receptor
    input wire [1:0] parity_type,  // 0/1: Sem, 2: Par, 3: Ímpar
    input wire nstop,  // numero de stop bits
    // Serial
    input wire rxd,  // dado recebido da serial
    // Paralela
    output wire [7:0] hexa,
    output wire txd,
    output wire tx_rdy,
    output wire data_valid,  // 1: dado válido(sem erros)
    output wire frame_error,  // stop bits não respeitado
    output wire parity_error  // erro de paridade
);

  wire clock_9600_16;
  wire clock_9600;
  wire data_valid_;
  wire [9:0] clock_cnt_9600_16;
  wire [13:0] clock_cnt_9600;
  wire [7:0] data_out;
  wire [7:0] hexa_not;

  uart_rx RX (
      .clock(clock_9600_16),
      .reset(reset),
      .rx_en(rx_en),
      .parity_type(parity_type),
      .nstop(nstop),
      .rxd(rxd),
      .data_valid(data_valid_),
      .data_out(data_out),
      .frame_error(frame_error),
      .parity_error(parity_error)
  );

  uart_tx TX (
      .clock(clock_9600),
      .reset(reset),
      .tx_en(rx_en),
      .parity_type(parity_type),
      .nstop(nstop),
      .txd(txd),
      .data_in(data_out),
      .data_valid(data_valid_),
      .tx_rdy(tx_rdy)
  );

  sync_parallel_counter #(
      .size(10),
      .init_value(0)
  ) gen_clk_9600_16 (
      .clock(clock),
      .reset(reset),
      .load(clock_9600_16),
      .load_value(10'b0),
      .inc_enable(1'b1),  // Sempre Ativo
      .dec_enable(1'b0),
      .value(clock_cnt_9600_16)
  );

  sync_parallel_counter #(
      .size(14),
      .init_value(0)
  ) gen_clk_9600 (
      .clock(clock),
      .reset(reset),
      .load(clock_9600),
      .load_value(14'b0),
      .inc_enable(1'b1),  // Sempre Ativo
      .dec_enable(1'b0),
      .value(clock_cnt_9600)
  );

  display hexa_seg (
      .ascii(data_out),
      .hexa (hexa_not[6:0])
  );

  assign clock_9600_16 = (clock_cnt_9600_16 == 53);  // 100MHz/(9600*16) - 1
  assign clock_9600 = (clock_cnt_9600 == 867);  // 100MHz/(9600) - 1
  //   assign hexa = data_out;
  assign hexa = hexa_not;
  assign hexa_not[7] = 1'b1;
  assign data_valid = data_valid_;

endmodule
