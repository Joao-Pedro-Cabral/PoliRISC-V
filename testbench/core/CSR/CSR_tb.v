`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

`define ASSERT(cond) if (!(cond)) $stop

module CSR_tb ();

  // Simulation Parameters
  localparam integer Line = 131;

  // DUT
  reg clock;
  reg reset;
  reg csr_reset;
  reg wr_en;
  reg [11:0] addr;
  reg [`DATA_SIZE-1:0] wr_data;
  reg external_interrupt;
  reg mem_msip;
  reg [`DATA_SIZE-1:0] pc;
  reg [31:0] instruction;
  reg [63:0] mem_mtime;
  reg [63:0] mem_mtimecmp;
  wire illegal_instruction;
  reg ecall;
  reg mret;
  reg sret;
  wire [`DATA_SIZE-1:0] rd_data;
  wire [`DATA_SIZE-1:0] mepc;
  wire [`DATA_SIZE-1:0] sepc;
  wire [`DATA_SIZE-1:0] trap_addr;
  wire trap;
  wire [1:0] privilege_mode;
  wire addr_exception;

  // Others table's columns
  reg [`DATA_SIZE-1:0] rd_data_;
  reg msb;  // rd_data's msb
  reg dont_ret;  // 1: don't active RET task
  reg [1:0] trap_type;  // [1:0] -> 00: no trap, 01: s-trap, 11: m-trap, 10: Reserved
  reg [`DATA_SIZE-1:0] mepc_;
  reg [`DATA_SIZE-1:0] sepc_;
  reg trap_;
  reg [`DATA_SIZE-1:0] trap_addr_;
  reg [1:0] privilege_mode_;
  reg addr_exception_;
  reg illegal_instruction_;

  // Auxiliaries
  reg [95:0] CSR_test[Line-1:0];
  integer i;
  reg [`DATA_SIZE-1:0] xtvec;  // Compute trap_addr
  reg [1:0] mpp;
  reg spp;

  // DUT
  CSR DUT (
      .clock(clock),
      .reset(csr_reset),
      .trap_en(1'b1),
      .wr_en(wr_en),
      .addr(addr),
      .wr_data(wr_data),
      .external_interrupt(external_interrupt),
      .mem_msip(mem_msip),
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
      .privilege_mode(privilege_mode),
      .addr_exception(addr_exception)
  );

  assign illegal_instruction = illegal_instruction_ | addr_exception_;

  // Tasks
  task automatic HandleTrap(input reg [1:0] trap_type);
    begin
      `ASSERT(trap_type === 2'b11 || trap_type === 2'b01);  // Others values are impossible
      mpp = DUT.mpp;
      spp = DUT.spp;
      mret = trap_type[1];
      sret = ~trap_type[1];
      // Clear all traps sources (except SEI/STI/SSI)
      {mem_mtime[1:0], mem_mtimecmp[1:0]} = 4'h1;
      ecall = 1'b0;
      {external_interrupt, mem_msip, illegal_instruction_} = 3'h0;
      wr_en = 1'b0;
      @(negedge clock);
      `ASSERT(mepc === mepc_);  // No changes
      `ASSERT(sepc === sepc_);  // No changes
      `ASSERT(trap === 1'b0);  // Clear trap
      // Back to previous privilege
      if (trap_type[1]) begin
        `ASSERT(privilege_mode === mpp);
      end else begin
        `ASSERT(privilege_mode === {1'b0, spp});
      end
    end
  endtask

  // Functions
  function automatic [`DATA_SIZE-1:0] gen_new_mepc(
      input reg [`DATA_SIZE-1:0] xepc, input reg [`DATA_SIZE-1:0] pc, input reg [1:0] trap_type,
      input reg [`DATA_SIZE-1:0] data, input reg [11:0] addr);
    begin
      if (trap_type === 2'b11) gen_new_mepc = pc;
      else if (!mret && !sret && trap_type == 2'b00 && addr == 12'h341)
        gen_new_mepc = {data[`DATA_SIZE-1:2], 2'b00};
      else gen_new_mepc = xepc;
    end
  endfunction

  function automatic [`DATA_SIZE-1:0] gen_new_sepc(
      input reg [`DATA_SIZE-1:0] xepc, input reg [`DATA_SIZE-1:0] pc, input reg [1:0] trap_type,
      input reg [`DATA_SIZE-1:0] data, input reg [11:0] addr);
    begin
      if (trap_type === 2'b01) gen_new_sepc = pc;
      else if (!sret && !mret && trap_type == 2'b00 && addr == 12'h141)
        gen_new_sepc = {data[`DATA_SIZE-1:2], 2'b00};
      else gen_new_sepc = xepc;
    end
  endfunction

  function automatic [`DATA_SIZE-1:0] gen_new_trap_addr(
      input reg [`DATA_SIZE-1:0] xtvec, input reg [`DATA_SIZE-1:0] cause, input reg has_async_trap);
    begin
      gen_new_trap_addr = (xtvec[0] && has_async_trap) ?
                                                      {xtvec[`DATA_SIZE-1:2], 2'b00} + (cause << 2)
                                                      : {xtvec[`DATA_SIZE-1:2], 2'b00};
    end
  endfunction

  always #3 clock = ~clock;

  initial begin
    // Reset
    $readmemh("./MIFs/core/CSR/CSR_test.mif", CSR_test);
    {clock, csr_reset, wr_en, addr, wr_data, external_interrupt, mem_msip, instruction,
    pc, mem_mtime, mem_mtimecmp, illegal_instruction_, ecall, mret, sret, rd_data_, privilege_mode_,
    msb, dont_ret, mepc_, sepc_, trap_, trap_addr_, trap_type} = 0;
    $display("SOT: %0t", $time);
    @(negedge clock);
    csr_reset = 1'b1;
    @(negedge clock);
    csr_reset = 1'b0;
    $display("Reset Complete : %0t", $time);
    // For each line of the table, the DUT is tested
    for (i = 0; i < Line; i = i + 1) begin
      // Simplification: Only use the first 16 bits of the vectors
      // Reason: Except mcause's msb and misa, after the 16th bit, all the others are read-only zero, WARL or don't care
      // Then, mcause will use msb reg and misa will have a special treatment
      // Set inputs/expected outputs
      $display("Test %d: %0t", i, $time);
      rd_data_ = 0;
      rd_data_[15:0] = CSR_test[i][15:0];
      addr_exception_ = CSR_test[i][19:16];  // truncat
      {dont_ret, msb, privilege_mode_} = CSR_test[i][23:20];
      instruction[15:0] = CSR_test[i][39:24];
      pc[15:0] = CSR_test[i][55:40];
      {mem_mtime[1:0], mem_mtimecmp[1:0]} = CSR_test[i][59:56];  // Only use 2 bits
      {ecall, mret, sret, trap_} = CSR_test[i][63:60];
      {external_interrupt, mem_msip, illegal_instruction_} = CSR_test[i][66:64];  // Only use 3 bits
      wr_data[15:0] = CSR_test[i][83:68];
      addr = CSR_test[i][95:84];
      wr_en = 1'b1;
      trap_type = trap_ ? privilege_mode_ : 2'b00;
      // Generate new expected outputs
      mepc_ = gen_new_mepc(mepc_, pc, trap_type, wr_data, addr);
      sepc_ = gen_new_sepc(sepc_, pc, trap_type, wr_data, addr);
      xtvec = trap_type == 2'b11 ? DUT.mtvec : DUT.stvec;
      // special treatment for MISA
      if (addr === 12'h301) begin
        msb = `DATA_SIZE == 64 ? 1'b1 : 1'b0;
        rd_data_ = `DATA_SIZE'h1400100;
        rd_data_[`DATA_SIZE-1:`DATA_SIZE-2] = `DATA_SIZE == 64 ? 2'b10 : 2'b01;
      end
      #1;
      trap_addr_ = gen_new_trap_addr(xtvec, DUT.cause_async, DUT.async_trap);
      `ASSERT(addr_exception === addr_exception_);
      `ASSERT(trap === trap_);
      `ASSERT(trap_addr === trap_addr_);
      @(negedge clock);
      // Check DUT's outputs
      `ASSERT(rd_data === {msb, rd_data_[`DATA_SIZE-2:0]});
      `ASSERT(mepc === mepc_);
      `ASSERT(sepc === sepc_);
      `ASSERT(privilege_mode === privilege_mode_);
      if (trap_ && !dont_ret) HandleTrap(trap_type);
    end
    $display("EOT: %0t", $time);
    $stop;
  end

endmodule
