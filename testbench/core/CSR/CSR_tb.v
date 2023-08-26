`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

`define ASSERT(cond, message) if (!cond) begin $display message ; $stop end

module CSR_tb ();

  reg clock;
  reg reset;
  reg wr_en;
  reg [11:0] addr;
  reg [`DATA_SIZE-1:0] wr_data;
  reg external_interrupt;
  reg mem_msip;
  reg mem_ssip;
  reg [`DATA_SIZE-1:0] pc;
  reg [63:0] mem_mtime;
  reg [63:0] mem_mtimecmp;
  reg illegal_instruction;
  reg ecall;
  reg mret;
  reg sret;
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
  wire trap;
  wire [1:0] privilege_mode;

  localparam reg [15:0]
    ResetCSR = 16'h0000,
    WriteMstatus = 16'h0001,
    ReadMstatus = 16'h0002,
    WriteSstatus = 16'h0003,
    ReadSstatus = 16'h0004,
    WriteMie = 16'h0005,
    ReadMie = 16'h0006,
    WriteMip = 16'h0007,
    ReadMip = 16'h0008,
    WriteSie = 16'h0009,
    ReadSie = 16'h000A,
    WriteSip = 16'h000B,
    ReadSip = 16'h000C;


  CSR csr (
      .clock(clock),
      .reset(reset),
      .wr_en(wr_en),
      .addr(addr),
      .wr_data(wr_data),
      .external_interrupt(external_interrupt),
      .mem_msip(mem_msip),
      .mem_ssip(mem_ssip),
      .pc(pc),
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
      .privilege_mode(privilege_mode)
  );

  /*
  * ideia: use temporary variables to store
  * randomly generated values for memory-mapped
  * CSRs
  */


  always #1 clk = ~clk;

endmodule
