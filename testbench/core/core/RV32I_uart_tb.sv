module RV32I_uart_tb;

  // Simulation Parameters
  localparam int AmntOfTests = 1;  // tx_full = 1 -> Write 0 to RAM -> EOT
  localparam int ClockPeriod = 20;

  // DUT signals
  logic        clock;
  logic        reset;
  // Interrupts from Memory
  logic        external_interrupt;
  logic [31:0] msip;
  logic [63:0] mtime;
  logic [63:0] mtimecmp;

  // Instruction and Data Memory Interfaces
  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(4),
      .ADDR_SIZE(32)
  ) wish_proc0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(4),
      .ADDR_SIZE(32)
  ) wish_proc1 (
      .*
  );

  int i;  // iteration variable

  // DUT instantiation
  core #(
      .DATA_SIZE(32)
  ) DUT (
      .clock(clock),
      .reset(reset),
      .wish_proc0(wish_proc0),
      .wish_proc1(wish_proc1),
      .external_interrupt(external_interrupt),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // ROM Instantiation
  rom #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/uart_tx_full_test.mif"),
      .BUSY_CYCLES  (2)
  ) Instruction_Memory (
      .wb_if_s(wish_proc0)
  );

  // Updated Data Memory (Single Port RAM) Instantiation
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/core.mif"),
      .BUSY_CYCLES  (2)
  ) Data_Memory (
      .wb_if_s(wish_proc1)
  );

  // UART
  uart #(
      .LITEX_ARCH(0),  // Assuming SiFive configuration, adjust if needed
      .FIFO_DEPTH(8),
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .wb_if_s(wish_proc1), // Assuming wishbone interface for UART
      .rxd(1'b1), // Assuming UART RX is held high (no data)
      .txd(),     // UART TX signal (not looped back)
      .interrupt() // UART interrupt (not connected)
  );

  // Clock generation
  always #(ClockPeriod / 2) clock = ~clock;

  // Testbench
  initial begin
    {i, clock, reset} = 0;
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    @(negedge clock);
    $display("[%0t] SOT", $time);
    while (i < AmntOfTests) begin
      // If it's a RAM write operation
      if (wish_proc1.we && wish_proc1.cyc && wish_proc1.stb) begin
        @(negedge clock);
        @(negedge clock);  // Wait for 2 cycles
        // Check if it's a store word
        assert (wish_proc1.sel === 4'hF)
        else $stop("Assertion failed: wish_proc1.sel is not 4'hF");
        // Check the write address
        assert (wish_proc1.addr[9:0] === 10'h0)
        else $stop("Assertion failed: wish_proc1.addr[9:0] is not 10'h0");
        // Check if it's writing 0: rx_data == tx_data
        assert (wish_proc1.dat_o_p === 32'h0)
        else $stop("Assertion failed: wish_proc1.dat_o_p is not 32'h0");
        i = i + 1;
      end
      @(negedge clock);
    end
    $display("[%0t] EOT", $time);
    $stop;
  end
endmodule

