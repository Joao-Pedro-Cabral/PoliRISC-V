module sd_controller (
    // sinais de sistema
    input clock_400K,
    input clock_50M,
    input reset,

    // interface com a pseudocache
    input rd_en,
    input [31:0] addr,
    output wire [4095:0] read_data,

    // interface com o cartão SD
    input miso,
    output reg cs,
    output wire sck,
    output wire mosi,

    // sinal de status
    output wire busy
);

  wire clock;

  reg [5:0] cmd_index;
  reg [31:0] argument;
  reg cmd_valid;
  reg [1:0] response_type;
  wire [4095:0] received_data;
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

  sd_receiver receiver (
      .clock(clock),
      .reset(reset),
      .response_type(response_type),
      .received_data(received_data),
      .data_valid(data_valid),
      .miso(miso)
  );


  reg new_cs;

  localparam reg [7:0]
    InitBegin = 4'h0,
    WaitSendCmd = 4'h1,
    WaitReceiveCmd = 4'h2,
    SendCmd0 = 4'h3,
    CheckCmd0 = 4'h4,
    SendCmd8 = 4'h5,
    CheckCmd8 = 4'h6,
    SendCmd55 = 4'h7,
    CheckCmd55 = 4'h8,
    SendAcmd41 = 4'h9,
    CheckAcmd41 = 4'hA,
    Idle = 4'hB,
    SendCmd17 = 4'hC,
    CheckCmd17 = 4'hD,
    CheckRead = 4'hE,
    CheckToken = 4'hF;

  reg [7:0] new_state = InitBegin, state = InitBegin, new_state_return = InitBegin;

  // Antes do Idle: Inicialização (400KHz), Após: Leitura(50MHz)
  assign clock = (state >= Idle) ? clock_50M : clock_400K;
  assign sck   = ~clock;

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      cs    <= 1'b1;
      state <= InitBegin;
    end else begin
      cs    <= new_cs;
      state <= new_state;
    end
  end

  task reset_signals;
    begin
      new_cs = 1'b1;
      cmd_index = 6'b000000;
      argument = 32'b0;
      cmd_valid = 1'b0;
      response_type = 2'b00;
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
        new_cs = 1'b0;
        if (data_valid) new_state = new_state_return;
        else new_state = WaitReceiveCmd;
      end

      SendCmd0: begin  // Enviar CMD0
        new_cs = 1'b0;
        cmd_index = 6'h00;
        argument = 32'b0;
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
        cmd_valid = 1'b1;
        response_type = 2'b01;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd8;
      end

      CheckCmd8: begin  // Checa check pattern e se a tensão é suportada
        if (received_data[7:0] != 8'hAA) new_state = SendCmd8;
        else if (received_data[11:8] != 4'h1) new_state = InitBegin;
        else new_state = SendCmd55;
      end

      SendCmd55: begin  // Envia CMD55 -> Deve proceder ACMD*
        new_cs = 1'b0;
        cmd_index = 6'd55;
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd55;
      end

      CheckCmd55: begin  // Checa se ainda está em Idle
        if (received_data[7:0] == 8'h01) new_state = SendAcmd41;
        else new_state = SendCmd55;
      end

      SendAcmd41: begin  // Envia ACMD41
        new_cs = 1'b0;
        cmd_index = 6'd41;
        argument = 32'h40000000;
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckAcmd41;
      end

      CheckAcmd41: begin  // Checa ACMD41 -> Até sair do Idle
        if (received_data[7:0] == 8'h00) new_state = Idle;
        else new_state = SendCmd55;
      end

      Idle: begin  // Idle: Espera leitura
        if (rd_en) begin
          new_cs = 1'b0;
          new_state = SendCmd17;
        end else new_state = Idle;
      end

      SendCmd17: begin  // Envia CMD17
        new_cs = 1'b0;
        cmd_index = 6'd17;
        argument = addr;
        cmd_valid = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd17;
      end

      CheckCmd17: begin  // Checa R1 do CMD17
        new_cs = 1'b0;
        // R1 sem erros -> Data Block
        if (received_data[7:0] == 8'h00) begin
          response_type = 2'b10;
          new_state = WaitReceiveCmd;
          new_state_return = CheckRead;
        end else begin  // R1 com erros -> Error Token
          new_state = WaitReceiveCmd;
          new_state_return = CheckToken;
        end
      end

      CheckRead: begin  // Checa dado lido
        if (data_valid) new_state = Idle;
        else new_state = SendCmd17;  // Tentar novamente
      end

      CheckToken: begin
        if (received_data[3]) new_state = Idle;  // Endereço inválido
        else new_state = SendCmd17;
      end

      default: begin
      end
    endcase
  end

  assign busy = (state != Idle) & rd_en;
  assign read_data = received_data;

endmodule
