module sd_cmd_receiver (
    // Comum
    input wire clock,
    input wire reset,
    // Controlador
    input wire response_type,  // 0: R1, 1: R3/R7
    output wire [39:0] received_data,
    output wire data_valid,
    // SD
    input wire miso
);

  wire [5:0] transmission_size;  // R1: 7, R3 e R7: 39
  wire [5:0] bits_received;
  wire [39:0] data_received;

  // Sinais de controle
  reg receiving;
  wire data_vld;

  // FSM
  localparam reg Idle = 1'b0, Receive = 1'b1;

  reg new_state, state;

  // Computa quantos dados já foram recebidos
  // Delay de 1 bit
  // data_valid ativado 1 ciclo após o data_received amostrar o último bit
  sync_parallel_counter #(
      .size(6),
      .init_value(40)
  ) bit_counter (
      .clock(clock),
      .load(receiving),
      .load_value(transmission_size),
      .reset(reset),
      .inc_enable(1'b0),
      .dec_enable(receiving),
      .value(bits_received)
  );

  assign transmission_size = response_type ? 39 : 7;
  assign data_vld = (bits_received == 6'b0);  // Dado válido ao fim da transmissão
  assign data_valid = data_vld;

  register_d #(
      .N(40),
      .reset_value({40{1'b0}})
  ) receiver_reg (
      .clock(clock),
      .reset(reset),
      .enable(receiving),
      .D({data_received[39:1], miso}),
      .Q(data_received)
  );

  assign received_data = data_received;

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
        if (data_vld) new_state = Idle;
        else begin
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
