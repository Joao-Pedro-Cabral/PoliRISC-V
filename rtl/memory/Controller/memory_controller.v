//
//! @file   memory_controller.v
//! @brief  Implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`include "macros.vh"

module memory_controller #(
    parameter integer BYTE_AMNT = 8,
    parameter integer MSIP_ADDR,
    parameter integer SSIP_ADDR,
    parameter integer MTIME_ADDR, // Alinhado em 8 bytes
    parameter integer MTIMECMP_ADDR // Alinhado em 8 bytes
) (
    /* Interface com o cache de instruções */
    input [8*BYTE_AMNT-1:0] inst_cache_data,
    input inst_cache_busy,
    output inst_cache_enable,
    output [8*BYTE_AMNT-1:0] inst_cache_addr,
    /* //// */

    /* Interface com a memória RAM */
    input [8*BYTE_AMNT-1:0] ram_read_data,
    input ram_busy,
    output [8*BYTE_AMNT-1:0] ram_address,
    output [8*BYTE_AMNT-1:0] ram_write_data,
    output ram_output_enable,
    output ram_write_enable,
    output ram_chip_select,
    output [BYTE_AMNT-1:0] ram_byte_enable,
    /* //// */

    /* Registradores do CSR mapeados em memória */
    input [8*BYTE_AMNT-1:0] msip,
    input [8*BYTE_AMNT-1:0] ssip,
    input [63:0] mtime,
    input [63:0] mtimecmp,
    output [8*BYTE_AMNT-1:0] csr_reg_wr_data,
    output msip_en,
    output ssip_en,
    output mtime_en,
    output mtimecmp_en,

    /* Interface com a UART */
`ifdef UART_0
    input [8*BYTE_AMNT-1:0] uart_0_rd_data,
    input uart_0_busy,
    output uart_0_rd_en,
    output uart_0_wr_en,
    output [4:0] uart_0_addr,
    output [8*BYTE_AMNT-1:0] uart_0_wr_data,
`endif
    /* //// */

    /* Interface com o processador */
    input mem_rd_en,
    input mem_wr_en,
    input [BYTE_AMNT-1:0] mem_byte_en,
    input [8*BYTE_AMNT-1:0] wr_data,
    input [8*BYTE_AMNT-1:0] mem_addr,

    output [8*BYTE_AMNT-1:0] rd_data,
    output [8*BYTE_AMNT-1:0] mem_msip,
    output [8*BYTE_AMNT-1:0] mem_ssip,
    output [63:0] mem_mtime,
    output [63:0] mem_mtimecmp,
    output mem_busy
    /* //// */
);

  /* Sinais de controle */
  wire s_rom_enable = mem_addr[8*BYTE_AMNT-1:24] == 0 ? 1'b1 : 1'b0;  // 16 MiB para a ROM
  wire s_ram_chip_select =
    mem_addr[8*BYTE_AMNT-1:24] <= 'b100 && mem_addr[8*BYTE_AMNT-1:24] >= 'b1 ? 1'b1
    : 1'b0;  // 64 MiB para a RAM
`ifdef UART_0
  wire uart_0_cs =
    mem_addr[8*BYTE_AMNT-1:12] >= 'h10013 && mem_addr[8*BYTE_AMNT-1:0] <= 'h10013018 ? 1'b1
    : 1'b0;
`endif

  wire msip_cs = (mem_addr == MSIP_ADDR);
  wire ssip_cs = (mem_addr == SSIP_ADDR);
  wire mtime_cs = (mem_addr[8*BYTE_AMNT-1:3] == (MTIME_ADDR/8));
  wire mtimecmp_cs = (mem_addr[8*BYTE_AMNT-1:3] == (MTIMECMP_ADDR/8));

  assign inst_cache_enable = s_rom_enable & mem_rd_en;
  assign ram_chip_select = s_ram_chip_select;

  reg csr_reg_busy;
  always @(posedge clock, posedge reset) begin
    if(reset || csr_reg_busy) csr_reg_busy <= 1'b0;
    else if((mem_rd_en || mem_wr_en) &&
    (msip_cs || ssip_cs || mtime_cs || mtimecmp_cs)) csr_reg_busy <= 1'b1;
  end

  // Trocar por OR invés de mux?
  assign mem_busy =
    s_rom_enable ? inst_cache_busy
    : s_ram_chip_select ? ram_busy
    `ifdef UART_0
        : uart_0_cs ? uart_0_busy
    `endif
    : (msip_cs || ssip_cs || mtime_cs || mtimecmp_cs) ? csr_reg_busy
    : 1'b0;

  assign ram_output_enable = s_ram_chip_select ? mem_rd_en : 1'b0;
  assign ram_write_enable = s_ram_chip_select ? mem_wr_en : 1'b0;
  assign ram_byte_enable = s_ram_chip_select ? mem_byte_en : 0;

`ifdef UART_0
  assign uart_0_rd_en = uart_0_cs ? mem_rd_en : 1'b0;
  assign uart_0_wr_en = uart_0_cs ? mem_wr_en : 1'b0;
`endif

  assign msip_en = msip_cs & mem_wr_en;
  assign ssip_en = ssip_cs & mem_wr_en;
  assign mtime_en = mtime_cs & mem_wr_en;
  assign mtimecmp_en = mtimecmp_cs & mem_wr_en;
  /* //// */

  /* Endereçamento */
  assign inst_cache_addr[23:0] = mem_addr[23:0];
  assign inst_cache_addr[8*BYTE_AMNT-1:24] = 'b0;

  wire ram_address24 = (~mem_addr[24]) & (mem_addr[26] ^ mem_addr[25]);
  wire ram_address25 =
    (~mem_addr[26])&(mem_addr[25]&mem_addr[24])|mem_addr[26]&(~mem_addr[25])&(~mem_addr[24]);
  assign ram_address[25:0] = {ram_address25, ram_address24, mem_addr[23:0]};
  assign ram_address[8*BYTE_AMNT-1:26] = 'b0;

`ifdef UART_0
  assign uart_0_addr = mem_addr[4:0];
`endif
  /* //// */

  /* Entradas de dados  */
  assign rd_data =
    s_rom_enable ? inst_cache_data
    : s_ram_chip_select ? ram_read_data
    `ifdef UART_0
       : uart_0_cs ? uart_0_rd_data
    `endif
    : msip_cs ? msip
    : ssip_cs ? ssip
    `ifdef RV64I
      : mtime_cs ? mtime
      : mtimecmp_cs ? mtimecmp
    `else
      : mtime_cs ? (mem_addr[2] ? mtime[63:32] : mtime[31:0])
      : mtimecmp_cs ? (mem_addr[2] ? mtimecmp[63:32] : mtimecmp[31:0])
    `endif
    : 0;
  /* //// */

  /* Saídas de dados */
  // Tirar os muxes e passar direto
  assign ram_write_data = wr_data;

`ifdef UART_0
  assign uart_0_wr_data = wr_data;
`endif
  /* //// */

endmodule
