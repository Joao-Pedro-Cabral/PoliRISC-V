//
//! @file   sd_controller.v
//! @brief  Implementação de um controlador de SD
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-10
//

`include "macros.vh"

module sd_controller #(
  parameter integer SDSC = 0
)(
    // sinais de sistema
    input wire CLK_I,
    input wire RST_I,

    // interface com a pseudocache
    input wire CYC_I,
    input wire STB_I,
    input wire WE_I,
    input wire [31:0] ADR_I,
    input wire [4095:0] DAT_I,
    output wire [4095:0] DAT_O,

    // interface com o cartão SD
    input wire miso,
    output reg cs,
    output wire sck,
    output wire mosi,

    // sinal de status
    output wire ACK_O
`ifdef DEBUG
    ,
    output wire [4:0] sd_controller_state,
    output wire [1:0] sd_receiver_state,
    output wire sd_sender_state,
    output reg  [7:0] check_cmd_0_dbg,
    output reg  [7:0] check_cmd_8_dbg,
    output reg  [7:0] check_cmd_55_dbg,
    output reg  [7:0] check_cmd_59_dbg,
    output reg  [7:0] check_acmd_41_dbg,
    output reg  [7:0] check_cmd_16_dbg,
    output reg  [7:0] check_cmd_24_dbg,
    output reg  [7:0] check_write_dbg,
    output reg  [15:0] check_cmd_13_dbg,
    output reg  [7:0] check_cmd_17_dbg,
    output reg  [7:0] check_read_dbg,
    output reg  [7:0] check_error_token_dbg,
    output wire crc_error_dbg,
    output wire [15:0] crc16_dbg
`endif
);

  wire wr_en = CYC_I & STB_I & WE_I;
  wire rd_en = CYC_I & STB_I & ~WE_I;

  reg [31:0] addr_reg;
  reg [4095:0] write_data_reg;
  reg new_ack, ack;

  reg [5:0] cmd_index;
  reg [31:0] argument;
  reg cmd_or_data;
  reg [2:0] response_type;
  reg [2:0] new_response_type;
  wire [4095:0] received_data;
  wire response_received;
  wire crc_error;
  reg new_cs;
  reg sck_en;

  reg sender_valid, receiver_valid;
  wire sender_ready, receiver_ready;

  localparam reg [4:0]
    InitBegin = 5'h0,
    WaitSendCmd = 5'h1,
    WaitReceiveCmd = 5'h2,
    SendCmd0 = 5'h3,
    CheckCmd0 = 5'h4,
    SendCmd8 = 5'h5,
    CheckCmd8 = 5'h6,
    SendCmd59 = 5'h7,
    CheckCmd59 = 5'h8,
    SendCmd55 = 5'h9,
    CheckCmd55 = 5'hA,
    SendAcmd41 = 5'hB,
    CheckAcmd41 = 5'hC,
    SendCmd16 = 5'hD,
    CheckCmd16 = 5'hE,
    Idle = 5'hF,
    SendCmd17 = 5'h10,
    CheckCmd17 = 5'h11,
    SendCmd24 = 5'h12,
    CheckCmd24 = 5'h13,
    CheckRead = 5'h14,
    CheckWrite = 5'h15,
    SendCmd13 = 5'h16,
    CheckCmd13 = 5'h17,
    CheckErrorToken = 5'h18,
    Final = 5'h1F;

  reg [4:0]
      new_state,
      state = InitBegin,
      state_return = InitBegin,
      new_state_return;
  reg state_return_en, response_type_en;

  sd_sender sender (
      .clock(CLK_I),
      .reset(RST_I),
      .cmd_index(cmd_index),
      .argument(argument),
      .cmd_or_data(cmd_or_data),
      .ready(sender_ready),
      .valid(sender_valid),
      .data(write_data_reg),
      .mosi(mosi)
`ifdef DEBUG
      ,
      .sender_state(sd_sender_state),
      .crc16_dbg(crc16_dbg)
`endif
  );

  sd_receiver receiver (
      .clock(CLK_I),
      .reset(RST_I),
      .response_type((state != CheckCmd17) ? response_type : new_response_type),
      .received_data(received_data),
      .ready(receiver_ready),
      .valid(receiver_valid),
      .crc_error(crc_error),
      .miso(miso)
`ifdef DEBUG
      ,
      .receiver_state(sd_receiver_state)
`endif
  );

`ifdef DEBUG
  reg
      check_cmd_0_dbg_en,
      check_cmd_8_dbg_en,
      check_cmd_55_dbg_en,
      check_cmd_59_dbg_en,
      check_acmd_41_dbg_en,
      check_cmd_16_dbg_en,
      check_cmd_24_dbg_en,
      check_write_dbg_en,
      check_cmd_13_dbg_en,
      check_cmd_17_dbg_en,
      check_read_dbg_en,
      check_error_token_dbg_en,
      clear_dbg;
`endif

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) begin
      cs    <= 1'b1;
      state <= InitBegin;
      state_return <= InitBegin;
      response_type <= 3'b000;
      ack <= 1'b0;
`ifdef DEBUG
      check_cmd_0_dbg <= 8'h00;
      check_cmd_8_dbg <= 8'd8;
      check_cmd_55_dbg <= 8'd55;
      check_cmd_59_dbg <= 8'd59;
      check_acmd_41_dbg <= 8'd41;
      check_cmd_16_dbg <= 8'd16;
      check_cmd_24_dbg <= 8'd24;
      check_write_dbg <= 8'd10;
      check_cmd_13_dbg <= 16'd13;
      check_cmd_17_dbg <= 8'd17;
      check_read_dbg <= 8'b11110000;
      check_error_token_dbg <= 8'b10101010;
`endif
    end else begin
      cs    <= new_cs;
      state <= new_state;
      if (state_return_en) state_return <= new_state_return;
      else state_return <= state_return;
      if (response_type_en) response_type <= new_response_type;
      else response_type <= response_type;
      if (ack) ack <= 1'b0;
      else if (new_ack) ack <= 1'b1;
      else ack <= ack;
`ifdef DEBUG
      if (check_cmd_0_dbg_en) check_cmd_0_dbg <= received_data[7:0];
      if (check_cmd_8_dbg_en) check_cmd_8_dbg <= received_data[39:32];
      if (check_cmd_55_dbg_en) check_cmd_55_dbg <= received_data[7:0];
      if (check_cmd_59_dbg_en) check_cmd_59_dbg <= received_data[7:0];
      if (check_acmd_41_dbg_en) check_acmd_41_dbg <= received_data[7:0];
      if (check_cmd_16_dbg_en) check_cmd_16_dbg <= received_data[7:0];
      if (check_cmd_24_dbg_en) check_cmd_24_dbg <= received_data[7:0];
      else if (clear_dbg) check_cmd_24_dbg <= 8'd24;
      if (check_write_dbg_en) check_write_dbg <= received_data[7:0];
      else if (clear_dbg) check_write_dbg <= 8'd10;
      if (check_cmd_13_dbg_en) check_cmd_13_dbg <= received_data[15:0];
      else if (clear_dbg) check_cmd_13_dbg <= 16'd13;
      if (check_cmd_17_dbg_en) check_cmd_17_dbg <= received_data[7:0];
      else if (clear_dbg) check_cmd_17_dbg <= 8'd17;
      if (check_read_dbg_en) check_read_dbg <= {7'b0, crc_error};
      else if (clear_dbg) check_read_dbg <= 8'b11110000;
      if (check_error_token_dbg_en) check_error_token_dbg <= received_data[7:0];
      else if (clear_dbg) check_error_token_dbg <= 8'b10101010;
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
      new_response_type = 3'b000;
      new_state = InitBegin;
      new_state_return = InitBegin;
      state_return_en = 1'b0;
      response_type_en = 1'b0;
      new_ack = 1'b0;
`ifdef DEBUG
      check_cmd_0_dbg_en = 1'b0;
      check_cmd_8_dbg_en = 1'b0;
      check_cmd_55_dbg_en = 1'b0;
      check_cmd_59_dbg_en = 1'b0;
      check_acmd_41_dbg_en = 1'b0;
      check_cmd_16_dbg_en = 1'b0;
      check_cmd_24_dbg_en = 1'b0;
      check_write_dbg_en = 1'b0;
      check_cmd_13_dbg_en = 1'b0;
      check_cmd_17_dbg_en = 1'b0;
      check_read_dbg_en = 1'b0;
      check_error_token_dbg_en = 1'b0;
      clear_dbg = 1'b0;
`endif
    end
  endtask

  always @(*) begin
    reset_signals;
    case(state)
      InitBegin: begin
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
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd0;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
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
        new_response_type = 3'b001;
        response_type_en = 1'b1;
        new_state_return = CheckCmd8;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd8: begin  // Checa check pattern e se a tensão é suportada
`ifdef DEBUG
        check_cmd_8_dbg_en = 1'b1;
`endif
        if (received_data[39:32] == 8'h05) new_state = SendCmd59;
        else if (received_data[7:0] != 8'hAA) new_state = SendCmd8;
        else if (received_data[11:8] != 4'h1) new_state = InitBegin;
        else new_state = SendCmd59;
      end

      SendCmd59: begin
        cmd_index = 6'd59;
        argument = 32'h00000001;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd59;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd59: begin  // Checa se ainda está em Idle
`ifdef DEBUG
        check_cmd_59_dbg_en = 1'b1;
`endif
        if (received_data[7:0] == 8'h01) new_state = SendCmd55;
        else new_state = SendCmd59;
      end

      SendCmd55: begin  // Envia CMD55 -> Deve proceder ACMD*
        cmd_index = 6'd55;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd55;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
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
        if(SDSC) argument = 32'h00000000;
        else argument = 32'h40000000;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckAcmd41;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckAcmd41: begin  // Checa ACMD41 -> Até sair do Idle
`ifdef DEBUG
        check_acmd_41_dbg_en = 1'b1;
`endif
        if (received_data[7:0] == 8'h00) begin
          if(SDSC) new_state = SendCmd16;
          else begin
            new_cs = 1'b0;
            new_state = Idle;
          end
        end else new_state = SendCmd55;
      end

      SendCmd16: begin
        cmd_index = 6'd16;
        argument = 32'd512;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd16;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd16: begin
  `ifdef DEBUG
        check_cmd_16_dbg_en = 1'b1;
  `endif
        if (received_data[7:0] != 8'h00) new_state = SendCmd16;
        else begin
          new_cs = 1'b0;
          new_state = Idle;
        end
      end

      Idle: begin  // Idle: Espera escrita ou leitura
        new_cs = 1'b0;
        if (~miso) begin
          new_state = state;
        end else if (wr_en) begin
          new_state = SendCmd24;
        end else if (rd_en) begin
          new_state = SendCmd17;
        end else new_state = state;
      end

      SendCmd24: begin
      `ifdef DEBUG
        clear_dbg = 1'b1;
      `endif
        cmd_index = 6'd24;
        argument = addr_reg;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd24;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd24: begin  // Checa R1 do CMD24
`ifdef DEBUG
        check_cmd_24_dbg_en = 1'b1;
`endif
        new_cs = 1'b0;
        cmd_or_data = 1'b1;
        new_response_type = 3'b010;
        response_type_en = 1'b1;
        new_state_return = CheckWrite;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckWrite: begin  // Checa escrita de dado
`ifdef DEBUG
        check_write_dbg_en = 1'b1;
`endif
        new_cs = 1'b0;
        new_ack = 1'b1;
        new_state = SendCmd13;
      end

      SendCmd13: begin
        cmd_index = 6'd13;
        new_response_type = 3'b100;
        response_type_en = 1'b1;
        new_state_return = CheckCmd13;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd13: begin // Nada a checar -> Apenas depuração
`ifdef DEBUG
        check_cmd_13_dbg_en = 1'b1;
`endif
        new_state = Idle;
      end

      SendCmd17: begin  // Envia CMD17
        cmd_index = 6'd17;
        argument = addr_reg;
        new_response_type = 3'b000;
        response_type_en = 1'b1;
        new_state_return = CheckCmd17;
        state_return_en = 1'b1;
        sender_valid = 1'b1;
        new_cs = 1'b0;
        if (~sender_ready) new_state = WaitSendCmd;
        else new_state = state;
      end

      CheckCmd17: begin  // Checa R1 do CMD17
`ifdef DEBUG
        check_cmd_17_dbg_en = 1'b1;
`endif
        sck_en = 1'b0;
        new_cs = 1'b0;
        // R1 sem erros -> Leitura do Data Block
        if (received_data[7:0] == 8'h00) begin
          new_response_type = 3'b011;
          new_state_return = CheckRead;
        end else begin  // R1 com erros -> Error Token
          new_response_type = 3'b000;
          new_state_return = CheckErrorToken;
        end
        response_type_en = 1'b1;
        state_return_en = 1'b1;
        receiver_valid = 1'b1;
        if (~receiver_ready) new_state = WaitReceiveCmd;
        else new_state = state;
      end

      CheckRead: begin  // Checa dado lido
`ifdef DEBUG
        check_read_dbg_en = 1'b1;
`endif
        new_cs = 1'b0;
        new_ack = 1'b1;
        new_state = Final;
      end

      CheckErrorToken: begin
`ifdef DEBUG
        check_error_token_dbg_en = 1'b1;
`endif
        new_cs = 1'b0;
        new_ack = 1'b1;
        new_state = Final;
      end

      Final: begin // wait for ACK falling edge
        new_state = Idle;
      end

      default: begin
      end
    endcase
  end

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) begin
      addr_reg <= 32'h0;
      write_data_reg <= 4096'h0;
    end else if ((state == Idle) & (rd_en | wr_en)) begin
      addr_reg <= ADR_I;
      write_data_reg <= DAT_I;
    end else begin
      addr_reg <= addr_reg;
      write_data_reg <= write_data_reg;
    end
  end

`ifdef DEBUG
  assign sd_controller_state = state;
  assign crc_error_dbg = crc_error;
`endif

  assign DAT_O = received_data;
  assign ACK_O = ack;

  assign sck   = sck_en & ~CLK_I;

endmodule
