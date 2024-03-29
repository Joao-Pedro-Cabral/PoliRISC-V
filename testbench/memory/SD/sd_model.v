
`include "macros.vh"

module sd_model #(
    parameter integer SDSC = 0
) (
    input wire sck,
    input wire cs,
    input wire mosi,
    input wire [31:0] expected_addr,

    output wire miso,
    output reg  cmd_error

);

  function automatic reg [6:0] CRC7(input reg [39:0] data);
    integer i;
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
    integer i;
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
  localparam reg [47:0] ExpectedCmd59 = {8'h7B, 32'h00000001, 8'h83};
  localparam reg [47:0] ExpectedCmd55 = {8'h77, 32'h00000000, 8'h65};
  localparam reg [47:0] ExpectedAcmd41 = {8'h69, 32'h40000000, 8'h77};
  localparam reg [47:0] ExpectedAcmd41SDSC = {8'h69, 32'h00000000, 8'hE5};
  localparam reg [47:0] ExpectedCmd16 = {8'h50, 32'h200, 8'h15};
  localparam reg [47:0] ExpectedCmd13 = {8'h4D, 32'h00000000, 8'h0D};
  reg [47:0] ExpectedCmd17;
  reg [47:0] ExpectedCmd24;
  reg [15:0] crc16_calc;

  localparam reg [7:0] Cmd0Response = 8'h01;
  localparam reg [39:0] Cmd8Response = {8'h01, 4'h2, 16'h0000, 4'h1, 8'hAA};
  localparam reg [7:0] Cmd59Response = 8'h01;
  localparam reg [7:0] Cmd55Response = 8'h01;
  localparam reg [7:0] Acmd41IdleResponse = 8'h01;
  localparam reg [7:0] Acmd41Response = 8'h00;
  localparam reg [7:0] Cmd16Response = 8'h00;
  localparam reg [7:0] Cmd24Response = 8'h00;
  localparam reg [7:0] Cmd13Response = 16'h0000;
  localparam reg [7:0] Cmd17Response = 8'h00;
  localparam reg [7:0] Cmd17ErrorResponse = {1'b0, 7'h74};
  localparam reg [7:0] ErrorTokenResponse = 8'h0F;
  localparam reg [7:0] WriteSuccessfulResponse = {1'b0, 2'b0, 1'b0, 3'b010, 1'b1};
  localparam reg [7:0] WriteErrorResponse = {1'b0, 2'b0, 1'b0, 3'b101, 1'b1};

  localparam reg [4:0]
    Idle = 5'h0,
    ReceivingCmd = 5'h1,
    DecodeCmd = 5'h2,
    CheckCmd = 5'h3,
    ReturnCmd0 = 5'h4,
    ReturnCmd8 = 5'h5,
    ReturnCmd59 = 5'h6,
    ReturnCmd55 = 5'h7,
    ReturnAcmd41Idle = 5'h8,
    ReturnAcmd41 = 5'h9,
    ReturnCmd16 = 5'hA,
    ReturnCmd13 = 5'hB,
    SendDataBlock = 5'hC,
    SendErrorToken = 5'hD,
    ReturnCmd17 = 5'hE,
    ReturnCmd24 = 5'hF,
    ReceiveDataBlock = 5'h10,
    CheckWrite = 5'h11,
    WriteError = 5'h12,
    WriteSuccessful = 5'h13,
    Busy = 5'h14,
    CmdError = 5'h1F;

  reg [4:0] state = Idle, new_state = Idle, return_state = Idle, new_return_state = Idle;

  reg [12:0] bit_counter = 13'd47, new_bit_counter = 13'd47;

  reg [47:0] cmd, expected_cmd, new_expected_cmd;
  reg set_cmd, acmd41_idle_flag = 1'b0;
  reg random_error_flag = 1'b0;
  reg [2:0] random_busy_cycles = 3'b0;  // só três bits para facilitar o debugging
  reg [4095:0] data_block;
  reg [4095:0] received_data_block;
  reg receive_data_block;
  reg [15:0] crc16;
  reg receive_crc16;
  reg [15:0] received_crc16;
  reg change_crc;

  reg miso_reg;
  wire [5:0] index = cmd[45:40];
  wire [31:0] argument = cmd[39:8];
  wire [6:0] crc7 = cmd[7:1];

  always @(posedge sck) begin
    if (~cs) begin
      state        <= new_state;
      return_state <= new_return_state;
      bit_counter  <= new_bit_counter;
      if (set_cmd) cmd[bit_counter] <= mosi;
      expected_cmd <= new_expected_cmd;
    end else begin
      state        <= state;
      return_state <= return_state;
      bit_counter  <= bit_counter;
      expected_cmd <= expected_cmd;
    end
  end

  // Determinar ACMD41 Idle Flag
  always @(posedge sck) begin
    if (acmd41_idle_flag == 1'b0 && state == ReturnAcmd41Idle) acmd41_idle_flag <= 1'b1;
    else acmd41_idle_flag <= acmd41_idle_flag;
  end

  // Determinar Random Error Flag
  always @(posedge sck) begin
    if ((state == DecodeCmd && (index == 6'o21 || index == 6'o30)))
      random_error_flag <= $urandom & $urandom;
    else random_error_flag <= random_error_flag;
  end

  // Determinar Random Busy Cycles
  always @(posedge sck) begin
    if (state == CheckWrite) random_busy_cycles <= $urandom;
    else random_busy_cycles <= random_busy_cycles;
  end

  // Determinar data block
  integer j;
  always @(posedge sck) begin
    if (state == ReturnCmd17 && bit_counter == 0 && random_error_flag == 1'b0) begin
      for (j = 0; j < 128; j = j + 1) begin
        data_block[32*j+:32] <= $urandom;
      end
      change_crc <= 1'b1;
    end else begin
      data_block <= data_block;
      change_crc <= 1'b0;
    end
  end

  // Atualizar crc no ciclo seguinte a atualização do data block
  always @(posedge sck) begin
    if (change_crc) crc16 <= CRC16(data_block);
    else crc16 <= crc16;
  end

  // recebe dados ou crc16 do comando de escrita
  always @(posedge sck) begin
    if (receive_data_block) received_data_block[bit_counter-17] <= mosi;
    if (receive_crc16) received_crc16[bit_counter-1] <= mosi;
  end

  always @(*) begin
    miso_reg            = 1'b1;
    cmd_error           = 1'b0;
    set_cmd             = 1'b0;
    new_bit_counter     = bit_counter;
    new_state           = state;
    new_return_state    = return_state;
    new_expected_cmd    = expected_cmd;
    ExpectedCmd17[47:8] = {1'b0, 1'b1, 6'o21, expected_addr};
    ExpectedCmd17[7:1]  = CRC7(ExpectedCmd17[47:8]);
    ExpectedCmd17[0]    = 1'b1;
    ExpectedCmd24[47:8] = {1'b0, 1'b1, 6'o30, expected_addr};
    ExpectedCmd24[7:1]  = CRC7(ExpectedCmd24[47:8]);
    ExpectedCmd24[0]    = 1'b1;
    receive_data_block  = 1'b0;
    receive_crc16       = 1'b0;
    crc16_calc          = 16'b0;

    case (state)
      Idle: begin
        if (~mosi) begin
          new_state       = ReceivingCmd;
          set_cmd         = 1'b1;
          new_bit_counter = 13'd46;
        end
      end

      ReceivingCmd: begin
        set_cmd = 1'b1;
        if (bit_counter) new_bit_counter = bit_counter - 6'o01;
        else new_state = DecodeCmd;
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
        end else if (index == 6'o73) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd59;
          new_return_state = ReturnCmd59;
        end else if (index == 6'o67) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd55;
          new_return_state = ReturnCmd55;
        end else if (index == 6'o51) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = SDSC ? ExpectedAcmd41SDSC : ExpectedAcmd41;
          new_return_state = acmd41_idle_flag ? ReturnAcmd41 : ReturnAcmd41Idle;
        end else if (index == 6'o20) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd16;
          new_return_state = ReturnCmd16;
        end else if (index == 6'o15) begin
          new_bit_counter  = 13'd16;
          new_expected_cmd = ExpectedCmd13;
          new_return_state = ReturnCmd13;
        end else if (index == 6'o21) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd17;
          new_return_state = ReturnCmd17;
        end else if (index == 6'o30) begin
          new_bit_counter  = 13'd8;
          new_expected_cmd = ExpectedCmd24;
          new_return_state = ReturnCmd24;
        end else new_state = CmdError;
      end

      CheckCmd: begin
        if (cmd != expected_cmd) new_state = CmdError;
        else new_state = return_state;
      end

      ReturnCmd0: begin
        if (bit_counter) begin
          miso_reg        = Cmd0Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd8: begin
        if (bit_counter) begin
          miso_reg        = Cmd8Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd59: begin
        if (bit_counter) begin
          miso_reg        = Cmd59Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd55: begin
        if (bit_counter) begin
          miso_reg        = Cmd55Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnAcmd41Idle: begin
        if (bit_counter) begin
          miso_reg        = Acmd41IdleResponse[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnAcmd41: begin
        if (bit_counter) begin
          miso_reg        = Acmd41Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd16: begin
        if (bit_counter) begin
          miso_reg        = Cmd16Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd13: begin
        if (bit_counter) begin
          miso_reg        = Cmd13Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd17: begin
        if (bit_counter) begin
          if (random_error_flag) begin
            miso_reg        = Cmd17ErrorResponse[bit_counter-1];
            new_bit_counter = bit_counter - 6'o01;
          end else begin
            miso_reg        = Cmd17Response[bit_counter-1];
            new_bit_counter = bit_counter - 6'o01;
          end
        end else begin
          if (random_error_flag) begin
            new_bit_counter = 13'd8;
            new_state = SendErrorToken;
          end else begin
            new_bit_counter = 13'd4120;
            new_state = SendDataBlock;
          end
        end
      end

      SendDataBlock: begin
        if (bit_counter > 13'd4113) begin
          miso_reg        = 1'b1;
          new_bit_counter = bit_counter - 6'o01;
        end else if (bit_counter == 13'd4113) begin
          miso_reg        = 1'b0;
          new_bit_counter = bit_counter - 6'o01;
        end else if (bit_counter > 16) begin
          miso_reg        = data_block[bit_counter-17];
          new_bit_counter = bit_counter - 6'o01;
        end else if (bit_counter) begin
          miso_reg        = crc16[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      SendErrorToken: begin
        if (bit_counter) begin
          miso_reg        = ErrorTokenResponse[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = Idle;
      end

      ReturnCmd24: begin
        if (bit_counter) begin
          miso_reg        = Cmd24Response[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else begin
          new_bit_counter = 13'd4113;
          new_state = ReceiveDataBlock;
        end
      end

      ReceiveDataBlock: begin
        if (bit_counter == 13'd4113) begin
          if (~mosi) new_bit_counter = bit_counter - 6'o01;
        end else if (bit_counter > 13'd16) begin
          receive_data_block = 1'b1;
          new_bit_counter    = bit_counter - 6'o01;
        end else if (bit_counter) begin
          receive_crc16   = 1'b1;
          new_bit_counter = bit_counter - 6'o01;
        end else new_state = CheckWrite;
      end

      CheckWrite: begin
        new_bit_counter = 13'd8;
        crc16_calc = CRC16(received_data_block);
        if (crc16_calc == received_crc16) new_state = WriteSuccessful;
        else new_state = WriteError;
      end

      WriteSuccessful: begin
        if (bit_counter) begin
          miso_reg        = WriteSuccessfulResponse[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else begin
          new_bit_counter = random_busy_cycles;
          new_state = Busy;
        end
      end

      WriteError: begin
        if (bit_counter) begin
          miso_reg        = WriteErrorResponse[bit_counter-1];
          new_bit_counter = bit_counter - 6'o01;
        end else begin
          new_state = Idle;
        end
      end

      Busy: begin
        miso_reg = 1'b0;
        if (bit_counter) new_bit_counter = bit_counter - 1;
        else new_state = Idle;
      end

      CmdError: begin
        $display("\n\tindex: 0x%h\n\tcmd: 0x%h\n\texpected_cmd: 0x%h", index, cmd, expected_cmd);
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
