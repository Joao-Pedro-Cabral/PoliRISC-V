
package sd_controller_pkg;

  typedef enum logic [4:0] {
    InitBegin,
    WaitSendCmd,
    WaitReceiveCmd,
    SendCmd0,
    CheckCmd0,
    SendCmd8,
    CheckCmd8,
    SendCmd59,
    CheckCmd59,
    SendCmd55,
    CheckCmd55,
    SendAcmd41,
    CheckAcmd41,
    SendCmd16,
    CheckCmd16,
    Idle,
    SendCmd17,
    CheckCmd17,
    SendCmd24,
    CheckCmd24,
    CheckRead,
    CheckWrite,
    SendCmd13,
    CheckCmd13,
    CheckErrorToken,
    Final
  } sd_controller_fsm_t;

  typedef enum logic [5:0] {
    Cmd0 = 6'd00,
    Cmd8 = 6'd08,
    Cmd13 = 6'd13,
    Cmd16 = 6'd16,
    Cmd17 = 6'd17,
    Cmd24 = 6'd24,
    Cmd41 = 6'd41,
    Cmd55 = 6'd55,
    Cmd59 = 6'd59
  } cmd_index_t;

  typedef enum logic [7:0] {
    CmdInitializedResponse = 8'h00,
    CmdNotInitializedResponse = 8'h01,
    WriteSuccessfulResponse = 8'h05,
    WriteErrorResponse = 8'h0B,
    ErrorTokenResponse = 8'h0F,
    Cmd17ErrorResponse = 8'h74
  } cmd_response_t;

  localparam reg [15:0] Cmd13Response = 16'h0000;
  localparam reg [39:0] Cmd8Response = {8'h01, 4'h2, 16'h0000, 4'h1, 8'hAA};

  typedef enum logic [31:0] {
    NullCmdArgument = 32'h00000000,
    Cmd8Argument = 32'h000001AA,
    Cmd59Argument = 32'h00000001,
    Acmd41Argument = 32'h40000000,
    Cmd16Argument = 32'd512
  } cmd_argument_t;

endpackage
