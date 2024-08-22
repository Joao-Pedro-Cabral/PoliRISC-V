
module core_tb ();

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
      .ADDR_SIZE(PeriphAddrSize)
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

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  ///////////////////////////////////
  //////// Especial Address /////////
  ///////////////////////////////////
  // Always to finish the simulation
  always @(posedge wish_proc1.we) begin
    if (wish_proc1.addr == FinalAddress) begin  // Final write addr
      $display("End of program!");
      $display("Write data: 0x%x", wish_proc1.dat_o_p);
      $display("Number of Cycles: %d", i);
      $stop;
    end
  end

  // Always to set/reset external_interrupt
  always @(posedge clock, posedge reset) begin
    if (reset) external_interrupt = 1'b0;
    else if (wish_proc1.addr == ExternalInterruptAddress && wish_proc1.we)
      external_interrupt = |wish_proc1.dat_o_p;
  end

  ///////////////////////////////////
  ////////// Initializer ////////////
  ///////////////////////////////////
  initial begin
    $display("SOT!");
    reset = 1'b1;
    @(posedge clock);
    @(negedge clock);
    reset = 1'b0;
    repeat (limit) begin
      @(posedge clock);
      i++;
    end
    $stop;
  end

endmodule
