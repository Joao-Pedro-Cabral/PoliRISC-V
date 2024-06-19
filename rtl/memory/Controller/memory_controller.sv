
module memory_controller #(
    parameter reg [63:0] ROM_ADDR,
    parameter reg [63:0] ROM_ADDR_MASK,
    parameter reg [63:0] RAM_ADDR,
    parameter reg [63:0] RAM_ADDR_MASK,
    parameter reg [63:0] UART_ADDR,
    parameter reg [63:0] UART_ADDR_MASK,
    parameter reg [63:0] CSR_ADDR,
    parameter reg [63:0] CSR_ADDR_MASK
) (
    wishbone_if.secondary wish_s_proc0,
    wishbone_if.secondary wish_s_proc1,
    wishbone_if.secondary wish_s_cache_inst,
    wishbone_if.secondary wish_s_cache_data,
    wishbone_if.primary   wish_p_rom,
    wishbone_if.primary   wish_p_ram,
    wishbone_if.primary   wish_p_cache_inst,
    wishbone_if.primary   wish_p_cache_data,
    wishbone_if.primary   wish_p_uart,
    wishbone_if.primary   wish_p_csr
);

  // Auxiliary
  logic sel_rom, sel_ram, sel_cache_inst, sel_cache_data, sel_uart, sel_csr;

  assign sel_rom = ((wish_s_cache_data.addr & ROM_ADDR_MASK) == ROM_ADDR)
                                              & wish_s_cache_data.cyc & wish_s_cache_data.stb;
  assign sel_ram = ((wish_s_cache_data.addr & RAM_ADDR_MASK) == RAM_ADDR)
                                              & wish_s_cache_data.cyc & wish_s_cache_data.stb;
  assign sel_cache_inst = ((wish_s_proc0.addr & ROM_ADDR_MASK) == ROM_ADDR)
                                              & wish_s_proc0.cyc & wish_s_proc0.stb;
  assign sel_cache_data = (((wish_s_proc1.addr & ROM_ADDR_MASK) == ROM_ADDR) ||
                          ((wish_s_proc1.addr & RAM_ADDR_MASK) == RAM_ADDR))
                                              & wish_s_proc1.cyc & wish_s_proc1.stb;
  assign sel_uart = ((wish_s_proc1.addr & UART_ADDR_MASK) == UART_ADDR)
                                              & wish_s_proc1.cyc & wish_s_proc1.stb;
  assign sel_csr = ((wish_s_proc1.addr & CSR_ADDR_MASK) == CSR_ADDR)
                                              & wish_s_proc1.cyc & wish_s_proc1.stb;

  // Connect primary modport
  assign wish_p_rom.cyc = sel_rom ? wish_s_cache_data.cyc : wish_s_cache_inst.cyc;
  assign wish_p_rom.stb = sel_rom ? wish_s_cache_data.stb : wish_s_cache_inst.stb;
  assign wish_p_rom.we = sel_rom ? wish_s_cache_data.we : wish_s_cache_inst.we;
  assign wish_p_rom.tgd = sel_rom ? wish_s_cache_data.tgd : wish_s_cache_inst.tgd;
  assign wish_p_rom.sel = sel_rom ? wish_s_cache_data.sel : wish_s_cache_inst.sel;
  assign wish_p_rom.addr = sel_rom ? wish_s_cache_data.addr : wish_s_cache_inst.addr;
  assign wish_p_rom.dat_o_p = sel_rom ? wish_s_cache_data.dat_i_s : wish_s_cache_inst.dat_i_s;

  assign wish_p_ram.cyc = sel_ram;
  assign wish_p_ram.stb = sel_ram;
  assign wish_p_ram.we = wish_s_cache_data.we;
  assign wish_p_ram.tgd = wish_s_cache_data.tgd;
  assign wish_p_ram.sel = wish_s_cache_data.sel;
  assign wish_p_ram.addr = wish_s_cache_data.addr;
  assign wish_p_ram.dat_o_p = wish_s_cache_data.dat_i_s;

  assign wish_p_cache_inst.cyc = sel_cache_inst;
  assign wish_p_cache_inst.stb = sel_cache_inst;
  assign wish_p_cache_inst.we = wish_s_proc0.we;
  assign wish_p_cache_inst.tgd = wish_s_proc0.tgd;
  assign wish_p_cache_inst.sel = wish_s_proc0.sel;
  assign wish_p_cache_inst.addr = wish_s_proc0.addr;
  assign wish_p_cache_inst.dat_o_p = wish_s_proc0.dat_i_s;

  assign wish_p_cache_data.cyc = sel_cache_data;
  assign wish_p_cache_data.stb = sel_cache_data;
  assign wish_p_cache_data.we = wish_s_proc1.we;
  assign wish_p_cache_data.tgd = wish_s_proc1.tgd;
  assign wish_p_cache_data.sel = wish_s_proc1.sel;
  assign wish_p_cache_data.addr = wish_s_proc1.addr;
  assign wish_p_cache_data.dat_o_p = wish_s_proc1.dat_i_s;

  assign wish_p_uart.cyc = sel_uart;
  assign wish_p_uart.stb = sel_uart;
  assign wish_p_uart.we = wish_s_proc1.we;
  assign wish_p_uart.tgd = wish_s_proc1.tgd;
  assign wish_p_uart.sel = wish_s_proc1.sel;
  assign wish_p_uart.addr = wish_s_proc1.addr;
  assign wish_p_uart.dat_o_p = wish_s_proc1.dat_i_s;

  assign wish_p_csr.cyc = sel_csr;
  assign wish_p_csr.stb = sel_csr;
  assign wish_p_csr.we = wish_s_proc1.we;
  assign wish_p_csr.tgd = wish_s_proc1.tgd;
  assign wish_p_csr.sel = wish_s_proc1.sel;
  assign wish_p_csr.addr = wish_s_proc1.addr;
  assign wish_p_csr.dat_o_p = wish_s_proc1.dat_i_s;

  // Connect secondary modport
  assign wish_s_cache_inst.ack = wish_p_rom.ack & !sel_rom;
  assign wish_s_cache_inst.dat_o_s = wish_p_rom.dat_i_p;

  assign wish_s_cache_data.ack = sel_rom ? wish_p_rom.ack : wish_p_ram.ack;
  assign wish_s_cache_data.dat_o_s = sel_rom ? wish_p_rom.dat_i_p : wish_p_ram.dat_i_p;

  assign wish_s_proc0.ack = wish_p_cache_inst.ack;
  assign wish_s_proc0.dat_o_s = wish_p_cache_inst.dat_i_p;

  assign wish_s_proc1.ack = sel_cache_data ? wish_p_cache_data.ack :
                                             (sel_csr ? wish_p_csr.ack : wish_p_uart.ack);
  assign wish_s_proc1.dat_o_s = sel_cache_data ?  wish_p_cache_data.dat_i_p :
                                             (sel_csr ? wish_p_csr.dat_i_p : wish_p_uart.dat_i_p);

endmodule
