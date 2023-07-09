module sd_controller #(
    parameter reg CPOL = 1'b0
) (
    // sinais de sistema
    input clock,
    input reset,

    // interface com a pseudocache
    input rd_en,
    input [31:0] addr,
    output reg [4095:0] read_data,

    // interface com o cartão SD
    input miso,
    output reg cs,
    output reg sck,
    output reg mosi,

    // sinal de status
    output reg init_busy
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
    InitBegin = 8'h00,
    WaitSendCmd = 8'h01,
    WaitReceiveCmd = 8'h02,
    SendCmd0 = 8'h03,
    CheckCmd0 = 8'h04,
    SendCmd8 = 8'h05,
    CheckCmd8 = 8'h06,
    SendCmd55 = 8'h07,
    CheckCmd55 = 8'h08,
    SendAcmd41 = 8'h09,
    CheckAcmd41 = 8'h0A,
    Idle = 8'h0B,
    SendCmd17 = 8'h0C,
    CheckCmd17 = 8'h0D;

  reg [7:0] new_state, state, new_state_return;

  always @(posedge clk) begin
    if (reset) begin
      cs    <= 1'b1;
      sck   <= CPOL;
      state <= InitBegin;
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
      new_state = InitBegin;
      new_state_return = InitBegin;
    end
  endtask

  always @(*) begin
    reset_signals;

    case (state)
      InitBegin: begin  // Faz nada
        new_state = SendCmd0;
      end

      WaitSendCmd: begin  // Espera Comando ser enviado pelo cmd_sender
        new_cs = 1'b0;
        if (!sending_cmd) new_state = WaitReceiveCmd;
        else new_state = WaitSendCmd;
      end

      WaitReceiveCmd: begin  // Espera resposta do cartão SD (componente cmd_receiver)
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
        // crc7 = ?
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd0;
      end

      CheckCmd0: begin  // Checa se cartão SD está InitBegin e sem erros
        if (received_data[7:0] == 8'h01) new_state = SendCmd8;
        else new_state = SendCmd0;
      end

      SendCmd8: begin  // Enviar CMD8
        new_cs = 1'b0;
        cmd_index = 6'h08;
        argument = 32'h000001AA;
        // crc7 = ?
        cmd_valid = 1'b1;
        response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd8;
      end

      CheckCmd8: begin  // Checa check pattern e se a tensão é suportada
        if (received_data[7:0] != 8'hAA) new_state = SendCmd8;
        else if (received_data[11:8] != 4'h1) new_state = InitBegin;
        else new_state = SendCmd55;
      end

      SendCmd55: begin
        new_cs = 1'b0;
        cmd_index = 6'd55;
        // crc7 = ?
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd55;
      end

      CheckCmd55: begin
        if (received_data[7:0] == 8'h01) new_state = SendAcmd41;
        else new_state = SendCmd55;
      end

      SendAcmd41: begin
        new_cs = 1'b0;
        cmd_index = 6'd41;
        argument = 32'h40000000;
        // crc7 = ?
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckAcmd41;
      end

      CheckAcmd41: begin
        if (received_data[7:0] == 8'h00) new_state = Idle;
        else new_state = SendCmd55;
      end

      Idle: begin
        if (rd_en) begin
          new_cs = 1'b0;
          new_state = SendCmd17;
        end else new_state = Idle;
      end

      SendCmd17: begin
        new_cs = 1'b0;
        cmd_index = 6'd17;
        argument = addr;
        // crc7 = ?
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd17;
      end

      CheckCmd17: begin
        if (received_data[7:0] == 8'h00) new_state = Idle;
        else new_state = SendCmd55;
      end

      default: begin
      end
    endcase
  end

  assign init_busy = state != Idle;

endmodule
