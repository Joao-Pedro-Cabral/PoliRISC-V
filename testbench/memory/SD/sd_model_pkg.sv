
package sd_model_pkg;

  typedef enum logic [4:0] {
    Idle,
    ReceivingCmd,
    DecodeCmd,
    CheckCmd,
    ReturnCmd0,
    ReturnCmd8,
    ReturnCmd59,
    ReturnCmd55,
    ReturnAcmd41Idle,
    ReturnAcmd41,
    ReturnCmd16,
    ReturnCmd13,
    SendDataBlock,
    SendErrorToken,
    ReturnCmd17,
    ReturnCmd24,
    ReceiveDataBlock,
    CheckWrite,
    WriteError,
    WriteSuccessful,
    Busy,
    CmdError
  } sd_model_fsm_t;

  localparam reg [47:0] ExpectedCmd0 = {8'h40, 32'h00000000, 8'h95};
  localparam reg [47:0] ExpectedCmd8 = {8'h48, 32'h000001AA, 8'h87};
  localparam reg [47:0] ExpectedCmd59 = {8'h7B, 32'h00000001, 8'h83};
  localparam reg [47:0] ExpectedCmd55 = {8'h77, 32'h00000000, 8'h65};
  localparam reg [47:0] ExpectedAcmd41 = {8'h69, 32'h40000000, 8'h77};
  localparam reg [47:0] ExpectedAcmd41SDSC = {8'h69, 32'h00000000, 8'hE5};
  localparam reg [47:0] ExpectedCmd16 = {8'h50, 32'h200, 8'h15};
  localparam reg [47:0] ExpectedCmd13 = {8'h4D, 32'h00000000, 8'h0D};

endpackage
