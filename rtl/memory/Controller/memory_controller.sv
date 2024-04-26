
module memory_controller #(
    parameter reg [63:0] ROM_ADDR_MASKS,
    parameter reg [63:0] RAM_ADDR_MASKS,
    parameter reg [63:0] CACHE_ROM_ADDR_MASKS,
    parameter reg [63:0] CACHE_RAM_ADDR_MASKS,
    parameter reg [63:0] UART_ADDR_MASKS,
    parameter reg [63:0] CSR_ADDR_MASKS
) (
    wishbone_if.secondary wish_s_proc0,
    wishbone_if.secondary wish_s_proc1,
    wishbone_if.secondary wish_s_cache_rom,
    wishbone_if.secondary wish_s_cache_ram,
    wishbone_if.primary wish_p_rom,
    wishbone_if.primary wish_p_ram,
    wishbone_if.primary wish_p_cache_rom,
    wishbone_if.primary wish_p_cache_ram,
    wishbone_if.primary wish_p_uart,
    wishbone_if.primary wish_p_csr
);

// Auxiliary

logic sel_rom, sel_ram, sel_cache_rom, sel_cache_ram, sel_uart, sel_csr;

assign sel_rom = ((wish_s_cache_ram.addr & ROM_ADDR_MASKS) == ROM_ADDR_MASKS)
                                              & wish_s_cache_ram.cyc & wish_s_cache_ram.stb;
assign sel_ram = ((wish_s_cache_ram.addr & RAM_ADDR_MASKS) == RAM_ADDR_MASKS)
                                              & wish_s_cache_ram.cyc & wish_s_cache_ram.stb;
assign sel_cache_rom = ((wish_s_proc0.addr & CACHE_ROM_ADDR_MASKS) == CACHE_ROM_ADDR_MASKS)
                                                      & wish_s_proc0.cyc & wish_s_proc0.stb;
assign sel_cache_ram = ((wish_s_proc1.addr & CACHE_RAM_ADDR_MASKS) == CACHE_RAM_ADDR_MASKS)
                                                      & wish_s_proc1.cyc & wish_s_proc1.stb;
assign sel_uart = ((wish_s_proc1.addr & UART_ADDR_MASKS) == UART_ADDR_MASKS) & wish_s_proc1.cyc
                                                                             & wish_s_proc1.stb;
assign sel_csr = ((wish_s_proc1.addr & CSR_ADDR_MASKS) == CSR_ADDR_MASKS) & wish_s_proc1.cyc
                                                                          & wish_s_proc1.stb;

// Connect primary modport
assign wish_p_rom.cyc = sel_rom ? wish_s_cache_ram.cyc : wish_s_cache_rom.cyc;
assign wish_p_rom.stb = sel_rom ? wish_s_cache_ram.stb : wish_s_cache_rom.stb;
assign wish_p_rom.we = sel_rom ? wish_s_cache_ram.we : wish_s_cache_rom.we;
assign wish_p_rom.tgd = sel_rom ? wish_s_cache_ram.tgd : wish_s_cache_rom.tgd;
assign wish_p_rom.sel = sel_rom ? wish_s_cache_ram.sel : wish_s_cache_rom.sel;
assign wish_p_rom.addr = sel_rom ? wish_s_cache_ram.addr : wish_s_cache_rom.addr;
assign wish_p_rom.dat_i_p = sel_rom ? wish_s_cache_ram.dat_o_s : wish_s_cache_rom.dat_o_s;

assign wish_p_ram.cyc = sel_ram;
assign wish_p_ram.stb = sel_ram;
assign wish_p_ram.we = wish_s_cache_ram.we;
assign wish_p_ram.tgd = wish_s_cache_ram.tgd;
assign wish_p_ram.sel = wish_s_cache_ram.sel;
assign wish_p_ram.addr = wish_s_cache_ram.addr;
assign wish_p_ram.dat_i_p = wish_s_cache_ram.dat_o_s;

assign wish_p_cache_rom.cyc = sel_cache_rom;
assign wish_p_cache_rom.stb = sel_cache_rom;
assign wish_p_cache_rom.we = wish_s_proc0.we;
assign wish_p_cache_rom.tgd = wish_s_proc0.tgd;
assign wish_p_cache_rom.sel = wish_s_proc0.sel;
assign wish_p_cache_rom.addr = wish_s_proc0.addr;
assign wish_p_cache_rom.dat_i_p = wish_s_proc0.dat_o_s;

assign wish_p_cache_ram.cyc = sel_cache_ram;
assign wish_p_cache_ram.stb = sel_cache_ram;
assign wish_p_cache_ram.we = wish_s_proc1.we;
assign wish_p_cache_ram.tgd = wish_s_proc1.tgd;
assign wish_p_cache_ram.sel = wish_s_proc1.sel;
assign wish_p_cache_ram.addr = wish_s_proc1.addr;
assign wish_p_cache_ram.dat_i_p = wish_s_proc1.dat_o_s;

assign wish_p_uart.cyc = sel_uart;
assign wish_p_uart.stb = sel_uart;
assign wish_p_uart.we = wish_s_proc1.we;
assign wish_p_uart.tgd = wish_s_proc1.tgd;
assign wish_p_uart.sel = wish_s_proc1.sel;
assign wish_p_uart.addr = wish_s_proc1.addr;
assign wish_p_uart.dat_i_p = wish_s_proc1.dat_o_s;

assign wish_p_csr.cyc = sel_csr;
assign wish_p_csr.stb = sel_csr;
assign wish_p_csr.we = wish_s_proc1.we;
assign wish_p_csr.tgd = wish_s_proc1.tgd;
assign wish_p_csr.sel = wish_s_proc1.sel;
assign wish_p_csr.addr = wish_s_proc1.addr;
assign wish_p_csr.dat_i_p = wish_s_proc1.dat_o_s;

// Connect secondary modport
assign wish_s_cache_rom.ack     = wish_p_rom.ack & !sel_rom;
assign wish_s_cache_rom.dat_i_s = wish_p_rom.dat_o_p;

assign wish_s_cache_ram.ack     = sel_rom ? wish_p_rom.ack : wish_p_ram.ack;
assign wish_s_cache_ram.dat_i_s = sel_rom ? wish_p_rom.dat_o_p : wish_p_ram.dat_o_p;

assign wish_s_proc0.ack         = wish_p_cache_rom.ack;
assign wish_s_proc0.dat_i_s     = wish_p_cache_rom.dat_i_p;

assign wish_s_proc1.ack         = sel_ram ? (sel_csr ? wish_p_csr.ack : wish_p_ram.ack) :
                                            (sel_uart ? wish_p_uart.ack : 1'b0);
assign wish_s_proc1.dat_i_p      = sel_ram ? wish_p_ram.dat_o_s :
                                            (sel_csr ? wish_p_csr.dat_o_s : wish_p_uart.dat_o_s);

endmodule
