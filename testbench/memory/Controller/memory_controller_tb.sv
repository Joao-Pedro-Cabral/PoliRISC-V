
module memory_controller_tb;

  import macros_pkg::*;
  import memory_controller_pkg::*;

  localparam integer ClockPeriod = 20;
  localparam integer BusyCycles = 10;
  localparam integer NumberOfTests = 100_000;

  localparam reg [63:0] RomAddr = 64'h0000000000000000;
  localparam reg [63:0] RomAddrMask = 64'hFFFFFFFFC0000000;
  localparam reg [63:0] RamAddr = 64'h0000000080000000;
  localparam reg [63:0] RamAddrMask = 64'hFFFFFFFFC0000000;
  localparam reg [63:0] UartAddr = 64'h00000000C0000000;
  localparam reg [63:0] UartAddrMask = 64'hFFFFFFFFE0000000;
  localparam reg [63:0] CsrAddr = 64'h00000000B0000000;
  localparam reg [63:0] CsrAddrMask = 64'hFFFFFFFFE0000000;

  // Interface Inputs
  logic clock, reset;

  // Auxiliaries
  logic sel_rom, sel_ram, sel_cache_inst, sel_cache_data, sel_uart, sel_csr;

  // Functions

  // Interfaces
  wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(ProcDataSize),
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
      .DATA_SIZE(ProcDataSize),
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
      .ADDR_SIZE(ProcAddrSize)
  ) wish_rom (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_ram (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_uart (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_csr (
      .*
  );

  // Classes
  wishbone_primary_class #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  )
      proc0, proc1;

  wishbone_primary_class #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  )
      cache_inst1, cache_data1;

  wishbone_secondary_class #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  )
      cache_inst0, cache_data0;

  wishbone_secondary_class #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  )
      rom, ram;

  wishbone_secondary_class #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  )
      uart, csr;

  // Instanciação do DUT
  memory_controller #(
      .ROM_ADDR(RomAddr),
      .RAM_ADDR(RamAddr),
      .UART_ADDR(UartAddr),
      .CSR_ADDR(CsrAddr),
      .ROM_ADDR_MASK(RomAddrMask),
      .RAM_ADDR_MASK(RamAddrMask),
      .UART_ADDR_MASK(UartAddrMask),
      .CSR_ADDR_MASK(CsrAddrMask)
  ) DUT (
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

  // Clock generation
  always #(ClockPeriod / 2) clock = ~clock;

  initial begin
    // Initializing
    clock       = 0;
    reset       = 0;
    proc0       = new(wish_proc0, "Proc 0");
    proc1       = new(wish_proc1, "Proc 1");
    cache_inst1 = new(wish_cache_inst1, "Cache Instruction 1");
    cache_data1 = new(wish_cache_data1, "Cache Data 1");
    cache_inst0 = new(wish_cache_inst0, "Cache Instruction 0");
    cache_data0 = new(wish_cache_data0, "Cache Data 0");
    rom         = new(wish_rom, "Rom");
    ram         = new(wish_ram, "Ram");
    uart        = new(wish_uart, "Uart");
    csr         = new(wish_csr, "CSR");

    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;

    $display("SOT");

    repeat (NumberOfTests) begin

      proc0.randomize_interface();
      proc1.randomize_interface();
      cache_inst1.randomize_interface();
      cache_data1.randomize_interface();
      cache_inst0.randomize_interface();
      cache_data0.randomize_interface();
      rom.randomize_interface();
      ram.randomize_interface();
      uart.randomize_interface();
      csr.randomize_interface();

      @(negedge clock);

      sel_rom = cache_data1.is_accessing(RomAddr, RomAddrMask);
      sel_ram = cache_data1.is_accessing(RamAddr, RamAddrMask);
      sel_cache_inst = proc0.is_accessing(RomAddr, RomAddrMask);
      sel_cache_data = proc1.is_accessing(RomAddr, RomAddrMask) |
          proc1.is_accessing(RamAddr, RamAddrMask);
      sel_uart = proc1.is_accessing(UartAddr, UartAddrMask);
      sel_csr = proc1.is_accessing(CsrAddr, CsrAddrMask);

      if (sel_rom) begin
        cache_data1.check_mem(rom.get_interface(), rom.get_name());
        rom.check_cache(cache_data1.get_interface(), cache_data1.get_name());
      end else begin
        cache_inst1.check_mem(rom.get_interface(), rom.get_name());
        rom.check_cache(cache_inst1.get_interface(), cache_inst1.get_name());
      end

      if (sel_ram) begin
        cache_data1.check_mem(ram.get_interface(), ram.get_name());
        ram.check_cache(cache_data1.get_interface(), cache_data1.get_name());
      end else ram.check_disabled();

      if (sel_cache_inst) begin
        proc0.check_cache(cache_inst0.get_interface(), cache_inst0.get_name());
        cache_inst0.check_proc(proc0.get_interface(), proc0.get_name());
      end else cache_inst0.check_disabled();

      if (sel_cache_data) begin
        proc1.check_cache(cache_data0.get_interface(), cache_data0.get_name());
        cache_data0.check_proc(proc1.get_interface(), proc1.get_name());
      end else cache_data0.check_disabled();

      if (sel_uart) begin
        proc1.check_periph(uart.get_interface(), uart.get_name());
        uart.check_proc(proc1.get_interface(), proc1.get_name());
      end else uart.check_disabled();

      if (sel_csr) begin
        proc1.check_periph(csr.get_interface(), csr.get_name());
        csr.check_proc(proc1.get_interface(), proc1.get_name());
      end else csr.check_disabled();

      @(negedge clock);

    end

    $display("EOT");

    $stop;
  end
endmodule
