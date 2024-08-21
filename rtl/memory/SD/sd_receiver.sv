
import sd_receiver_pkg::*;

module sd_receiver (
    // Comum
    input wire clock,
    input wire reset,

    // Controlador
    input sd_receiver_response_t response_type,
    output wire [4095:0] received_data,
    output wire ready,
    input wire valid,
    output wire crc_error,

    // SD
    input wire miso,

    output sd_receiver_fsm_t receiver_state_db
);

  reg _ready;

  sd_receiver_response_size_t transmission_size;  // R1: 7, R3 e R7: 39, Data: 4112
  wire [12:0] bits_received;
  wire [4095:0] data_received;
  reg [15:0] crc16;

  // Sinais de controle
  reg init_transmission;
  reg receiving;
  reg end_transmission;

  sd_receiver_fsm_t new_state, state;

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

  always_comb begin
    unique case(response_type)
      R1: transmission_size = R1OrDataTokenSize;
      R3OrR7: transmission_size = R3OrR7Size;
      DataToken: transmission_size = R1OrDataTokenSize;
      DataBlock: transmission_size = DataBlockSize;
      R2: transmission_size = R2Size;
      default: transmission_size = R2Size;
    endcase
  end

  // Shift Register
  register_d #(
      .N(4096),
      .reset_value({4096{1'b0}})
  ) receiver_reg (
      .clock(clock),
      .reset(reset),
      // Paro o reg antes dele pegar o CRC16
      .enable(receiving && !((response_type == DataBlock) && bits_received <= 16)),
      .D({data_received[4094:0], miso}),
      .Q(data_received)
  );

  // CRC16 com LFSR
  always_ff @(posedge clock) begin
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
  always_ff @(posedge clock, posedge reset) begin
    if (reset) state <= sd_receiver_pkg::Idle;
    else state <= new_state;
  end

  task automatic reset_signals;
    begin
      _ready = 1'b0;
      init_transmission = 1'b0;
      receiving = 1'b0;
      end_transmission = 1'b0;
    end
  endtask

  always_comb begin
    reset_signals;
    new_state = sd_receiver_pkg::Idle;

    case (state)
      sd_receiver_pkg::Idle: begin
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
          if (response_type == DataToken) new_state = WaitBusy;
          else new_state = sd_receiver_pkg::Idle;
        end else begin
          receiving = 1'b1;
          new_state = state;
        end
      end

      WaitBusy: begin
        end_transmission = 1'b1;
        if (miso) new_state = sd_receiver_pkg::Idle;
        else new_state = state;
      end

      default: begin
        new_state = sd_receiver_pkg::Idle;
      end
    endcase
  end

  // Saídas
  assign crc_error  = end_transmission && ((response_type == DataBlock) && (crc16 != 0));
  assign ready = _ready;
  assign received_data = data_received;

  assign receiver_state_db = state;

endmodule
