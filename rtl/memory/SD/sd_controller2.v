//
//! @file   sd_controller.v
//! @brief  Implementação de um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-10
//

/* `define SDSC */
/* `define DEBUG */

module sd_controller2 (
    // sinais de sistema
    input clock_400K,
    input clock_50M,
    input reset,

    // interface com a pseudocache
    input rd_en,
    input wr_en,
    input [31:0] addr,
    input wire [4095:0] write_data,
    output wire [4095:0] read_data,

    // interface com o cartão SD
    input miso,
    output reg cs,
    output wire sck,
    output wire mosi,

    // sinal de status
    output reg busy

`ifdef DEBUG
    ,
    output wire [4:0] sd_controller_state,
    output reg  [7:0] check_cmd_0_dbg,
    output reg  [7:0] check_cmd_8_dbg,
    output reg  [7:0] check_cmd_55_dbg,
    output reg  [7:0] check_acmd_41_dbg,
    output reg  [7:0] check_cmd_16_dbg,
    output reg  [7:0] check_cmd_24_dbg,
    output reg  [7:0] check_write_dbg,
    output reg  [7:0] check_cmd_17_dbg,
    output reg  [7:0] check_read_dbg
`endif
);

  wire clock;
  reg [31:0] addr_reg;
  reg [4095:0] write_data_reg;
  reg busy_en, new_busy;

  reg [5:0] cmd_index;
  reg [31:0] argument;
  reg cmd_or_data;
  reg [1:0] response_type;
  reg [1:0] new_response_type;
  wire [4095:0] received_data;
  wire response_received;
  wire crc_error;
  reg new_cs;
  reg initializing, new_initializing, initializing_en;
  reg new_sck_50M;
  reg sck_50M;
  reg sck_en;

  reg sender_valid, receiver_valid;
  wire sender_ready, receiver_ready;

  sd_sender2 sender (
      .clock(clock),
      .reset(reset),
      .cmd_index(cmd_index),
      .argument(argument),
      .cmd_or_data(cmd_or_data),
      .ready(sender_ready),
      .valid(sender_valid),
      .data(write_data_reg),
      .mosi(mosi)
  );

  sd_receiver2 receiver (
      .clock(clock),
      .reset(reset),
      .response_type(response_type),
      .received_data(received_data),
      .ready(receiver_ready),
      .valid(receiver_valid),
      .crc_error(crc_error),
      .miso(miso)
  );

  assign read_data = received_data;

  localparam reg [4:0]
    InitBegin = 5'h0,
    WaitSendCmd = 5'h1,
    WaitReceiveCmd = 5'h2,
    SendCmd0 = 5'h3,
    CheckCmd0 = 5'h4,
    SendCmd8 = 5'h5,
    CheckCmd8 = 5'h6,
    SendCmd55 = 5'h7,
    CheckCmd55 = 5'h8,
    SendAcmd41 = 5'h9,
    CheckAcmd41 = 5'hA,
`ifdef SDSC
    SendCmd16 = 5'hB,
    CheckCmd16 = 5'hC,
`endif
    Idle = 5'hD,
    SendCmd17 = 5'hE,
    CheckCmd17 = 5'hF,
    SendCmd24 = 5'h10,
    CheckCmd24 = 5'h11,
    CheckRead = 5'h12,
    CheckWrite = 5'h13,
    CheckErrorToken = 5'h14;

  reg [4:0]
      new_state,
      state = InitBegin,
      state_return = InitBegin,
      new_state_return;
  reg state_return_en, response_type_en;

  // Antes do Idle: Inicialização (400KHz), Após: Leitura(50MHz)
  assign clock = sck_50M ? clock_50M : clock_400K;
  assign sck   = sck_en & ~clock; // TODO: ver se tirar o enable muda algo

`ifdef DEBUG
  reg
      check_cmd_0_dbg_en,
      check_cmd_8_dbg_en,
      check_cmd_55_dbg_en,
      check_acmd_41_dbg_en,
      check_cmd_16_dbg_en,
      check_cmd_24_dbg_en,
      check_write_dbg_en,
      check_cmd_17_dbg_en,
      check_read_dbg_en;
`endif

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      cs    <= 1'b1;
      sck_50M <= 1'b0;
      state <= InitBegin;
      state_return <= InitBegin;
      response_type <= 2'b00;
      busy <= 1'b0;
      initializing <= 1'b1;
`ifdef DEBUG
      check_cmd_0_dbg <= 8'h00;
      check_cmd_8_dbg <= 8'd8;
      check_cmd_55_dbg <= 8'd55;
      check_acmd_41_dbg <= 8'd41;
      check_cmd_16_dbg <= 8'd16;
      check_cmd_24_dbg <= 8'd24;
      check_write_dbg <= 8'd10;
      check_cmd_17_dbg <= 8'd17;
      check_read_dbg <= 8'd11;
`endif
    end else begin
      cs    <= new_cs;
      state <= new_state;
      if (state_return_en) state_return <= new_state_return;
      else state_return <= state_return;
      if (response_type_en) response_type <= new_response_type;
      else response_type <= response_type;
      if (new_sck_50M) sck_50M <= 1'b1;
      else sck_50M <= sck_50M;
      if (busy_en) busy <= new_busy;
      else busy <= busy;
      if(initializing_en) initializing <= new_initializing;
      else initializing <= initializing;
`ifdef DEBUG
      if (check_cmd_0_dbg_en) check_cmd_0_dbg <= received_data[7:0];
      if (check_cmd_8_dbg_en) check_cmd_8_dbg <= received_data[39:32];
      if (check_cmd_55_dbg_en) check_cmd_55_dbg <= received_data[7:0];
      if (check_acmd_41_dbg_en) check_acmd_41_dbg <= received_data[7:0];
      if (check_cmd_16_dbg_en) check_cmd_16_dbg <= received_data[7:0];
      if (check_cmd_24_dbg_en) check_cmd_24_dbg <= received_data[7:0];
      if (check_write_dbg_en) check_write_dbg <= received_data[7:0];
      if (check_cmd_17_dbg_en) check_cmd_17_dbg <= received_data[7:0];
      if (check_read_dbg_en) check_read_dbg <= received_data[7:0];
`endif
    end
  end


  task reset_signals;
    begin
      sck_en = 1'b1;
      new_cs = 1'b1;
      cmd_index = 6'b000000;
      argument = 32'b0;
      cmd_or_data = 1'b0;
      sender_valid = 1'b0;
      receiver_valid = 1'b0;
      new_response_type = 2'b00;
      new_sck_50M = 1'b0;
      new_state = InitBegin;
      new_state_return = InitBegin;
      state_return_en = 1'b0;
      response_type_en = 1'b0;
      new_initializing = 1'b0;
      initializing_en = 1'b0;
      new_busy = 1'b0;
      busy_en = 1'b0;
`ifdef DEBUG
      check_cmd_0_dbg_en = 1'b0;
      check_cmd_8_dbg_en = 1'b0;
      check_cmd_55_dbg_en = 1'b0;
      check_acmd_41_dbg_en = 1'b0;
      check_cmd_16_dbg_en = 1'b0;
      check_cmd_24_dbg_en = 1'b0;
      check_write_dbg_en = 1'b0;
      check_cmd_17_dbg_en = 1'b0;
      check_read_dbg_en = 1'b0;
`endif
    end
  endtask

  always @(*) begin
    reset_signals;
    case(state)
      InitBegin: begin
        new_initializing = 1'b1;
        initializing_en = 1'b1;
        new_busy = 1'b0;
        busy_en = 1'b1;
        new_state = SendCmd0;
      end

      WaitSendCmd: begin  // Espera Comando ser enviado pelo cmd_sender
        new_cs = 1'b0;
        if (sender_ready) begin
          receiver_valid = 1'b1;
          if (~receiver_ready) new_state = WaitReceiveCmd;
          else new_state = state;
        end else new_state = state;
      end

      WaitReceiveCmd: begin  // Espera resposta do cartão SD (componente cmd_receiver)
        new_cs = 1'b0;
        if (receiver_ready) new_state = state_return;
        else new_state = state;
      end

      SendCmd0: begin  // Enviar CMD0
        cmd_index = 6'h00;
        argument = 32'b0;
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckCmd0;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0; // TODO: testar com esse cs para fora
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd0: begin  // Checa se cartão SD está InitBegin e sem erros
`ifdef DEBUG
        check_cmd_0_dbg_en = 1'b1;
`endif
        if (received_data[7:0] == 8'h01) new_state = SendCmd8;
        else new_state = SendCmd0;
      end

      SendCmd8: begin  // Enviar CMD8
        cmd_index = 6'h08;
        argument = 32'h000001AA;
        new_response_type = 2'b01;
        response_type_en = 1'b1;
        new_state_return = CheckCmd8;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd8: begin  // Checa check pattern e se a tensão é suportada
`ifdef DEBUG
        check_cmd_8_dbg_en = 1'b1;
`endif
        if (received_data[39:32] == 8'h05) new_state = SendCmd55;
        else if (received_data[7:0] != 8'hAA) new_state = SendCmd8;
        else if (received_data[11:8] != 4'h1) new_state = InitBegin;
        else new_state = SendCmd55;
      end

      SendCmd55: begin  // Envia CMD55 -> Deve proceder ACMD*
        cmd_index = 6'd55;
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckCmd55;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd55: begin  // Checa se ainda está em Idle
`ifdef DEBUG
        check_cmd_55_dbg_en = 1'b1;
`endif
        if (received_data[7:0] == 8'h01) new_state = SendAcmd41;
        else new_state = SendCmd55;
      end

      SendAcmd41: begin  // Envia ACMD41
        cmd_index = 6'd41;
`ifdef SDSC
        argument = 32'h00000000;
`else
        argument = 32'h40000000;
`endif
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckAcmd41;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckAcmd41: begin  // Checa ACMD41 -> Até sair do Idle
`ifdef DEBUG
        check_acmd_41_dbg_en = 1'b1;
`endif
        if (received_data[7:0] == 8'h00) begin
`ifdef SDSC
          new_state = SendCmd16;
`else
          new_initializing = 1'b0;
          initializing_en = 1'b1;
          new_sck_50M = 1'b1;
          new_state = Idle;
`endif
        end else new_state = SendCmd55;
      end

`ifdef SDSC
      SendCmd16: begin
        cmd_index = 6'd16;
        argument = 32'd512;
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckCmd16;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd16: begin
  `ifdef DEBUG
        check_cmd_16_dbg_en = 1'b1;
  `endif
        if (received_data[7:0] != 8'h00) new_state = SendCmd16;
        else begin
          new_initializing = 1'b0;
          initializing_en = 1'b1;
          new_sck_50M = 1'b1;
          new_state = Idle;
        end
      end
`endif

      Idle: begin  // Idle: Espera escrita ou leitura
        if (wr_en) begin
          new_busy = 1'b1;
          busy_en = 1'b1;
          new_state = SendCmd24;
        end else if (rd_en) begin
          new_busy = 1'b1;
          busy_en = 1'b1;
          new_state = SendCmd17;
        end else new_state = state;
      end

      SendCmd24: begin
        cmd_index = 6'd24;
        argument = addr_reg;
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckCmd24;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd24: begin  // Checa R1 do CMD24
`ifdef DEBUG
        check_cmd_24_dbg_en = 1'b1;
`endif
        new_cs = 1'b0;
        sck_en = 1'b0;
        // R1 sem erros -> Escrita do Data Block
        if (received_data[7:0] == 8'h00) begin
          cmd_or_data = 1'b1;
          new_response_type = 2'b00;
          response_type_en = 1'b1;
          new_state_return = CheckWrite;
          state_return_en = 1'b1;
          sender_valid = 1'b1;
          if (~sender_ready) new_state = WaitSendCmd;
          else new_state = state;
        end else begin  // R1 com erros -> Tentar novamente
          new_state = SendCmd24;
        end
      end

      CheckWrite: begin  // Checa escrita de dado
`ifdef DEBUG
        check_write_dbg_en = 1'b1;
`endif
        if (received_data[3:1] == 3'b010) begin
            new_busy = 1'b0;
            busy_en = 1'b1;
            new_state = Idle;
        end
        else new_state = SendCmd24;  // Tentar novamente (TODO: talvez não seja a melhor escolha)
      end

      SendCmd17: begin  // Envia CMD17
        cmd_index = 6'd17;
        argument = addr_reg;
        new_response_type = 2'b00;
        response_type_en = 1'b1;
        new_state_return = CheckCmd17;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) begin
          new_state = WaitSendCmd;
        end else new_state = state;
      end

      CheckCmd17: begin  // Checa R1 do CMD17
`ifdef DEBUG
        check_cmd_17_dbg_en = 1'b1;
`endif
        sck_en = 1'b0;
        new_cs = 1'b0;
        // R1 sem erros -> Leitura do Data Block
        if (received_data[7:0] == 8'h00) begin
          new_response_type = 2'b10;
          new_state_return = CheckRead;
        end else begin  // R1 com erros -> Error Token
          new_response_type = 2'b00;
          new_state_return = CheckErrorToken;
        end
        response_type_en = 1'b1;
        state_return_en = 1'b1;
        receiver_valid = 1'b1;
        if (~receiver_ready) new_state = WaitReceiveCmd;
        else new_state = state;
      end

      CheckRead: begin  // Checa dado lido
          if (~crc_error) begin
              new_busy = 1'b0;
              busy_en = 1'b1;
              new_state = Idle;
          end
        else new_state = SendCmd17;  // Tentar novamente
      end

      CheckErrorToken: begin
`ifdef DEBUG
        check_read_dbg_en = 1'b1;
`endif
        if (received_data[3]) begin
          new_busy = 1'b0;
          busy_en = 1'b1;
          new_state = Idle;  // Endereço inválido
        end
        else new_state = SendCmd17;
      end

      default: begin
      end
    endcase
  end

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      addr_reg <= 32'h0;
      write_data_reg <= 4096'h0;
    end else if ((state == Idle) & (rd_en | wr_en)) begin
      addr_reg <= addr;
      write_data_reg <= write_data;
    end else begin
      addr_reg <= addr_reg;
      write_data_reg <= write_data_reg;
    end
  end

`ifdef DEBUG
  assign sd_controller_state = state;
`endif

endmodule
