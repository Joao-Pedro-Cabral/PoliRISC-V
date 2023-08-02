//
//! @file   sd_controller.v
//! @brief  Implementação de um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-10
//

`define SDSC
/* `undef SDSC */

module sd_controller (
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
    output reg busy,

    // debug
    output wire [12:0] bits_received_dbg,
    output reg  [ 7:0] check_cmd_0_dbg,
    output reg  [ 7:0] check_cmd_8_dbg,
    output reg  [ 7:0] check_cmd_55_dbg,
    output reg  [ 7:0] check_acmd_41_dbg,
    output reg  [ 7:0] check_cmd_16_dbg
);

  wire clock;

  reg [5:0] cmd_index;
  reg [31:0] argument;
  reg cmd_or_data;
  wire sending_cmd;
  reg cmd_valid;
  reg [1:0] response_type;
  reg new_response_type;
  wire [4095:0] received_data;
  wire data_valid;
  wire crc_error;
  reg end_op;
  reg new_cs;
  reg new_sck_50M;
  reg sck_50M;
  reg sck_en;

  sd_sender sender (
      .clock(clock),
      .reset(reset),
      .cmd_index(cmd_index),
      .argument(argument),
      .data(write_data),
      .cmd_or_data(cmd_or_data),
      .cmd_valid(cmd_valid),
      // interface com o cartão SD
      .mosi(mosi),
      .sending_cmd(sending_cmd)
  );

  sd_receiver receiver (
      .clock(clock),
      .reset(reset),
      .response_type(response_type),
      .new_response_type(new_response_type),
      .received_data(received_data),
      .data_valid(data_valid),
      .crc_error(crc_error),
      .miso(miso),
      .bits_received_dbg(bits_received_dbg)
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
    Idle = 5'hB,
    SendCmd17 = 5'hC,
    CheckCmd17 = 5'hD,
    SendCmd24 = 5'hE,
    CheckCmd24 = 5'hF,
    CheckRead = 5'h10,
    CheckWrite = 5'h11,
    CheckErrorToken = 5'h12;
`ifdef SDSC
  localparam reg [4:0] SendCmd16 = 5'h1E, CheckCmd16 = 5'h1F;
`endif

  reg [4:0] new_state, state = InitBegin, state_return = InitBegin, new_state_return;
  reg state_return_en;

  // Antes do Idle: Inicialização (400KHz), Após: Leitura(50MHz)
  assign clock = sck_50M ? clock_50M : clock_400K;
  assign sck   = sck_en & ~clock;

  reg
      check_cmd_0_dbg_en,
      check_cmd_8_dbg_en,
      check_cmd_55_dbg_en,
      check_acmd_41_dbg_en,
      check_cmd_16_dbg_en;

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      cs    <= 1'b1;
      sck_50M <= 1'b0;
      state <= InitBegin;
      state_return <= InitBegin;
      check_cmd_0_dbg <= 8'h00;
      check_cmd_8_dbg <= 8'h00;
      check_cmd_55_dbg <= 8'h00;
      check_acmd_41_dbg <= 8'h00;
      check_cmd_16_dbg <= 8'h00;
    end else begin
      cs    <= new_cs;
      state <= new_state;
      if (state_return_en) state_return <= new_state_return;
      else state_return <= state_return;
      if (new_sck_50M) sck_50M <= 1'b1;
      else sck_50M <= sck_50M;
      if (check_cmd_0_dbg_en) check_cmd_0_dbg <= received_data[7:0];
      if (check_cmd_8_dbg_en) check_cmd_8_dbg <= received_data[39:32];
      if (check_cmd_55_dbg_en) check_cmd_55_dbg <= received_data[7:0];
      if (check_acmd_41_dbg_en) check_acmd_41_dbg <= received_data[7:0];
      if (check_cmd_16_dbg_en) check_cmd_16_dbg <= received_data[7:0];
    end
  end


  task reset_signals;
    begin
      sck_en = 1'b1;
      new_cs = 1'b1;
      cmd_index = 6'b000000;
      argument = 32'b0;
      cmd_or_data = 1'b0;
      cmd_valid = 1'b0;
      response_type = 2'b00;
      new_response_type = 1'b0;
      new_sck_50M = 1'b0;
      new_state = InitBegin;
      new_state_return = InitBegin;
      state_return_en = 1'b0;
      end_op = 1'b0;
      check_cmd_0_dbg_en = 1'b0;
      check_cmd_8_dbg_en = 1'b0;
      check_cmd_55_dbg_en = 1'b0;
      check_acmd_41_dbg_en = 1'b0;
      check_cmd_16_dbg_en = 1'b0;
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
        if (data_valid | crc_error) new_state = state_return;
        else new_state = WaitReceiveCmd;
      end

      SendCmd0: begin  // Enviar CMD0
        new_cs = 1'b0;
        cmd_index = 6'h00;
        argument = 32'b0;
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd0;
        state_return_en = 1'b1;
      end

      CheckCmd0: begin  // Checa se cartão SD está InitBegin e sem erros
        check_cmd_0_dbg_en = 1'b1;
        if (received_data[7:0] == 8'h01) new_state = SendCmd8;
        else new_state = SendCmd0;
      end

      SendCmd8: begin  // Enviar CMD8
        new_cs = 1'b0;
        cmd_index = 6'h08;
        argument = 32'h000001AA;
        cmd_valid = 1'b1;
        response_type = 2'b01;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd8;
        state_return_en = 1'b1;
      end

      CheckCmd8: begin  // Checa check pattern e se a tensão é suportada
        check_cmd_8_dbg_en = 1'b1;
        if (received_data[39:32] == 8'h05) new_state = SendCmd55;
        else if (received_data[7:0] != 8'hAA) new_state = SendCmd8;
        else if (received_data[11:8] != 4'h1) new_state = InitBegin;
        else new_state = SendCmd55;
      end

      SendCmd55: begin  // Envia CMD55 -> Deve proceder ACMD*
        new_cs = 1'b0;
        cmd_index = 6'd55;
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd55;
        state_return_en = 1'b1;
      end

      CheckCmd55: begin  // Checa se ainda está em Idle
        check_cmd_55_dbg_en = 1'b1;
        if (received_data[7:0] == 8'h01) new_state = SendAcmd41;
        else new_state = SendCmd55;
      end

      SendAcmd41: begin  // Envia ACMD41
        new_cs = 1'b0;
        cmd_index = 6'd41;
`ifdef SDSC
        argument = 32'h00000000;
`else
        argument = 32'h40000000;
`endif
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckAcmd41;
        state_return_en = 1'b1;
      end

      CheckAcmd41: begin  // Checa ACMD41 -> Até sair do Idle
        check_acmd_41_dbg_en = 1'b1;
        if (received_data[7:0] == 8'h00) begin
          new_sck_50M = 1'b1;
`ifdef SDSC
          new_state = SendCmd16;
`else
          new_state = Idle;
`endif
        end else new_state = SendCmd55;
      end

`ifdef SDSC
      SendCmd16: begin
        new_cs = 1'b0;
        cmd_index = 6'd16;
        argument = 32'd512;
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd16;
        state_return_en = 1'b1;
      end

      CheckCmd16: begin
        check_cmd_16_dbg_en = 1'b1;
        if (received_data[7:0] != 8'h00) new_state = SendCmd16;
        else new_state = Idle;
      end
`endif

      Idle: begin  // Idle: Espera escrita ou leitura
        if (!miso) begin  // Cartão não terminou a escrita
          new_cs = 1'b0;
          new_state = Idle;
        end else if (wr_en) begin
          new_cs = 1'b0;
          new_state = SendCmd24;
        end else if (rd_en) begin
          new_cs = 1'b0;
          new_state = SendCmd17;
        end else new_state = Idle;
      end

      SendCmd24: begin
        new_cs = 1'b0;
        cmd_index = 6'd24;
        argument = addr;
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd24;
        state_return_en = 1'b1;
      end

      CheckCmd24: begin  // Checa R1 do CMD24
        sck_en = 1'b0;
        new_cs = 1'b0;
        // R1 sem erros -> Escrita do Data Block
        if (received_data[7:0] == 8'h00) begin
          cmd_or_data = 1'b1;
          cmd_valid = 1'b1;
          new_response_type = 1'b1;
          new_state = WaitSendCmd;
          new_state_return = CheckWrite;
          state_return_en = 1'b1;
        end else begin  // R1 com erros -> Tentar novamente
          new_state = SendCmd24;
        end
      end

      CheckWrite: begin  // Checa escrita de dado
        new_cs = 1'b0;
        if (received_data[3:1] == 3'b010) begin
          end_op    = 1'b1;
          new_state = Idle;
        end else begin
          new_state = SendCmd24;  // Tentar novamente (TODO: talvez não seja a melhor escolha)
        end
      end

      SendCmd17: begin  // Envia CMD17
        new_cs = 1'b0;
        cmd_index = 6'd17;
        argument = addr;
        cmd_valid = 1'b1;
        new_response_type = 1'b1;
        new_state = WaitSendCmd;
        new_state_return = CheckCmd17;
        state_return_en = 1'b1;
      end

      CheckCmd17: begin  // Checa R1 do CMD17
        sck_en = 1'b0;
        new_cs = 1'b0;
        new_response_type = 1'b1;
        state_return_en = 1'b1;
        // R1 sem erros -> Leitura do Data Block
        if (received_data[7:0] == 8'h00) begin
          response_type = 2'b10;
          new_state = WaitReceiveCmd;
          new_state_return = CheckRead;
        end else begin  // R1 com erros -> Error Token
          new_state = WaitReceiveCmd;
          new_state_return = CheckErrorToken;
        end
      end

      CheckRead: begin  // Checa dado lido
        if (data_valid) begin
          end_op = 1'b1;
          new_state = Idle;
        end else new_state = SendCmd17;  // Tentar novamente
      end

      CheckErrorToken: begin
        if (received_data[3]) new_state = Idle;  // Endereço inválido
        else new_state = SendCmd17;
      end

      default: begin
      end
    endcase
  end

  always @(posedge clock) begin
    if (reset | end_op) busy <= 1'b0;
    else if (rd_en | wr_en) busy <= 1'b1;
    else busy <= busy;
  end

endmodule
