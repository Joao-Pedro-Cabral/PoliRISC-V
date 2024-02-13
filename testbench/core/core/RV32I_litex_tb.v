//
//! @file   RV32I_Litex_tb.v
//! @brief  Testbench do core com BIOS da Litex
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2024-02-11
//

`include "macros.vh"
`include "extensions.vh"

`define ASSERT(condition) if (!(condition)) $stop

module RV32I_litex_tb ();
  // sinais do DUT
  reg clock;
  reg reset;
  // BUS
  wire [31:0] rd_data;
  wire [31:0] wr_data;
  wire [31:0] mem_addr;
  wire mem_ack;
  wire mem_wr_en;
  wire mem_CYC_O;
  wire mem_STB_O;
  wire [3:0] mem_byte_en;
  wire external_interrupt;
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
  // CSR + CLINT
  wire csr_clint_cyc;
  wire csr_clint_we;
  wire [3:0] csr_clint_sel;
  wire [31:0] csr_clint_dat;
  wire csr_clint_ack;
  // PLIC
  wire plic_cyc;
  wire plic_we;
  wire [3:0] plic_sel;
  wire [31:0] plic_dat;
  wire plic_ack;
  // OpenSBI
  // wire opensbi_cyc;
  // wire opensbi_we;
  // wire [3:0] opensbi_sel;
  // wire [31:0] opensbi_dat;
  // wire opensbi_ack;
  // variáveis
  integer limit = 100000;  // tamanho do programa que será executado
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
      .external_interrupt(external_interrupt),
      .mem_msip(0),
      .mem_mtime(64'h64),
      .mem_mtimecmp(64'h0)
  );

  // ROM
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/bios.mif"),
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
      .RAM_INIT_FILE("./MIFs/memory/ROM/bios.mif"),
      .ADDR_SIZE(12),
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
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/bios.mif"),
      .ADDR_SIZE(26),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) memory_ram (
      .CLK_I(clock),
      .ADR_I(mem_addr),
      .DAT_I(wr_data),
      .CYC_I(ram_cyc),
      .STB_I(ram_cyc),
      .WE_I (ram_we),
      .SEL_I(ram_sel),
      .DAT_O(ram_dat),
      .ACK_O(ram_ack)
  );

  // CSR + CLINT
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
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
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/ROM/zeros.mif"),
      .ADDR_SIZE(22),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) memory_plic (
      .CLK_I(clock),
      .ADR_I(mem_addr),
      .DAT_I(wr_data),
      .CYC_I(plic_cyc),
      .STB_I(plic_cyc),
      .WE_I (plic_we),
      .SEL_I(plic_sel),
      .DAT_O(plic_dat),
      .ACK_O(plic_ack)
  );

  // OpenSBI
  // single_port_ram #(
  //     .RAM_INIT_FILE("./MIFs/memory/ROM/bios.mif"),
  //     .ADDR_SIZE(19),
  //     .BYTE_SIZE(8),
  //     .DATA_SIZE(32),
  //     .BUSY_CYCLES(2)
  // ) memory_opensbi (
  //     .CLK_I(clock),
  //     .ADR_I(mem_addr),
  //     .DAT_I(wr_data),
  //     .CYC_I(opensbi_cyc),
  //     .STB_I(opensbi_cyc),
  //     .WE_I (opensbi_we),
  //     .SEL_I(opensbi_sel),
  //     .DAT_O(opensbi_dat_O),
  //     .ACK_O(opensbi_ack)
  // );

  // BUS
  assign external_interrupt = memory_csr_clint.ram[16'h1010][1];

  // Memory controller
  // ROM
  assign rom_cyc = (mem_addr[31:16] == 0) & mem_STB_O;
  assign rom_we = rom_cyc & mem_wr_en;
  assign rom_sel = mem_byte_en;
  // SRAM
  assign sram_cyc = (mem_addr[31:12] == 20'h10000) & mem_STB_O;
  assign sram_we = sram_cyc & mem_wr_en;
  assign sram_sel = mem_byte_en;
  // RAM
  assign ram_cyc = (mem_addr[31:26] == 6'h10) & mem_STB_O;
  assign ram_we = ram_cyc & mem_wr_en;
  assign ram_sel = mem_byte_en;
  // CSR + CLINT
  assign csr_clint_cyc = (mem_addr[31:17] == 15'h7800) & mem_STB_O;
  assign csr_clint_we = csr_clint_cyc & mem_wr_en;
  assign csr_clint_sel = mem_byte_en;
  // PLIC
  assign plic_cyc = (mem_addr[31:22] == 10'h3C3) & mem_STB_O;
  assign plic_we = plic_cyc & mem_wr_en;
  assign plic_sel = mem_byte_en;
  // OpenSBI
  // assign opensbi_cyc = mem_addr[31:19] == 13'h;
  // assign opensbi_we = opensbi_cyc & mem_wr_en;
  // assign opensbi_sel = mem_byte_en;
  assign rd_data = rom_cyc       ? rom_dat       :
                   sram_cyc      ? sram_dat      :
                   ram_cyc       ? ram_dat       :
                   csr_clint_cyc ? csr_clint_dat :
                   plic_cyc      ? plic_dat      : 0;
  assign mem_ack = rom_cyc       ? rom_ack       :
                   sram_cyc      ? sram_ack      :
                   ram_cyc       ? ram_ack       :
                   csr_clint_cyc ? csr_clint_ack :
                   plic_cyc      ? plic_ack      : 1'b0;
  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  always @(posedge csr_clint_cyc) begin
    if (mem_addr == 32'hf0001000 && csr_clint_we) begin
      $write("%s", wr_data[7:0]);
    end else if (32'hf0001010 == mem_addr && csr_clint_we) begin
      $display("Accessing pending");
      if (~wr_data[1]) begin
        force memory_csr_clint.ram[16'h1010][1] = 1'b0;
        release memory_csr_clint.ram[16'h1010][1];
      end
    end
  end

  always @(posedge DUT.illegal_instruction) begin
    $display("Illegal instruction!");
    $stop;
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
    // $monitor("[monitor]: time=%0t, trap=%b, pc=%x", $time, DUT.DF._trap, DUT.DF.pc);
    for (i = 0; i < limit; i = i + 1) begin
      // $display("Test: %d", i);
      @(negedge clock);
      if (limit == 58567) begin
        force memory_csr_clint.ram[16'h1010][1] = 1'b1;
        release memory_csr_clint.ram[16'h1010][1];
      end
    end
    $stop;
  end
endmodule
