//
//! @file   uart_tx.v
//! @brief  Transmissor da UART
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

module uart_tx (
    input wire clock,
    input wire reset,
    // Configuração do Transmissor
    input wire tx_en,  // habilita o transmissor
    input wire [1:0] parity_type,  // 0/1: Sem, 2: Par, 3: Ímpar
    input wire nstop,  // numero de stop bits
    // Serial
    output reg txd,  // dado enviado na serial
    // Paralela
    input wire [7:0] data_in,
    input wire data_valid,  // 1: data_in é válido
    output reg tx_rdy  // 1: tx está pronto para receber um dado
);

  reg [2:0] present_state, next_state;  // Estado da transmissão

  // Estados possíveis
  localparam reg [2:0] Idle = 3'h0, Start = 3'h1, Data = 3'h2,
    Parity = 3'h3, Stop1 = 3'h4, Stop2 = 3'h5;

  // Registrador Paralelo-Serial
  wire [7:0] mux_data;  // data_reg << 1 ou data_in
  wire [7:0] data_reg;
  reg data_en;  // 1: Shiftar o data_reg

  // Calculo da Paridade
  wire tx_parity;  // paridade do dado transmitido
  reg parity_en;  // habilita cálculo da paridade

  // Sinais do contador do estado Data
  reg data_cnt_rst;
  wire [2:0] data_cnt;

  // Tx Reg
  register_d #(
      .N(8),
      .reset_value(0)
  ) tx_reg (
      .clock(clock),
      .reset(1'b0),
      .enable(data_en | (tx_en & data_valid)),
      .D(mux_data),
      .Q(data_reg)
  );
  // data_en tem prioridade sobre data_valid, pois quando uma transmissão começa ela não deve ser interrompida
  assign mux_data = data_en ? {1'b0, data_reg[7:1]} : data_in;

  // Cálculo da Paridade
  register_d #(
      .N(1),
      .reset_value(0)
  ) parity_reg (
      .clock(clock),
      .reset(1'b0),
      .enable(parity_en),
      .D((^data_reg) ^ parity_type[0]),
      .Q(tx_parity)
  );


  // Contador de 8 Ciclos para o estado Data
  sync_parallel_counter #(
      .size(3),
      .init_value(0)
  ) data_counter (
      .clock(clock),
      .reset(data_cnt_rst),
      .load(1'b0),
      .load_value(3'b0),
      .inc_enable(data_en),
      .dec_enable(1'b0),
      .value(data_cnt)
  );

  // Transição de Estado
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Saída e de Próximo Estado da FSM
  always @(*) begin
    txd = 1'b1;
    tx_rdy = 1'b0;
    data_en = 1'b0;
    parity_en = 1'b0;
    data_cnt_rst = 1'b0;
    case (present_state)
      Idle: begin
        tx_rdy = 1'b1;  // Transmissor pronto para receber
        if (tx_en && data_valid) next_state = Start;
        else next_state = Idle;
      end
      Start: begin
        txd = 1'b0;
        parity_en = 1'b1;  // data_reg válido
        data_cnt_rst = 1'b1;  // reseta contador do Data
        next_state = Data;
      end
      Data: begin
        txd = data_reg[0];  // envio começando pelo LSb
        data_en = 1'b1;
        if (&data_cnt) begin
          if (parity_type[1]) next_state = Parity;  // Paridade está sendo transmitida
          else next_state = Stop1;  // Sem paridade
        end else next_state = Data;
      end
      Parity: begin
        txd = tx_parity;
        next_state = Stop1;
      end
      Stop1: begin
        txd = 1'b1;  // 1º Stop bit
        if (nstop) next_state = Stop2;  // 2 stop bits
        else next_state = Idle;
      end
      Stop2: begin
        txd = 1'b1;  // 2º Stop bit
        next_state = Idle;
      end
      default: begin
        next_state = Idle;
      end
    endcase
  end
endmodule
