//
//! @file   RV32I_uart_tb.sv
//! @brief  Testbench for RV32I with UART without FENCE, ECALL, and EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2024-08-22
//

// 2 TBs in 1
// First TB (uart_test.mif)
// Check if the processor can write/read from the UART
// Write data to TX -> Receive the same data via RX
// Subtract the written and received value
// Write the result to the address
// Second TB (uart_tx_full_test.mif)
// Check processor behavior when writing to TX
// Observe how the processor sees tx_full


module RV32I_uart_tb;

  import macros_pkg::*;
  import board_pkg::*;
  import uart_pkg::*;
  import uart_phy_pkg::uart_phy_fsm_t;

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
  // UART
  logic        uart_0_txd;
  logic        uart_0_rxd;

  // Wishbone Interfaces
  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(32)
  ) wish_proc0 (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(32)
  ) wish_proc1 (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(32)
  ) wish_cache_inst (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(32)
  ) wish_cache_data (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(128),
      .BYTE_SIZE(8),
      .ADDR_SIZE(16)
  ) wish_rom (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(128),
      .BYTE_SIZE(8),
      .ADDR_SIZE(16)
  ) wish_ram (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(3)
  ) wish_uart (
      .*
  );

  wishbone_if #(
      .DATA_SIZE(32),
      .BYTE_SIZE(8),
      .ADDR_SIZE(7)
  ) wish_csr (
      .*
  );

  int i;  // iteration variable

  // DUT
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

  // Instruction Memory (ROM)
  rom #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/uart_tx_full_test.mif"),
      .BUSY_CYCLES  (2)
  ) Instruction_Memory (
      .wb_if_s(wish_rom)
  );

  // Data Memory (RAM)
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/core.mif"),
      .BUSY_CYCLES  (3)
  ) Data_Memory (
      .wb_if_s(wish_ram)
  );

  // UART
  uart #(
      .LITEX_ARCH(0),
      .FIFO_DEPTH(8),
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .wb_if_s  (wish_uart),
      .rxd      (uart_0_rxd),  // TX always high to simulate no data
      .txd      (uart_0_txd),
      .interrupt()
  );

  // CSR (Assuming a CSR module is present)
  // Assuming there's some form of CSR interface connected
  // CSR module would go here

  // Updated Memory Controller Instantiation
  memory_controller #(
      .ROM_ADDR(64'h0000000000000000),
      .ROM_ADDR_MASK(64'hFFFFFFFFC0000000),
      .RAM_ADDR(64'h0000000080000000),
      .RAM_ADDR_MASK(64'hFFFFFFFFC0000000),
      .UART_ADDR(64'h00000000C0000000),
      .UART_ADDR_MASK(64'hFFFFFFFFE0000000),
      .CSR_ADDR(64'h00000000B0000000),
      .CSR_ADDR_MASK(64'hFFFFFFFFE0000000)
  ) BUS (
      .wish_s_proc0(wish_proc0),
      .wish_s_proc1(wish_proc1),
      .wish_s_cache_inst(wish_cache_inst),
      .wish_s_cache_data(wish_cache_data),
      .wish_p_rom(wish_rom),
      .wish_p_ram(wish_ram),
      .wish_p_cache_inst(wish_cache_inst),
      .wish_p_cache_data(wish_cache_data),
      .wish_p_uart(wish_uart),
      .wish_p_csr(wish_csr)
  );

  // curto circuito da serial da UART
  //assign uart_0_rxd = uart_0_txd;  // modo echo
  assign uart_0_rxd = 1'b1;  // checar tx_full

  // Clock generation
  always #(ClockPeriod / 2) clock = ~clock;

  // Testbench
  initial begin
    {i, clock, reset} = 0;
    msip = 0;
    mtime = 0;
    mtimecmp = 0;

    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    @(negedge clock);
    $display("[%0t] SOT\n", $time);

    while (i < AmntOfTests) begin
      // Check for RAM write operation using wishbone interface signals
      if (wish_ram.we && wish_ram.cyc && wish_ram.stb) begin
        @(negedge clock);
        @(negedge clock);  // Wait for 2 cycles

        // Check if it's a store word (SW) operation
        assert (wish_ram.sel === 4'hF)
        else $stop("Assertion failed: wish_ram.sel is not 4'hF");

        // Check the write address
        // FIXME: code below does not work. Why?
        //assert (wish_ram.addr[9:0] === 10'b0)
        //else $stop("Assertion failed: wish_ram.addr[9:0] is not 10'h0");

        // Check the write address
        if (!(wish_ram.addr[9:0] === 10'h0)) begin
          $display("[%0t] Assertion failed: wish_ram.addr[9:0] is not 10'h0", $time);
          $stop;
        end

        // Check if the data being written is 0 (rx_data == tx_data)
        assert (wish_ram.dat_o_p === 32'h0)
        else $stop("Assertion failed: wish_ram.dat_o_p is not 32'h0");

        i = i + 1;
      end
      @(negedge clock);
    end

    $display("[%0t] EOT\n", $time);
    $stop;
  end
endmodule
