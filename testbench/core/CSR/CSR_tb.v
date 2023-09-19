`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

`ifndef SYNTH
`define ASSERT(cond, message) if (!(cond)) begin $display message ; $stop ; end
`endif

module CSR_tb (
`ifdef SYNTH
    input clock,
    input reset,

    output reg [15:0] state
`endif
);

`ifndef SYNTH
  reg clock;
  reg reset;
`endif
  reg csr_reset;
  reg wr_en;
  reg [11:0] addr;
  reg [`DATA_SIZE-1:0] wr_data;
  reg external_interrupt;
  reg mem_msip;
  reg mem_ssip;
  reg [`DATA_SIZE-1:0] pc;
  reg [31:0] instruction;
  reg [63:0] mem_mtime;
  reg [63:0] mem_mtimecmp;
  reg illegal_instruction;
  reg ecall;
  reg mret;
  reg sret;
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
  wire [`DATA_SIZE-1:0] trap_addr;
  wire trap;
  wire [1:0] privilege_mode;

  localparam reg [15:0]
    ResetCSR                       = 16'h0000,
    WriteMie                       = 16'h0001,
    ReadMie                        = 16'h0002,
    WriteSie                       = 16'h0003,
    ReadSie                        = 16'h0004,
    WriteMstatus                   = 16'h0005,
    ReadMstatus                    = 16'h0006,
    WriteMstatusTrap               = 16'h0007,
    ReadMstatusTrap                = 16'h0008,
    WriteMstatusMret               = 16'h0009,
    ReadMstatusMret                = 16'h000A,
    WriteSstatus                   = 16'h000B,
    ReadSstatus                    = 16'h000C,
    WriteSstatusSret               = 16'h000D,
    ReadSstatusSret                = 16'h000E,
    Mret                           = 16'h000F,
    WriteMip                       = 16'h0010,
    ReadMip                        = 16'h0011,
    WriteSip                       = 16'h0012,
    ReadSip                        = 16'h0013,
    WriteMepcTrap                  = 16'h0014,
    ReadMepcTrap                   = 16'h0015,
    WriteMepc                      = 16'h0016,
    ReadMepc                       = 16'h0017,
    WriteSepc                      = 16'h0018,
    ReadSepc                       = 16'h0019,
    WriteMcauseAsyncTrap           = 16'h001A,
    ReadMcauseAsyncTrap            = 16'h001B,
    ReadScauseAsyncTrap            = 16'h001C,
    WriteMcauseSyncTrap            = 16'h001D,
    ReadMcauseSyncTrap             = 16'h001E,
    ReadScauseSyncTrap             = 16'h001F,
    WriteMcauseIllegalInstruction  = 16'h0020,
    ReadMcauseIllegalInstruction   = 16'h0021,
    ReadScauseIllegalInstruction   = 16'h0022,
    WriteMcauseEcall               = 16'h0023,
    ReadMcauseEcall                = 16'h0024,
    ReadScauseEcall                = 16'h0025,
    WriteMcause                    = 16'h0026,
    ReadMcause                     = 16'h0027,
    ReadScause                     = 16'h0028,
    TestEnd                        = 16'h0029;
  reg [15:0] state;
  reg [15:0] next_state;

  CSR DUT (
      .clock(~clock),
      .reset(csr_reset),
      .wr_en(wr_en),
      .addr(addr),
      .wr_data(wr_data),
      .external_interrupt(external_interrupt),
      .mem_msip(mem_msip),
      .mem_ssip(mem_ssip),
      .pc(pc),
      .instruction(instruction),
      .mem_mtime(mem_mtime),
      .mem_mtimecmp(mem_mtimecmp),
      .illegal_instruction(illegal_instruction),
      .ecall(ecall),
      .mret(mret),
      .sret(sret),

      .rd_data(rd_data),
      .mepc(mepc),
      .sepc(sepc),
      .trap(trap),
      .trap_addr(trap_addr),
      .privilege_mode(privilege_mode)
  );

  task assign_defaults;
    begin
      csr_reset           = 1'b0;
      wr_en               = 1'h0;
      addr                = 12'h0;
      wr_data             = {`DATA_SIZE{1'b0}};
      external_interrupt  = 1'b0;
      mem_msip            = 1'b0;
      mem_ssip            = 1'b0;
      instruction         = 0;
      pc                  = {`DATA_SIZE{1'b0}};
      mem_mtime           = 64'h0;
      mem_mtimecmp        = 64'h1;
      illegal_instruction = 1'b0;
      ecall               = 1'b0;
      mret                = 1'b0;
      sret                = 1'b0;
    end
  endtask

`ifndef SYNTH
  initial begin
    force clock = 1'b0;
    reset = 1'b0;
    repeat (2) #1 reset = ~reset;
    release clock;
  end
`endif

  /*
  * ideia: use temporary variables to store
  * randomly generated values for memory-mapped
  * CSRs
  */

  always @(posedge clock, posedge reset) begin
    if (reset) begin
      state <= ResetCSR;
    end else begin
      state <= next_state;
    end
  end

  always @* begin
    assign_defaults;

    case (state)
      ResetCSR: begin
        csr_reset  = 1'b1;
        next_state = WriteMie;
      end

      WriteMie: begin
        addr        = 12'h304;
        wr_en       = 1'b1;
        wr_data[3]  = 1'b1;  // MSIE
        wr_data[7]  = 1'b1;  // MTIE
        wr_data[11] = 1'b1;  // MEIE
        next_state  = ReadMie;
      end

      ReadMie: begin
        addr = 12'h304;
`ifndef SYNTH
        `ASSERT(rd_data[3] & rd_data[7] & rd_data[11],
                ("[%t] ReadMie: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteSie;
      end

      WriteSie: begin
        addr       = 12'h104;
        wr_en      = 1'b1;
        wr_data[1] = 1'b1;  // SSIE
        wr_data[5] = 1'b1;  // STIE
        wr_data[9] = 1'b1;  // SEIE
        next_state = ReadSie;
      end

      ReadSie: begin
        addr = 12'h104;
`ifndef SYNTH
        `ASSERT(rd_data[1] & ~rd_data[3] & rd_data[5] & ~rd_data[7] & rd_data[9] & ~rd_data[11],
                ("[%t] ReadSie: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMstatus;
      end

      WriteMstatus: begin
        addr           = 12'h300;
        wr_en          = 1'b1;
        wr_data[3]     = 1'b1;  // MIE
        wr_data[7]     = 1'b1;  // MPIE
        wr_data[8]     = 1'b0;  // SPP
        wr_data[12:11] = 2'b01;  // MPP
        next_state     = ReadMstatus;
      end

      ReadMstatus: begin
        addr = 12'h300;
`ifndef SYNTH
        `ASSERT(rd_data[3] && rd_data[7] && ~rd_data[8] && (rd_data[12:11] == 2'b01),
                ("[%t] ReadMstatus: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMstatusTrap;
      end

      WriteMstatusTrap: begin
        addr               = 12'h300;
        external_interrupt = 1'b1;
        next_state         = ReadMstatusTrap;
      end

      ReadMstatusTrap: begin
        addr = 12'h300;
`ifndef SYNTH
        `ASSERT(!rd_data[3] && rd_data[7] && (rd_data[12:11] == 2'b11),
                ("[%t] ReadMstatusTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMstatusMret;
      end

      WriteMstatusMret: begin
        addr       = 12'h300;
        mret       = 1'b1;
        next_state = ReadMstatusMret;
      end

      ReadMstatusMret: begin
        addr = 12'h300;
`ifndef SYNTH
        `ASSERT(rd_data[3] && rd_data[7] && (rd_data[12:11] == 2'b00),
                ("[%t] ReadMstatusMret: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteSstatus;
      end

      WriteSstatus: begin
        addr       = 12'h100;
        wr_en      = 1'b1;
        wr_data[1] = 1'b1;  // SIE
        wr_data[5] = 1'b1;  // SPIE
        wr_data[8] = 1'b1;  // SPP
        next_state = ReadSstatus;
      end

      ReadSstatus: begin
        addr = 12'h100;
`ifndef SYNTH
        `ASSERT(rd_data[1] & rd_data[5] & rd_data[8],
                ("[%t] ReadSstatus: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteSstatusSret;
      end

      WriteSstatusSret: begin
        addr       = 12'h100;
        sret       = 1'b1;
        next_state = ReadSstatusSret;
      end

      ReadSstatusSret: begin
        addr = 12'h100;
`ifndef SYNTH
        `ASSERT(rd_data[1] & rd_data[5] & ~rd_data[8],
                ("[%t] ReadSstatusSret: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = Mret;
      end

      Mret: begin
        // to make sure DUT.priv == 2'b11
        mret       = 1'b1;
        next_state = WriteMip;
      end

      WriteMip: begin
        addr       = 12'h344;
        wr_en      = 1'b1;
        wr_data[5] = 1'b0;  // STIP
        wr_data[9] = 1'b0;  // SEIP
        next_state = ReadMip;
      end

      ReadMip: begin
        addr               = 12'h344;
        mem_ssip           = 1'b1;
        mem_msip           = 1'b1;
        mem_mtime          = 64'h2;
        external_interrupt = 1'b1;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data[1] & rd_data[3] & ~rd_data[5] & rd_data[7] & ~rd_data[9] & rd_data[11],
                ("[%t] ReadMip: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteSip;
      end

      WriteSip: begin
        addr       = 12'h144;
        wr_en      = 1'b1;
        wr_data[5] = 1'b1;  // STIP
        wr_data[9] = 1'b1;  // SEIP
        next_state = ReadSip;
      end

      ReadSip: begin
        addr               = 12'h144;
        mem_ssip           = 1'b1;
        mem_msip           = 1'b1;
        mem_mtime          = 64'h2;
        external_interrupt = 1'b1;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data[1] & ~rd_data[3] & rd_data[5] & ~rd_data[7] & rd_data[9] & ~rd_data[11],
                ("[%t] ReadSip: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMepcTrap;
      end

      WriteMepcTrap: begin
        addr       = 12'h341;
        ecall      = 1'b1;
        pc         = `DATA_SIZE'b10101010;
        next_state = ReadMepcTrap;
      end

      ReadMepcTrap: begin
        addr = 12'h341;
`ifndef SYNTH
        `ASSERT(rd_data == `DATA_SIZE'b10101010,
                ("[%t] ReadMepcTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMepc;
      end

      WriteMepc: begin
        addr       = 12'h341;
        wr_en      = 1'b1;
        wr_data    = {`DATA_SIZE{1'b1}};
        next_state = ReadMepc;
      end

      ReadMepc: begin
        addr = 12'h341;
`ifndef SYNTH
        `ASSERT(rd_data == {{`DATA_SIZE - 2{1'b1}}, 2'b00},
                ("[%t] ReadMepc: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteSepc;
      end

      WriteSepc: begin
        addr       = 12'h141;
        wr_en      = 1'b1;
        wr_data    = {`DATA_SIZE{1'b1}};
        next_state = ReadSepc;
      end

      ReadSepc: begin
        addr = 12'h141;
`ifndef SYNTH
        `ASSERT(rd_data == {{`DATA_SIZE - 2{1'b1}}, 2'b00},
                ("[%t] ReadSepc: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMcauseAsyncTrap;
      end

      WriteMcauseAsyncTrap: begin
        addr               = 12'h342;
        external_interrupt = 1'b1;
        next_state         = ReadMcauseAsyncTrap;
      end

      ReadMcauseAsyncTrap: begin
        addr = 12'h342;
`ifndef SYNTH
        `ASSERT(rd_data == `DATA_SIZE'd11,
                ("[%t] ReadMcauseAsyncTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = ReadScauseAsyncTrap;
      end

      ReadScauseAsyncTrap: begin
        addr = 12'h142;
        sret = 1'b1;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data == `DATA_SIZE'd0,
                ("[%t] ReadScauseAsyncTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMcauseSyncTrap;
      end

      WriteMcauseSyncTrap: begin
        addr = 12'h342;
        illegal_instruction = 1'b1;
        next_state = ReadMcauseSyncTrap;
      end

      ReadMcauseSyncTrap: begin
        addr = 12'h342;
`ifndef SYNTH
        `ASSERT(rd_data == `DATA_SIZE'd2,
                ("[%t] ReadMcauseSyncTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = ReadScauseSyncTrap;
      end

      ReadScauseSyncTrap: begin
        addr = 12'h142;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data == `DATA_SIZE'd0,
                ("[%t] ReadScauseSyncTrap: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMcauseEcall;
      end

      WriteMcauseEcall: begin
        addr = 12'h342;
        ecall = 1'b1;
        next_state = ReadMcauseEcall;
      end

      ReadMcauseEcall: begin
        addr = 12'h342;
`ifndef SYNTH
        `ASSERT(rd_data == `DATA_SIZE'd11,
                ("[%t] ReadMcauseEcall: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = ReadScauseEcall;
      end

      ReadScauseEcall: begin
        addr = 12'h142;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data == `DATA_SIZE'd0,
                ("[%t] ReadScauseEcall: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = WriteMcause;
      end

      WriteMcause: begin
        addr = 12'h342;
        wr_en = 1'b1;
        wr_data = 64'd5;
        next_state = ReadMcause;
      end

      ReadMcause: begin
        addr = 12'h342;
`ifndef SYNTH
        `ASSERT(rd_data == `DATA_SIZE'd5, ("[%t] ReadMcause: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = ReadScause;
      end

      ReadScause: begin
        addr = 12'h142;
`ifndef SYNTH
        @(posedge clock);
        `ASSERT(rd_data == `DATA_SIZE'd0, ("[%t] ReadScause: rd_data = 0x%x", $realtime, rd_data))
`endif
        next_state = TestEnd;
      end

      TestEnd: begin
`ifndef SYNTH
        $stop;
`endif
        next_state = state;
      end

      default: begin
        next_state = state;
      end
    endcase
  end

`ifndef SYNTH
  always #1 clock = ~clock;
`endif

endmodule
