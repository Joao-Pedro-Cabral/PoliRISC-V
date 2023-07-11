module sd_model (
    input sck,
    input cs,
    input mosi,
    input [31:0] expected_addr,

    output miso,
    output reg cmd_error

);

  function automatic reg [6:0] CRC7(input reg [39:0] data);
    integer j;
    reg [6:0] crc;
    reg do_invert;
    begin
      crc = 0;
      for (i = 39; i >= 0; i = i - 1) begin
        do_invert = crc[6] ^ data[i];
        crc[6:4] = crc[5:3];
        crc[3] = crc[2] ^ do_invert;
        crc[2:1] = crc[1:0];
        crc[0] = do_invert;
      end
      CRC7 = crc;
    end
  endfunction

  function automatic reg [15:0] CRC16(input reg [4095:0] data);
    integer j;
    reg [15:0] crc;
    reg do_invert;
    begin
      crc = 0;
      for (i = 4095; i >= 0; i = i - 1) begin
        do_invert = crc[15] ^ data[i];
        crc[15:13] = crc[14:12];
        crc[12] = crc[11] ^ do_invert;
        crc[11:6] = crc[10:5];
        crc[5] = crc[4] ^ do_invert;
        crc[4:1] = crc[3:0];
        crc[0] = do_invert;
      end
      CRC16 = crc;
    end
  endfunction

  localparam reg [47:0] ExpectedCmd0 = {8'h40, 32'h00000000, 8'h95};
  localparam reg [47:0] ExpectedCmd8 = {8'h48, 32'h000001AA, 8'h87};
  localparam reg [47:0] ExpectedCmd55 = {8'h77, 32'h00000000, 8'h65};
  localparam reg [47:0] ExpectedAcmd41 = {8'h69, 32'h40000000, 8'h77};
  reg [47:0] ExpectedCmd17;

  localparam reg [7:0] Cmd0Response = 8'h01;
  localparam reg [39:0] Cmd8Response = {8'h01, 4'h2, 16'h0000, 4'h1, 8'hAA};
  localparam reg [7:0] Cmd55Response = 8'h01;
  localparam reg [7:0] Acmd41IdleResponse = 8'h01;
  localparam reg [7:0] Acmd41Response = 8'h00;
  localparam reg [7:0] Cmd17Response = 8'h00;
  localparam reg [7:0] ErrorTokenResponse = 8'h0F;
  localparam reg [7:0] R1ErrorResponse = 8'h74;

  localparam reg [7:0]
    Idle = 8'h0,
    ReceivingCmd = 8'h01,
    DecodeCmd = 8'h02,
    CheckCmd = 8'h03,
    ReturnCmd0 = 8'h04,
    ReturnCmd8 = 8'h05,
    ReturnCmd55 = 8'h06,
    ReturnAcmd41 = 8'h07,
    ReturnCmd17 = 8'h08,
    SendDataBlock = 8'h09,
    SendErrorToken = 8'h0A,
    CmdError = 8'hFF;
  reg [3:0] state = Idle, new_state = Idle, return_state = Idle, new_return_state = Idle;

  reg [12:0] bit_counter = 13'd47, new_bit_counter = 13'd47;

  reg [47:0] cmd, expected_cmd, new_expected_cmd;
  reg set_cmd, acmd41_idle_flag = 1'b0, new_acmd41_idle_flag;

  always @(posedge sck) begin
    if (~cs) begin
      state        <= new_state;
      return_state <= new_return_state;
      bit_counter  <= new_bit_counter;
      if (set_cmd) cmd[bit_counter] <= mosi;
      expected_cmd     <= new_expected_cmd;
      acmd41_idle_flag <= new_acmd41_idle_flag;
    end else begin
      state            <= state;
      return_state     <= return_state;
      bit_counter      <= bit_counter;
      expected_cmd     <= expected_cmd;
      acmd41_idle_flag <= acmd41_idle_flag;
    end
  end

  reg miso_reg;
  wire [5:0] index = cmd[45:40];
  wire [31:0] argument = cmd[39:8];
  wire [6:0] crc7 = cmd[7:1];
  reg [6:0] crc16;
  reg random_error_flag;

  always @(*) begin
    miso_reg            = 1'b1;
    cmd_error           = 1'b0;
    set_cmd             = 1'b0;
    new_bit_counter     = bit_counter;
    new_state           = state;
    new_return_state    = return_state;
    new_expected_cmd    = expected_cmd;
    ExpectedCmd17[47:8] = {1'b0, 1'b1, 6'o21, expected_addr};
    ExpectedCmd17[0]    = 1'b1;

    case (state)
      Idle: begin
        if (~mosi) begin
          new_state       = ReceivingCmd;
          set_cmd         = 1'b1;
          new_bit_counter = 13'd46;
        end
      end

      ReceivingCmd: begin
        if (bit_counter) begin
          set_cmd = 1'b1;
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = DecodeCmd;
      end

      DecodeCmd: begin
        new_state = CheckCmd;
        if (index == 6'o0) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd0;
          new_return_state = ReturnCmd0;
        end else if (index == 6'o10) begin
          new_bit_counter  = 13'd40;
          new_expected_cmd = ExpectedCmd8;
          new_return_state = ReturnCmd8;
        end else if (index == 6'o67) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd55;
          new_return_state = ReturnCmd55;
        end else if (index == 6'o51) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedAcmd41;
          new_return_state = acmd41_idle_flag ? ReturnAcmd41 : ReturnAcmd41Idle;
        end else if (index == 6'o21) begin
          new_bit_counter = 13'd8;
          ExpectedCmd17[7:1] = CRC7({1'b0, 1'b1, index, argument});
          new_expected_cmd = ExpectedCmd17;
          new_return_state = ReturnCmd17;
          random_error_flag = $urandom;
        end else new_state = CmdError;
      end

      CheckCmd: begin
        if (cmd != expected_cmd) new_state = CmdError;
        else new_state = return_state;
      end

      ReturnCmd0: begin
        if (bit_counter) begin
          miso_reg        = Cmd0Response[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd8: begin
        if (bit_counter) begin
          miso_reg        = Cmd8Response[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd55: begin
        if (bit_counter) begin
          miso_reg        = Cmd55Response[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnAcmd41Idle: begin
        if (bit_counter) begin
          miso_reg        = Acmd41IdleResponse[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else begin
          new_state = Idle;
          new_acmd41_idle_flag = 1'b1;
        end
      end

      ReturnAcmd41: begin
        if (bit_counter) begin
          miso_reg        = Acmd41Response[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd17: begin
        if (bit_counter) begin
          if (random_error_flag) begin
            miso_reg        = R1ErrorResponse[bitcounter];
            new_bit_counter = bit_counter - 6'o01;
          end else begin
            miso_reg        = Cmd17Response[bit_counter];
            new_bit_counter = bit_counter - 6'o01;
          end
        end else begin
          if (random_error_flag) begin
            new_bit_counter = 13'd8;
            new_state = SendErrorToken;
          end else begin
            new_bit_counter = 13'd4113;
            new_state = SendDataBlock;
          end
        end
      end

      SendDataBlock: begin
        if (bit_counter > 16) begin
          miso_reg        = data_block[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else if (bit_counter) begin
          crc16           = CRC16(data_block);
          miso_reg        = crc16[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      SendErrorToken: begin
        if (bit_counter) begin
          miso_reg        = ErrorTokenResponse[bit_counter];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      CmdError: begin
        cmd_error = 1'b1;
        new_state = state;
      end

      default: begin
        new_state = Idle;
      end
    endcase

  end

  assign miso = ~cs ? miso_reg : 1'bz;

endmodule
