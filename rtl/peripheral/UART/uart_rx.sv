
module uart_rx (
    input wire clock,
    input wire reset,
    // Configuração do Receptor
    input wire rx_en,  // habilita o receptor
    input wire [1:0] parity_type,  // 0/1: Sem, 2: Par, 3: Ímpar
    input wire nstop,  // numero de stop bits
    // Serial
    input wire rxd,  // dado recebido da serial
    // Paralela
    output wire [7:0] data_out,
    output wire data_valid,  // 1: dado válido(sem erros)
    output wire frame_error,  // stop bits não respeitado
    output wire parity_error  // erro de paridade
);

  reg [2:0] present_state, next_state;  // Estado da transmissão

  // Estados possíveis
  localparam reg [2:0] Idle = 3'h0, Start = 3'h1, Data = 3'h2,
                       Parity = 3'h3, Stop1 = 3'h4, Stop2 = 3'h5;

  // Registrador de amostragem(3 amostragens por bit)
  wire [2:0] sampled_reg;
  wire sampled_bit;

  // Contador da Amostragem
  reg sample_cnt_rst;
  wire [3:0] sample_cnt;
  wire sample_end = &sample_cnt;  // fim da contagem de 16 ciclos

  // Contador de dados amostrados
  reg data_cnt_rst;
  wire [2:0] data_cnt;

  // Registrador Serial-Paralelo
  wire [7:0] data_reg;
  reg data_en;  // habilita a escrita no registrador

  // Sinais para checagem da paridade
  reg check_parity;
  wire parity_er;

  // Sinais para checagem do framing
  reg check_framing;
  wire framing_er;

  wire data_vld;  // Dado Válido

  // fim da transmissão
  reg transmit_end_en;
  wire transmit_end;

  // Amostragem por voto da maioria
  // Decide qual o dado recebido
  assign sampled_bit =  (sampled_reg[0] & sampled_reg[1]) |
                        (sampled_reg[0] & sampled_reg[2]) |
                        (sampled_reg[1] & sampled_reg[2]);
  // Gerar os registradores dos dados amostrados
  genvar i;
  generate
    for (i = 0; i < 3; i = i + 1) begin : g_sample_block
      register_d #(
          .N(1),
          .reset_value(0)
      ) sample_reg_0 (
          .clock(clock),
          .reset(1'b0),
          .enable((sample_cnt == (7 + i))),
          .D(rxd),
          .Q(sampled_reg[i])
      );
    end
  endgenerate

  // Contador de 16 Ciclos para a Amostragem
  sync_parallel_counter #(
      .size(4),
      .init_value(0)
  ) sample_counter (
      .clock(clock),
      .reset(sample_cnt_rst),
      .load(1'b0),
      .load_value(4'b0),
      .inc_enable(1'b1),  // Sempre Ativo
      .dec_enable(1'b0),
      .value(sample_cnt)
  );

  // Rx Reg
  register_d #(
      .N(8),
      .reset_value(0)
  ) rx_reg (
      .clock(clock),
      .reset(reset),
      // Enable: Estado Data, Fim da contagem de amostragem
      // (garante que sampled bit seja válido)
      .enable(data_en & sample_end),
      .D({sampled_bit, data_reg[7:1]}),
      .Q(data_reg)
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
      .inc_enable(sample_end),
      .dec_enable(1'b0),
      .value(data_cnt)
  );

  // Verifica se houve erro de paridade
  register_d #(
      .N(1),
      .reset_value(0)
  ) parity_reg (
      .clock(clock),
      .reset(reset | data_cnt_rst),  // limpa o erro de paridade antigo
      .enable(check_parity & sample_end),
      // Checa se a paridade obtida é a correta
      .D((^data_reg) ^ parity_type[0] ^ sampled_bit),
      .Q(parity_er)
  );

  // Verifica se houve erro de framing
  register_d #(
      .N(1),
      .reset_value(0)
  ) framing_reg (
      .clock(clock),
      .reset(reset),
      .enable(check_framing & sample_end),
      // Checa se a paridade obtida é a correta
      .D(~sampled_bit),
      .Q(framing_er)
  );

  // Registrador do sinal de fim da transmissão
  register_d #(
      .N(1),
      .reset_value(0)
  ) transmit_end_reg (
      .clock(clock),
      .reset(reset),
      .enable(transmit_end_en | transmit_end),
      .D(~transmit_end),
      .Q(transmit_end)
  );

  // Saídas Bufferizadas
  register_d #(
      .N(3),
      .reset_value(0)
  ) output_reg (
      .clock(clock),
      .reset(reset | data_cnt_rst),  // reseto as saídas no Start
      .enable(transmit_end),
      .D({parity_er, framing_er, data_vld}),
      .Q({parity_error, frame_error, data_valid})
  );

  assign data_out = data_reg;

  // Dado válido após o fim da recepção e sem erros
  assign data_vld = ~parity_er & ~framing_er;

  // Transição de Estado
  always_ff @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Saída e de Próximo Estado da FSM
  always_comb begin
    data_en = 1'b0;
    sample_cnt_rst = 1'b0;
    data_cnt_rst = 1'b0;
    check_parity = 1'b0;
    check_framing = 1'b0;
    transmit_end_en = 1'b0;
    case (present_state)
      Idle: begin
        // Caso RX habilitado e um 0 seja detectado -> Start
        sample_cnt_rst = 1'b1;
        if (~rxd && rx_en) next_state = Start;
        else next_state = Idle;
      end
      Start: begin
        // Detectou Start Bit com sucesso
        if ((~sampled_bit) && sample_end) begin
          data_cnt_rst = 1'b1;
          next_state   = Data;
        end else if (sample_end) next_state = Idle;  // Falsa Detecção
        else next_state = Start;
      end
      Data: begin
        data_en = 1'b1;
        if (&data_cnt & sample_end) begin
          if (parity_type[1]) next_state = Parity;  // Paridade está sendo transmitida
          else next_state = Stop1;  // Sem paridade
        end else next_state = Data;
      end
      Parity: begin
        check_parity = 1'b1;  // checar paridade
        if (sample_end) next_state = Stop1;
        else next_state = Parity;
      end
      Stop1: begin
        check_framing = 1'b1;
        if (sample_end) begin
          if (nstop) next_state = Stop2;
          else begin
            transmit_end_en = 1'b1;  // Fim da transmissão
            next_state = Idle;
          end
        end else next_state = Stop1;
      end
      Stop2: begin
        // Sem erro no stop1 -> checar stop2
        check_framing = ~framing_er;
        if (sample_end) begin
          transmit_end_en = 1'b1;  // Fim da transmissão
          next_state = Idle;
        end else next_state = Stop2;
      end
      default: begin
        next_state = Idle;
      end
    endcase
  end
endmodule
