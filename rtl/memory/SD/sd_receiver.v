module sd_receiver (
    // Comum
    input wire clock,
    input wire reset,
    // Controlador
    input wire [1:0] response_type,  // 00: R1, 01: R3/R7, 1X: Data Block
    input wire new_response_type,  // 1: receiver amostra novo response type
    output wire [4095:0] received_data,
    output wire data_valid,
    output wire crc_error,
    // SD
    input wire miso
);

  wire [12:0] transmission_size;  // R1: 7, R3 e R7: 39
  wire [12:0] bits_received;
  wire [4095:0] data_received;
  reg [15:0] crc16;

  // Sinais de controle
  reg receiving;
  wire [1:0] response_type_;

  // FSM
  localparam reg Idle = 1'b0, Receive = 1'b1;

  reg new_state, state;

  // Computa quantos dados já foram recebidos
  // Delay de 1 bit
  // data_valid ativado 1 ciclo após o data_received amostrar o último bit
  sync_parallel_counter #(
      .size(13),
      .init_value(4113)
  ) bit_counter (
      .clock(clock),
      .load(receiving & (state == Idle)),  // Carrega a cada nova transmissão
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

  assign transmission_size = response_type_[1] ? 4113 : (response_type_[0] ? 39 : 7);
  assign data_valid = (!receiving) & (!response_type_[1] | (crc16 == 0));
  assign crc_error = (!receiving) & (!response_type_[1] | (crc16 != 0));

  // Shift Register
  register_d #(
      .N(4096),
      .reset_value({4096{1'b0}})
  ) receiver_reg (
      .clock(clock),
      .reset(reset),
      // Paro o reg antes dele pegar o CRC16
      .enable(receiving & !(response_type_[1] & bits_received <= 17)),
      .D({data_received[4094:0], miso}),
      .Q(data_received)
  );

  assign received_data = data_received;

  // CRC16 com LFSR
  always @(posedge clock) begin
    if (reset) begin
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
    new_state = Idle;
    case (state)
      Idle: begin
        if (!miso) begin
          receiving = 1'b1;
          new_state = Receive;
        end
      end
      Receive: begin
        if (bits_received == 13'b0) begin
          new_state = Idle;
        end else begin
          receiving = 1'b1;
          new_state = Receive;
        end
      end
      default: begin
        receiving = 1'b0;
        new_state = Idle;
      end
    endcase
  end
endmodule
