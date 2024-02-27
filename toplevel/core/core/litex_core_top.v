
`include "macros.vh"
`include "extensions.vh"

module litex_core_top (
    // Common
    input  wire        clock,
    input  wire        reset,
    // DDR2
    output wire [12:0] ddram_a,
    output wire [ 2:0] ddram_ba,
    output wire        ddram_cas_n,
    output wire        ddram_cke,
    output wire        ddram_clk_n,
    output wire        ddram_clk_p,
    output wire        ddram_cs_n,
    output wire [ 1:0] ddram_dm,
    inout  wire [15:0] ddram_dq,
    inout  wire [ 1:0] ddram_dqs_n,
    inout  wire [ 1:0] ddram_dqs_p,
    output wire        ddram_odt,
    output wire        ddram_ras_n,
    output wire        ddram_reset_n,
    output wire        ddram_we_n
);

  // BUS
  wire [31:0] rd_data;
  wire [31:0] wr_data;
  wire [31:0] mem_addr;
  wire mem_ack;
  wire mem_wr_en;
  wire mem_CYC_O;
  wire mem_STB_O;
  wire [3:0] mem_byte_en;
  // Sinais do Barramento
  // ROM
  wire rom_cyc;
  wire rom_we;
  wire [3:0] rom_sel;
  wire [31:0] rom_dat;
  wire rom_ack;
  // SRAM
  wire sram_cyc;
  wire sram_we;
  wire [3:0] sram_sel;
  wire [31:0] sram_dat;
  wire sram_ack;
  // RAM
  wire ram_cyc;
  wire ram_we;
  wire [3:0] ram_sel;
  wire [31:0] ram_dat;
  wire ram_ack;
  // ETHMAC
  wire eth_cyc;
  wire eth_we;
  wire [3:0] eth_sel;
  wire [31:0] eth_dat;
  reg eth_ack;
  reg [1:0] eth_flag;
  // CSR + CLINT
  wire csr_clint_cyc;
  wire csr_clint_we;
  wire [3:0] csr_clint_sel;
  wire [31:0] csr_clint_dat;
  wire csr_clint_ack;
  // CSR_RAM
  wire csr_ram_cyc;
  wire csr_ram_we;
  wire [3:0] csr_ram_sel;
  wire [31:0] csr_ram_dat;
  wire csr_ram_ack;
  // PLIC
  wire plic_cyc;
  // wire plic_we;
  // wire [3:0] plic_sel;
  wire [31:0] plic_dat;
  reg plic_ack;
  reg [1:0] plic_flag;
  // variáveis
  integer i;

  // DUT
  core DUT (
      .clock(clock),
      .reset(reset),
      .DAT_I(rd_data),
      .DAT_O(wr_data),
      .mem_ADR_O(mem_addr),
      .mem_ACK_I(mem_ack),
      .mem_CYC_O(mem_CYC_O),
      .mem_STB_O(mem_STB_O),
      .mem_SEL_O(mem_byte_en),
      .mem_WE_O(mem_wr_en),
      .external_interrupt(1'b0),
      .mem_msip(0),
      .mem_mtime(64'h64),
      .mem_mtimecmp(64'h0)
  );

  // ROM
  single_port_ram #(
      .RAM_INIT_FILE("nexys4ddr_bios.mif"),
      .ADDR_SIZE(16),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) memory_rom (
      .CLK_I(clock),
      .ADR_I(mem_addr),
      .DAT_I(wr_data),
      .CYC_I(rom_cyc),
      .STB_I(rom_cyc),
      .WE_I (rom_we),
      .SEL_I(rom_sel),
      .DAT_O(rom_dat),
      .ACK_O(rom_ack)
  );

  // SRAM
  single_port_ram #(
      .RAM_INIT_FILE("zeros.mif"),
      .ADDR_SIZE(13),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) memory_sram (
      .CLK_I(clock),
      .ADR_I(mem_addr),
      .DAT_I(wr_data),
      .CYC_I(sram_cyc),
      .STB_I(sram_cyc),
      .WE_I (sram_we),
      .SEL_I(sram_sel),
      .DAT_O(sram_dat),
      .ACK_O(sram_ack)
  );

  // Main RAM
  litedram_core main_ram (
      .clk(clock),
      .ddram_a(ddram_a),
      .ddram_ba(ddram_ba),
      .ddram_cas_n(ddram_cas_n),
      .ddram_cke(ddram_cke),
      .ddram_clk_n(ddram_clk_n),
      .ddram_clk_p(ddram_clk_p),
      .ddram_cs_n(ddram_cs_n),
      .ddram_dm(ddram_dm),
      .ddram_dq(ddram_dq),
      .ddram_dqs_n(ddram_dqs_n),
      .ddram_dqs_p(ddram_dqs_p),
      .ddram_odt(ddram_odt),
      .ddram_ras_n(ddram_ras_n),
      .ddram_reset_n(ddram_reset_n),
      .ddram_we_n(ddram_we_n),
      .init_done(),
      .init_error(),
      .pll_locked(),
      .rst(reset),
      .user_clk(),
      .user_port_wishbone_0_ack(ram_ack),
      .user_port_wishbone_0_adr(mem_addr[24:0]),
      .user_port_wishbone_0_cyc(ram_cyc),
      .user_port_wishbone_0_dat_r(ram_dat),
      .user_port_wishbone_0_dat_w(wr_data),
      .user_port_wishbone_0_err(),
      .user_port_wishbone_0_sel(mem_sel),
      .user_port_wishbone_0_stb(ram_cyc),
      .user_port_wishbone_0_we(ram_we),
      .user_rst(),
      .wb_ctrl_ack(csr_ram_ack),
      .wb_ctrl_adr(mem_addr[29:0]),
      .wb_ctrl_bte(2'b00),
      .wb_ctrl_cti(3'b000),
      .wb_ctrl_cyc(csr_ram_cyc),
      .wb_ctrl_dat_r(csr_ram_dat),
      .wb_ctrl_dat_w(wr_data),
      .wb_ctrl_err(),
      .wb_ctrl_sel(csr_ram_sel),
      .wb_ctrl_stb(csr_ram_cyc),
      .wb_ctrl_we(csr_ram_we)
  );

  // ETHMAC
  // single_port_ram #(
  //     .RAM_INIT_FILE("zeros.mif"),
  //     .ADDR_SIZE(13),
  //     .BYTE_SIZE(8),
  //     .DATA_SIZE(32),
  //     .BUSY_CYCLES(2)
  // ) memory_eth (
  //     .CLK_I(clock),
  //     .ADR_I(mem_addr),
  //     .DAT_I(wr_data),
  //     .CYC_I(eth_cyc),
  //     .STB_I(eth_cyc),
  //     .WE_I (eth_we),
  //     .SEL_I(eth_sel),
  //     .DAT_O(eth_dat),
  //     .ACK_O(eth_ack)
  // );

  // ETH
  assign eth_dat = 0;
  always @(posedge clock) begin
    eth_ack <= 1'b0;
    if (eth_flag == 2'b11) begin
      eth_ack  <= 1'b1;
      eth_flag <= 2'b00;
    end else if (eth_flag != 2'b00) begin
      eth_flag <= eth_flag + 1;
    end else if (plic_cyc) begin
      eth_flag <= 2'b01;
    end
  end

  // CSR + CLINT
  single_port_ram #(
      .RAM_INIT_FILE("zeros.mif"),
      .ADDR_SIZE(17),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) memory_csr_clint (
      .CLK_I(clock),
      .ADR_I(mem_addr),
      .DAT_I(wr_data),
      .CYC_I(csr_clint_cyc),
      .STB_I(csr_clint_cyc),
      .WE_I (csr_clint_we),
      .SEL_I(csr_clint_sel),
      .DAT_O(csr_clint_dat),
      .ACK_O(csr_clint_ack)
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

  // Memory controller
  // ROM
  assign rom_cyc = (mem_addr[31:16] == 0) & mem_STB_O;
  assign rom_we = rom_cyc & mem_wr_en;
  assign rom_sel = mem_byte_en;
  // SRAM
  assign sram_cyc = (mem_addr[31:13] == 19'h08000) & mem_STB_O;
  assign sram_we = sram_cyc & mem_wr_en;
  assign sram_sel = mem_byte_en;
  // RAM
  assign ram_cyc = (mem_addr[31:26] == 6'h10) & mem_STB_O;
  assign ram_we = ram_cyc & mem_wr_en;
  assign ram_sel = mem_byte_en;
  // ETHMAC
  assign eth_cyc = (mem_addr[31:13] == 19'h40000) & mem_STB_O;
  assign eth_we = eth_cyc & mem_wr_en;
  assign eth_sel = mem_byte_en;
  // CSR + CLINT
  assign csr_clint_cyc = (mem_addr[31:17] == 15'h7800) & mem_STB_O;
  assign csr_clint_we = csr_clint_cyc & mem_wr_en;
  assign csr_clint_sel = mem_byte_en;
  // CSR + CLINT
  assign csr_ram_cyc = (mem_addr[31:8] == 24'hF0008) & mem_STB_O;
  assign csr_ram_we = csr_ram_cyc & mem_wr_en;
  assign csr_ram_sel = mem_byte_en;
  // PLIC
  assign plic_cyc = (mem_addr[31:22] == 10'h3C3) & mem_STB_O;
  // Controller
  assign rd_data = rom_cyc       ? rom_dat       :
                   sram_cyc      ? sram_dat      :
                   ram_cyc       ? ram_dat       :
                   eth_cyc       ? eth_dat       :
                   csr_ram_cyc   ? csr_ram_dat   :
                   csr_clint_cyc ? csr_clint_dat :
                   plic_cyc      ? plic_dat      : 0;
  assign mem_ack = rom_cyc       ? rom_ack       :
                   sram_cyc      ? sram_ack      :
                   ram_cyc       ? ram_ack       :
                   eth_cyc       ? eth_ack       :
                   csr_ram_cyc   ? csr_ram_ack   :
                   csr_clint_cyc ? csr_clint_ack :
                   plic_cyc      ? plic_ack      : 1'b0;

endmodule
