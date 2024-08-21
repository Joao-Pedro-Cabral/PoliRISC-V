
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
    output wire        ddram_we_n,
    // SD card
    input  wire        miso,
    output wire        mosi,
    output wire        cs,
    output wire        sck,
    output wire        sd_reset,

    // UART
    input  wire rxd,
    output wire txd
);

  // Parameters
  localparam integer CacheSize = 8192;
  localparam integer SetSize = 1;
  localparam integer InstDataSize = 32;
  localparam integer ProcAddrSize = 32;
  localparam integer RomAddrSize = 16;
  localparam integer SramAddrSize = 13;
  localparam integer RamAddrSize = 25;
  localparam integer EthAddrSize = 13;
  localparam integer CsrClintAddrSize = 32;
  localparam integer CsrRamAddrSize = 30;
  localparam integer ByteSize = 8;
  localparam integer DataSize = 32;

  // BUS
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
  // ETHMAC
  wire eth_cyc;
  wire eth_we;
  wire [3:0] eth_sel;
  wire [31:0] eth_dat;
  reg eth_ack;
  reg [1:0] eth_flag;
  // CSR + CLINT
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(CsrClintAddrSize)
  ) wish_csr_clint (
      .*
  );
  // CSR_RAM
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(CsrRamAddrSize)
  ) wish_csr_ram (
      .*
  );
  // PLIC
  wire plic_cyc;
  wire [31:0] plic_dat;
  reg plic_ack;
  reg [1:0] plic_flag;

  // DUT
  core DUT (
      .clock,
      .reset,
      .wish_proc0,
      .wish_proc1,
      .external_interrupt(external_interrupt),
      .msip(0),
      .mtime(64'h64),
      .mtimecmp(64'h0)
  );

  sd_controller #(
      .SDSC(0)
  ) sd_card (
      .wb_if_s(wish_rom),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .sd_controller_state_db(),
      .sd_receiver_state_db(),
      .sd_sender_state_db(),
      .check_cmd_0_db(),
      .check_cmd_8_db(),
      .check_cmd_55_db(),
      .check_cmd_59_db(),
      .check_acmd_41_db(),
      .check_cmd_16_db(),
      .check_cmd_24_db(),
      .check_write_db(),
      .check_cmd_13_db(),
      .check_cmd_17_db(),
      .check_read_db(),
      .check_error_token_db(),
      .crc_error_db(),
      .crc16_db()
  );

  assign sd_reset = reset;

  // SRAM
  single_port_ram #(
      .RAM_INIT_FILE("zeros.mif"),
      .BUSY_CYCLES(2)
  ) memory_sram (
      .wb_if_s(wish_sram)
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
      .user_port_wishbone_0_ack(wish_ram.ack),
      .user_port_wishbone_0_adr(wish_ram.addr),
      .user_port_wishbone_0_cyc(wish_ram.cyc),
      .user_port_wishbone_0_dat_r(wish_ram.dat_o_s),
      .user_port_wishbone_0_dat_w(wish_ram.dat_i_s),
      .user_port_wishbone_0_err(),
      .user_port_wishbone_0_sel(wish_ram.sel),
      .user_port_wishbone_0_stb(wish_ram.cyc),
      .user_port_wishbone_0_we(wish_ram.we),
      .user_rst(),
      .wb_ctrl_ack(wish_csr_ram.ack),
      .wb_ctrl_adr(wish_csr_ram.addr),
      .wb_ctrl_bte(2'b00),
      .wb_ctrl_cti(3'b000),
      .wb_ctrl_cyc(wish_csr_ram.cyc),
      .wb_ctrl_dat_r(wish_csr_ram.dat_o_s),
      .wb_ctrl_dat_w(wish_csr_ram.dat_i_s),
      .wb_ctrl_err(),
      .wb_ctrl_sel(wish_csr_ram.sel),
      .wb_ctrl_stb(wish_csr_ram.cyc),
      .wb_ctrl_we(wish_csr_ram.we)
  );

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
  csr_and_clint memory_csr_clint (
      .wb_if_s(wish_csr_clint),
      .rxd(rxd),
      .txd(txd),
      .uart_interrupt(external_interrupt)
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
  assign wish_rom.tgd = wish_proc1.tgd;
  assign wish_rom.addr = sel_rom ? wish_proc1.addr : wish_proc0.addr;
  assign wish_rom.dat_o_p = sel_rom ? wish_proc1.dat_o_p : wish_proc0.dat_o_p;
  // SRAM
  assign wish_sram.cyc = (wish_proc1.addr[31:13] == 19'h08000) & wish_proc1.stb;
  assign wish_sram.stb = wish_sram.cyc;
  assign wish_sram.we = wish_sram.cyc & wish_proc1.we;
  assign wish_sram.sel = wish_proc1.sel;
  assign wish_sram.tgd = wish_proc1.tgd;
  assign wish_sram.addr = wish_proc1.addr;
  assign wish_sram.dat_o_p = wish_proc1.dat_o_p;
  // RAM
  assign wish_ram.cyc = (wish_proc1.addr[31:26] == 6'h10) & wish_proc1.stb;
  assign wish_ram.stb = wish_ram.cyc;
  assign wish_ram.we = wish_ram.cyc & wish_proc1.we;
  assign wish_ram.sel = wish_proc1.sel;
  assign wish_ram.tgd = wish_proc1.tgd;
  assign wish_ram.addr = wish_proc1.addr[26:2];
  assign wish_ram.dat_o_p = wish_proc1.dat_o_p;
  // ETHMAC
  assign eth_cyc = (wish_proc1.addr[31:13] == 19'h40000) & wish_proc1.stb;
  assign eth_we = eth_cyc & wish_proc1.we;
  assign eth_sel = wish_proc1.sel;
  // CSR + CLINT
  assign wish_csr_clint.cyc = (wish_proc1.addr[31:17] == 15'h7800) & wish_proc1.stb;
  assign wish_csr_clint.stb = wish_csr_clint.cyc;
  assign wish_csr_clint.we = wish_csr_clint.cyc & wish_proc1.we;
  assign wish_csr_clint.sel = wish_proc1.sel;
  assign wish_csr_clint.tgd = wish_proc1.tgd;
  assign wish_csr_clint.addr = wish_proc1.addr;
  assign wish_csr_clint.dat_o_p = wish_proc1.dat_o_p;
  // CSR + RAM
  assign wish_csr_ram.cyc = (wish_proc1.addr[31:8] == 24'hF0008) & wish_proc1.stb;
  assign wish_csr_ram.stb = wish_csr_ram.cyc;
  assign wish_csr_ram.we = wish_csr_ram.cyc & wish_proc1.we;
  assign wish_csr_ram.sel = wish_proc1.sel;
  assign wish_csr_ram.tgd = wish_proc1.tgd;
  assign wish_csr_ram.addr = wish_proc1.addr[31:2];
  assign wish_csr_ram.dat_o_p = wish_proc1.dat_o_p;
  // PLIC
  assign plic_cyc = (wish_proc1.addr[31:22] == 10'h3C3) & wish_proc1.stb;
  // Proc0
  assign wish_proc0.dat_o_s = wish_rom.dat_o_s;
  assign wish_proc0.ack = wish_rom.ack & !sel_rom;
  // Proc1
  assign wish_proc1.dat_o_s = (wish_rom.cyc & sel_rom)   ? wish_rom.dat_o_s       :
                              wish_sram.cyc              ? wish_sram.dat_o_s      :
                              wish_ram.cyc               ? wish_ram.dat_o_s       :
                              eth_cyc                    ? eth_dat                :
                              wish_csr_ram.cyc           ? wish_csr_ram.dat_o_s   :
                              wish_csr_clint.cyc         ? wish_csr_clint.dat_o_s :
                              plic_cyc                   ? plic_dat               : 0;
  assign wish_proc1.ack = (wish_rom.cyc & sel_rom)       ? wish_rom.ack           :
                          wish_sram.cyc                  ? wish_sram.ack          :
                          wish_ram.cyc                   ? wish_ram.ack           :
                          eth_cyc                        ? eth_ack                :
                          wish_csr_ram.cyc               ? wish_csr_ram.ack       :
                          wish_csr_clint.cyc             ? wish_csr_clint.ack     :
                          plic_cyc                       ? plic_ack               : 1'b0;

endmodule
