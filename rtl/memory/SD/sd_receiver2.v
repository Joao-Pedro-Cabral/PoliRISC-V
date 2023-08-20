//
//! @file   sd_receiver.v
//! @brief  Implementação de um recebedor SPI para um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-09
//

`define DEBUG

module sd_receiver2 (
    // Comum
    input clock,
    input reset,

    // Controlador
    input [2:0] response_type,  // 000: R1, 001: R3/R7, 010: data_token, 011: Data Block, 1XX: R2
    output wire [4095:0] received_data,
    output wire ready,
    input valid,
    output wire crc_error,

    // SD
    input miso

`ifdef DEBUG
    ,
    output wire [1:0] receiver_state
`endif
);

  reg _ready;

  wire [12:0] transmission_size;  // R1: 7, R3 e R7: 39, Data: 4112
  wire [12:0] bits_received;
  wire [4095:0] data_received;
  reg [15:0] crc16;

  // Sinais de controle
  reg init_transmission;
  reg receiving;
  reg end_transmission;

  // FSM
  localparam reg [1:0] Idle = 2'b00, WaitingSD = 2'b01, Receiving = 2'b10, WaitBusy = 2'b11;

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

  assign transmission_size =
    response_type[2] ? 13'd15
    : ((response_type == 3'b011) ? 13'd4112 : (response_type[0] ? 13'd39 : 13'd7));

  // Shift Register
  register_d #(
      .N(4096),
      .reset_value({4096{1'b0}})
  ) receiver_reg (
      .clock(clock),
      .reset(reset),
      // Paro o reg antes dele pegar o CRC16
      .enable(receiving && !((response_type == 3'b011) && bits_received <= 16)),
      .D({data_received[4094:0], miso}),
      .Q(data_received)
  );

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
  always @(posedge clock, posedge reset) begin
    if (reset) state <= Idle;
    else state <= new_state;
  end

  task reset_signals;
    begin
      _ready = 1'b0;
      init_transmission = 1'b0;
      receiving = 1'b0;
      end_transmission = 1'b0;
    end
  endtask

  always @* begin
    reset_signals;
    new_state = Idle;

    case (state)
      Idle: begin
        _ready = 1'b1;
        end_transmission = 1'b1;
        if (valid) begin
          if (~miso) begin
            init_transmission = 1'b1;
            receiving = 1'b1;
            new_state = Receiving;
          end else new_state = WaitingSD;
        end else new_state = state;
      end

      WaitingSD: begin
        if (~miso) begin
          init_transmission = 1'b1;
          receiving = 1'b1;
          new_state = Receiving;
        end else new_state = state;
      end

      Receiving: begin
        if (bits_received == 13'b0) begin
          end_transmission = 1'b1;
          if (response_type == 3'b010) new_state = WaitBusy;
          else new_state = Idle;
        end else begin
          receiving = 1'b1;
          new_state = state;
        end
      end

      WaitBusy: begin
        end_transmission = 1'b1;
        if (miso) new_state = Idle;
        else new_state = state;
      end

      default: begin
        new_state = Idle;
      end
    endcase
  end

  // Saídas
  assign crc_error  = end_transmission && ((response_type == 3'b011) && (crc16 != 0));
  assign ready = _ready;
  assign received_data = data_received;
`ifdef DEBUG
  assign receiver_state = state;
`endif

endmodule
