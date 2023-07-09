module sd_init #(
    parameter reg CPOL = 1'b0
) (
    // sinais de sistema
    input wire clock,
    input wire reset,

    // interface com o cartão SD
    input  wire miso,
    output reg  cs,
    output reg  sck,
    output reg  mosi,

    // sinais de status
    input  wire init_en,
    output reg  init_busy
);

  reg cmd_index;
  reg argument;
  reg cmd_valid;
  reg response_type;
  wire [39:0] received_data;
  wire data_valid;

  sd_cmd_sender cmd_sender (
      .clock(clock),
      .reset(reset),
      .cmd_index(cmd_index),
      .argument(argument),
      .cmd_valid(cmd_valid),
      // interface com o cartão SD
      .mosi(mosi),
      .sending_cmd(sending_cmd)
  );

  sd_cmd_receiver cmd_receiver (
      .clock(clock),
      .reset(reset),
      .response_type(response_type),
      .received_data(received_data),
      .data_valid(data_valid),
      .miso(miso)
  );


  reg new_cs;
  reg new_sck;

  localparam reg [7:0]
    Idle = 8'h00,
    SendCmd0 = 8'h03,
    Cmd8 = 8'h04,
    Cmd8R1 = 8'h05,
    Cmd8B2 = 8'h06,
    Cmd8B3 = 8'h07,
    Cmd8B4 = 8'h08,
    Cmd8GotB4 = 8'h09,
    Cmd55 = 8'h0A,
    Acmd41 = 8'h0B,
    PollCmd = 8'h0C,
    Cmd58 = 8'h0D,
    Cmd58R1 = 8'h0E,
    Cmd58B2 = 8'h0F,
    Cmd58B3 = 8'h10,
    Cmd58B4 = 8'h11,
    WaitSendCmd = 8'h12;

  reg [7:0] new_state, state, new_state_return;

  always @(posedge clk) begin
    if (reset) begin
      cs    <= 1'b1;
      sck   <= CPOL;
      state <= Idle;
    end else begin
      cs    <= new_cs;
      sck   <= new_sck;
      state <= new_state;
    end
  end

  task reset_signals;
    begin
      new_cs = 1'b1;
      new_sck = CPOL;
      cmd_index = 6'b000000;
      argument = 32'b0;
      cmd_valid = 1'b0;
      response_type = 1'b0;
      new_state = Idle;
      new_state_return = Idle;
    end
  endtask

  always @(*) begin
    reset_signals;

    case (state)
      Idle: begin  // Faz nada
        if (init_en) new_state = SendCmd0;
        else new_state = Idle;
      end

      WaitSendCmd: begin  // Espera Comando ser enviado pelo cmd_sender
        new_cs = 1'b0;
        if (!sending_cmd) new_state = WaitReceiveCmd;
        else new_state = WaitSendCmd;
      end

      WaitReceiveCmd: begin
        if (data_valid) begin
          new_cs = 1'b1;
          new_state = new_state_return;
        end else begin
          new_cs = 1'b0;
          new_state = WaitReceiveCmd;
        end
      end

      SendCmd0: begin  // Enviar CMD0
        new_cs = 1'b0;
        cmd_index = 6'h00;
        argument = 32'b0;
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd0;
      end

      CheckCmd0: begin
        if (received_data[7:0] == 8'h01) new_state = SendCmd8;
        else new_state = SendCmd0;
      end

      SendCmd8: begin  // Enviar CMD8
        new_cs = 1'b0;
        cmd_index = 6'h08;
        argument = 32'h000001AA;
        cmd_valid = 1'b1;
        response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd8;
      end

      CheckCmd8: begin
        // Tenta dnv kkkkkkkk
      end

      Cmd8R1: begin
      end

      Cmd8B2: begin
      end

      Cmd8B3: begin
      end

      Cmd8B4: begin
      end

      Cmd8GotB4: begin
      end

      Cmd55: begin
      end

      Acmd41: begin
      end

      PollCmd: begin
      end

      Cmd58: begin
      end

      Cmd58R1: begin
      end

      Cmd58B2: begin
      end

      Cmd58B3: begin
      end

      Cmd58B4: begin
      end

      default: begin
      end
    endcase
  end

  assign init_busy = state != Idle;

endmodule
