
module core_litex_nexys4ddr_tb ();

  import extensions_pkg::*;
  import csr_pkg::*;

  // Parameters
  localparam integer CacheSize = 8192;
  localparam integer SetSize = 1;
  localparam integer InstDataSize = 32;
  localparam integer ProcAddrSize = 32;
  localparam integer RomAddrSize = 16;
  localparam integer SramAddrSize = 13;
  localparam integer RamAddrSize = 27;
  localparam integer EthAddrSize = 13;
  localparam integer CsrClintAddrSize = 17;
  localparam integer ByteSize = 8;

  localparam integer UartAddress = 32'hf0001000;

  // Common
  reg clock;
  reg reset;
  // PLIC
  wire plic_cyc;
  // wire plic_we;
  // wire [3:0] plic_sel;
  wire [31:0] plic_dat;
  reg plic_ack;
  reg [1:0] plic_flag;
  // Proc
  logic sel_rom;
  // variáveis
  integer i;

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
      .ADDR_SIZE(RomAddrSize)
  ) wish_rom (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(SramAddrSize)
  ) wish_sram (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(RamAddrSize)
  ) wish_ram (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(EthAddrSize)
  ) wish_eth (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(CsrClintAddrSize)
  ) wish_csr_clint (
      .*
  );

  // DUT
  core DUT (
      .clock,
      .reset,
      .wish_proc0,
      .wish_proc1,
      .external_interrupt(1'b0),
      .msip(0),
      .mtime(64'h64),
      .mtimecmp(64'h0)
  );

  // ROM
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/bios/nexys4ddr_bios.mif"),
      .BUSY_CYCLES(2)
  ) memory_rom (
      .wb_if_s(wish_rom)
  );

  // SRAM
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
      .BUSY_CYCLES(2)
  ) memory_sram (
      .wb_if_s(wish_sram)
  );

  // Main RAM
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
      .BUSY_CYCLES(2)
  ) memory_ram (
      .wb_if_s(wish_ram)
  );

  // ETHMAC
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
      .BUSY_CYCLES(2)
  ) memory_eth (
      .wb_if_s(wish_eth)
  );

  // CSR + CLINT
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
      .BUSY_CYCLES(2)
  ) memory_csr_clint (
      .wb_if_s(wish_csr_clint)
  );

  // PLIC
  assign plic_dat = 0;
  always @(posedge clock) begin
    plic_ack <= 1'b0;
    if (plic_flag == 2'b11) begin
      plic_ack  <= 1'b1;
      plic_flag <= 2'b00;
    end else if (plic_flag != 2'b00) begin
      plic_flag <= plic_flag + 1;
    end else if (plic_cyc) begin
      plic_flag <= 2'b01;
    end
  end

  // Wishbone
  assign sel_rom = (wish_proc1.addr[31:16] == 0) & wish_proc1.cyc & wish_proc1.stb;
  // ROM
  assign wish_rom.cyc = sel_rom ? 1'b1 : (wish_proc0.addr[31:16] == 0) & wish_proc0.stb;
  assign wish_rom.stb = wish_rom.cyc;
  assign wish_rom.we = sel_rom ? wish_proc1.we : wish_proc0.we;
  assign wish_rom.sel = sel_rom ? wish_proc1.sel : wish_proc0.sel;
  assign wish_rom.addr = sel_rom ? wish_proc1.addr : wish_proc0.addr;
  assign wish_rom.dat_o_p = sel_rom ? wish_proc1.dat_o_p : wish_proc0.dat_o_p;
  // SRAM
  assign wish_sram.cyc = (wish_proc1.addr[31:13] == 19'h08000) & wish_proc1.stb;
  assign wish_sram.stb = wish_sram.cyc;
  assign wish_sram.we = wish_sram.cyc & wish_proc1.we;
  assign wish_sram.sel = wish_proc1.sel;
  assign wish_sram.addr = wish_proc1.addr;
  assign wish_sram.dat_o_p = wish_proc1.dat_o_p;
  // RAM
  assign wish_ram.cyc = (wish_proc1.addr[31:26] == 6'h10) & wish_proc1.stb;
  assign wish_ram.stb = wish_ram.cyc;
  assign wish_ram.we = wish_ram.cyc & wish_proc1.we;
  assign wish_ram.sel = wish_proc1.sel;
  assign wish_ram.addr = wish_proc1.addr;
  assign wish_ram.dat_o_p = wish_proc1.dat_o_p;
  // ETHMAC
  assign wish_eth.cyc = (wish_proc1.addr[31:13] == 19'h40000) & wish_proc1.stb;
  assign wish_eth.stb = wish_eth.cyc;
  assign wish_eth.we = wish_eth.cyc & wish_proc1.we;
  assign wish_eth.sel = wish_proc1.sel;
  assign wish_eth.addr = wish_proc1.addr;
  assign wish_eth.dat_o_p = wish_proc1.dat_o_p;
  // CSR + CLINT
  assign wish_csr_clint.cyc = (wish_proc1.addr[31:17] == 15'h7800) & wish_proc1.stb;
  assign wish_csr_clint.stb = wish_csr_clint.cyc;
  assign wish_csr_clint.we = wish_csr_clint.cyc & wish_proc1.we;
  assign wish_csr_clint.sel = wish_proc1.sel;
  assign wish_csr_clint.addr = wish_proc1.addr;
  assign wish_csr_clint.dat_o_p = wish_proc1.dat_o_p;
  // PLIC
  assign plic_cyc = (wish_proc1.addr[31:22] == 10'h3C3) & wish_proc1.stb;
  // Proc0
  assign wish_proc0.dat_o_s = wish_rom.dat_o_s;
  assign wish_proc0.ack = wish_rom.ack & !sel_rom;
  // Proc1
  assign wish_proc1.dat_o_s = (wish_rom.cyc & sel_rom)   ? wish_rom.dat_o_s       :
                              wish_sram.cyc              ? wish_sram.dat_o_s      :
                              wish_ram.cyc               ? wish_ram.dat_o_s       :
                              wish_eth.cyc               ? wish_eth.dat_o_s       :
                              wish_csr_clint.cyc         ? wish_csr_clint.dat_o_s :
                              plic_cyc                   ? plic_dat               : 0;
  assign wish_proc1.ack = (wish_rom.cyc & sel_rom)       ? wish_rom.ack           :
                          wish_sram.cyc                  ? wish_sram.ack          :
                          wish_ram.cyc                   ? wish_ram.ack           :
                          wish_eth.cyc                   ? wish_eth.ack           :
                          wish_csr_clint.cyc             ? wish_csr_clint.ack     :
                          plic_cyc                       ? plic_ack               : 1'b0;
  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  always @(posedge wish_csr_clint.cyc) begin
    @(negedge clock);
    if (wish_proc1.addr == UartAddress && wish_csr_clint.we) begin
      $write("%s", wish_proc1.dat_o_p[7:0]);
    end
  end

  always @(DUT.csr_op) begin
    if(DUT.data_flow.csr_bank.csr_op == CsrIllegalInstruction &&
       DUT.data_flow.csr_bank.exception) begin
      $display("Illegal instruction!");
      $stop;
    end
  end

  task automatic DoReset();
    begin
      // desabilito a escrita no banco simulado
      reset = 1'b1;
      @(posedge clock);
      @(negedge clock);
      reset = 1'b0;
    end
  endtask

  // testar o DUT
  initial begin : Testbench
    $display("SOT!");
    DoReset();
  end
endmodule
