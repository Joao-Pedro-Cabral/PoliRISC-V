//
//! @file   sd_receiver.v
//! @brief  Implementação de um recebedor SPI para um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-09
//

module sd_receiver (
    // Comum
    input wire clock,
    input wire reset,
    // Controlador
    input wire [1:0] response_type,  // 00: R1 e data_response, 01: R3/R7, 1X: Data Block
    input wire new_response_type,  // 1: receiver amostra novo response type
    output wire [4095:0] received_data,
    output wire data_valid,
    output wire crc_error,
    // SD
    input wire miso
);

  wire [12:0] transmission_size;  // R1: 7, R3 e R7: 39, Data: 4113
  wire [12:0] bits_received;
  wire [4095:0] data_received;
  reg [15:0] crc16;

  // Sinais de controle
  reg init_transmission;
  reg receiving;
  reg end_transmission;
  wire [1:0] response_type_;

  // FSM
  localparam reg [1:0] Idle = 2'b00, Receive = 2'b01, End = 2'b10;

  reg [1:0] new_state, state;

  // Computa quantos dados já foram recebidos
  // Delay de 1 bit
  // data_valid ativado 1 ciclo após o data_received amostrar o último bit
  sync_parallel_counter #(
      .size(13),
      .init_value(4113)
  ) bit_counter (
      .clock(clock),
      .load(init_transmission),  // Carrega a cada nova transmissão
      .load_value(transmission_size),
      .reset(reset),
      .inc_enable(1'b0),
      .dec_enable(receiving),
      .value(bits_received)
  );

  register_d #(
      .N(2),
      .reset_value(2'b0)
  ) response_type_reg (
      .clock(clock),
      .reset(reset),
      // Paro o reg antes dele pegar o CRC16
      .enable(new_response_type),
      .D(response_type),
      .Q(response_type_)
  );

  assign transmission_size = response_type_[1] ? 4112 : (response_type_[0] ? 39 : 7);

  // Shift Register
  register_d #(
      .N(4096),
      .reset_value({4096{1'b0}})
  ) receiver_reg (
      .clock(clock),
      .reset(reset),
      // Paro o reg antes dele pegar o CRC16
      .enable(receiving & !(response_type_[1] & bits_received <= 16)),
      .D({data_received[4094:0], miso}),
      .Q(data_received)
  );

  assign received_data = data_received;

  // CRC16 com LFSR
  always @(posedge clock) begin
    if (reset | init_transmission) begin
      crc16 <= 16'b0;
    end else if (receiving) begin
      crc16[0] <= crc16[15] ^ miso;
      crc16[4:1] <= crc16[3:0];
      crc16[5] <= crc16[4] ^ crc16[15] ^ miso;
      crc16[11:6] <= crc16[10:5];
      crc16[12] <= crc16[11] ^ crc16[15] ^ miso;
      crc16[15:13] <= crc16[14:12];
    end
  end

  // FSM
  always @(posedge clock) begin
    if (reset) state <= Idle;
    else state <= new_state;
  end

  always @(*) begin
    receiving = 1'b0;
    init_transmission = 1'b0;
    end_transmission = 1'b0;
    new_state = Idle;
    case (state)
      Idle: begin
        if (!miso) begin
          init_transmission = 1'b1;
          receiving = 1'b1;
          new_state = Receive;
        end
      end
      Receive: begin
        if (bits_received == 13'b0) begin
          end_transmission = 1'b1;
          new_state = End;
        end else begin
          receiving = 1'b1;
          new_state = Receive;
        end
      end
      End: begin
        if (!miso) begin
          init_transmission = 1'b1;
          receiving = 1'b1;
          new_state = Receive;
        end else end_transmission = 1'b1;
      end
      default: begin
        new_state = Idle;
      end
    endcase
  end

  // Saídas de status
  assign data_valid = end_transmission & (!response_type_[1] | (crc16 == 0)) & miso;
  assign crc_error  = end_transmission & (response_type_[1] & (crc16 != 0));

endmodule
