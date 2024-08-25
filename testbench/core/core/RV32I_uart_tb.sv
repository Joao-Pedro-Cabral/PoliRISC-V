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

  ///////////////////////////////////
  ///////////// Imports /////////////
  ///////////////////////////////////
  import extensions_pkg::*;

  ///////////////////////////////////
  //////////// Parameters ///////////
  ///////////////////////////////////
  // Wishbone
  localparam integer CacheSize = 8192;
  localparam integer SetSize = 1;
  localparam integer InstDataSize = 32;
  localparam integer HasRV64I = (DataSize == 64);
  localparam integer CacheDataSize = 128;
  localparam integer ProcAddrSize = 32;
  localparam integer MemoryAddrSize = 16;
  localparam integer PeriphAddrSize = 7;
  localparam integer ByteSize = 8;
  localparam integer ByteNum = DataSize / ByteSize;
  // Memory Address
  localparam reg [63:0] RomAddr = 64'h0000000000000000;
  localparam reg [63:0] RomAddrMask = 64'hFFFFFFFFFF000000;
  localparam reg [63:0] RamAddr = 64'h0000000001000000;
  localparam reg [63:0] RamAddrMask = 64'hFFFFFFFFFF000000;
  localparam reg [63:0] UartAddr = 64'h0000000010013000;
  localparam reg [63:0] UartAddrMask = 64'hFFFFFFFFFFFFF000;
  localparam reg [63:0] CsrAddr = 64'h000000003FFFF000;
  localparam reg [63:0] CsrAddrMask = 64'hFFFFFFFFFFFFFFC0;
  // MTIME
  localparam integer ClockCycles = 100;

  ///////////////////////////////////
  /////////// DUT Signals ///////////
  ///////////////////////////////////
  logic clock;
  logic reset;
  // Interrupts from Memory
  logic external_interrupt;
  logic [DataSize-1:0] msip;
  logic [63:0] mtime;
  logic [63:0] mtimecmp;

  ///////////////////////////////////
  /////////// Interfaces ////////////
  ///////////////////////////////////
  wishbone_if #(
      .DATA_SIZE(InstDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_inst0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_inst1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_data0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_data1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(MemoryAddrSize)
  ) wish_rom (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(MemoryAddrSize)
  ) wish_ram (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize - 4)
  ) wish_uart (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_csr (
      .*
  );

  ///////////////////////////////////
  //////// Simulator Signals ////////
  ///////////////////////////////////
  // variáveis
  integer
      limit = 1000, i = 0;  // número máximo de iterações a serem feitas (evitar loop infinito)
  // Address
  localparam integer FinalAddress = 16781308;  // Final execution address
  localparam integer ExternalInterruptAddress = 16781320;  // Active/Desactive External Interrupt

  // DUT
  core #(
      .DATA_SIZE(DataSize)
  ) DUT (
      .clock,
      .reset,
      .wish_proc0,
      .wish_proc1,
      .external_interrupt,
      .msip,
      .mtime,
      .mtimecmp
  );

  ///////////////////////////////////
  //////// Mem Components ///////////
  ///////////////////////////////////
  // Instruction Cache
  cache #(
      .CACHE_SIZE(CacheSize),
      .SET_SIZE  (SetSize)
  ) instruction_cache (
      .wb_if_ctrl(wish_cache_inst0),
      .wb_if_mem (wish_cache_inst1)
  );

  // Data Cache
  cache #(
      .CACHE_SIZE(CacheSize),
      .SET_SIZE  (SetSize)
  ) data_cache (
      .wb_if_ctrl(wish_cache_data0),
      .wb_if_mem (wish_cache_data1)
  );

  // Instruction Memory
  rom #(
      .ROM_INIT_FILE("./ROM.mif"),
      .BUSY_CYCLES  (4)
  ) instruction_memory (
      .wb_if_s(wish_rom)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .BUSY_CYCLES  (4)
  ) data_memory (
      .wb_if_s(wish_ram)
  );

  // Registradores em memória do CSR
  csr_mem #(
      .DATA_SIZE(DataSize),
      .CLOCK_CYCLES(ClockCycles)
  ) mem_csr (
      .wb_if_s(wish_csr),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .ROM_ADDR(RomAddr),
      .RAM_ADDR(RamAddr),
      .UART_ADDR(UartAddr),
      .CSR_ADDR(CsrAddr),
      .ROM_ADDR_MASK(RomAddrMask),
      .RAM_ADDR_MASK(RamAddrMask),
      .UART_ADDR_MASK(UartAddrMask),
      .CSR_ADDR_MASK(CsrAddrMask)
  ) controller (
      .wish_s_proc0(wish_proc0),
      .wish_s_proc1(wish_proc1),
      .wish_s_cache_inst(wish_cache_inst1),
      .wish_s_cache_data(wish_cache_data1),
      .wish_p_rom(wish_rom),
      .wish_p_ram(wish_ram),
      .wish_p_cache_inst(wish_cache_inst0),
      .wish_p_cache_data(wish_cache_data0),
      .wish_p_uart(wish_uart),
      .wish_p_csr(wish_csr)
  );

  // UART
  uart #(
      .LITEX_ARCH(0),
      .FIFO_DEPTH(8),
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .wb_if_s            (wish_uart),
      .rxd                (uart_0_rxd),  // TX always high to simulate no data
      .txd                (uart_0_txd),
      .interrupt          (),
      .div_db             (),
      .rx_pending_db      (),
      .tx_pending_db      (),
      .rx_pending_en_db   (),
      .tx_pending_en_db   (),
      .txcnt_db           (),
      .rxcnt_db           (),
      .txen_db            (),
      .rxen_db            (),
      .nstop_db           (),
      .rx_fifo_empty_db   (),
      .rxdata_db          (),
      .tx_fifo_full_db    (),
      .txdata_db          (),
      .present_state_db   (),
      .addr_db            (),
      .wr_data_db         (),
      .rx_data_valid_db   (),
      .tx_data_valid_db   (),
      .tx_rdy_db          (),
      .rx_watermark_reg_db(),
      .tx_watermark_reg_db(),
      .tx_status_db       (),
      .rx_status_db       ()
  );

  // curto circuito da serial da UART
  assign uart_0_rxd = uart_0_txd;  // modo echo
  //assign uart_0_rxd = 1'b1;  // checar tx_full

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
    $display("[%0t] SOT\n", $time);

    while (i < AmntOfTests) begin
      // Check for RAM write operation using wishbone interface signals
      if (wish_cache_data0.we && wish_cache_data0.cyc && wish_cache_data0.stb) begin
        @(negedge clock);
        @(negedge clock);  // Wait for 2 cycles

        // Check if it's a store word (SW) operation
        assert (wish_cache_data0.sel === 4'hF)
        else $stop("Assertion failed: wish_cache_data0.sel is not 4'hF");

        // Check the write address
        // FIXME: code below does not work. Why?
        // assert (wish_cache_data0.addr[9:0] === 10'b0)
        // else $stop("Assertion failed: wish_cache_data0.addr[9:0] is not 10'h0");
        // Check if the data being written is 0 (rx_data == tx_data)
        // assert (wish_cache_data0.dat_o_p === 32'h0)
        // else $stop("Assertion failed: wish_cache_data0.dat_o_p is not 32'h0");

        // Check the write address
        if (!(wish_cache_data0.addr[9:0] === 10'h0)) begin
          $display("[%0t] Assertion failed: wish_cache_data0.addr[9:0] is not 10'h0", $time);
          $stop;
        end

        if (!(wish_cache_data0.dat_o_p === 32'h0)) begin
          $display("[%0t] Assertion failed: wish_cache_data0.dat_o_p is not 32'h0", $time);
          $stop;
        end

        i = i + 1;
      end
      @(negedge clock);
    end

    $display("[%0t] EOT\n", $time);
    $stop;
  end
endmodule
