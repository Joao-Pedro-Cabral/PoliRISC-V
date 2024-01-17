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
    parameter [63:0] MSIP_ADDR = 32'hFFFFFFC0,
    parameter [63:0] MTIME_ADDR = 32'hFFFFFFE0, // Alinhado em 8 bytes
    parameter [63:0] MTIMECMP_ADDR = 32'hFFFFFFF0 // Alinhado em 8 bytes
) (
    /* Interface com o cache de instruções */
    input  wire [8*BYTE_AMNT-1:0] inst_cache_DAT_I,
    input  wire inst_cache_ACK_I,
    output wire inst_cache_enable,
    output wire [8*BYTE_AMNT-1:0] inst_cache_ADR_O,
    /* //// */

    /* Interface com a memória RAM */
    input  wire [8*BYTE_AMNT-1:0] ram_DAT_I,
    input  wire ram_ACK_I,
    output wire [8*BYTE_AMNT-1:0] ram_ADR_O,
    output wire [8*BYTE_AMNT-1:0] ram_DAT_O,
    output wire ram_output_enable,
    output wire ram_write_enable,
    output wire ram_chip_select,
    output wire [BYTE_AMNT-1:0] ram_byte_enable,
    /* //// */

    /* Registradores do CSR mapeados em memória */
    input  wire csr_mem_ACK_I,
    input  wire [8*BYTE_AMNT-1:0] csr_mem_DAT_I,
    output wire [8*BYTE_AMNT-1:0] csr_mem_DAT_O,
    output wire csr_mem_rd_en,
    output wire csr_mem_wr_en,
    output wire [2:0] csr_mem_ADR_O,

    /* Interface com a UART */
`ifdef UART_0
    input  wire  [8*BYTE_AMNT-1:0] uart_0_DAT_I,
    input  wire  uart_0_ACK_I,
    output wire  uart_0_rd_en,
    output wire  uart_0_wr_en,
    output wire  [4:0] uart_0_ADR_O,
    output wire  [8*BYTE_AMNT-1:0] uart_0_DAT_O,
`endif
    /* //// */

    /* Interface com o processador */
    input wire cpu_CYC_I,
    input wire cpu_STB_I,
    input wire cpu_WE_I,
    input wire [BYTE_AMNT-1:0] mem_byte_en,
    input wire [8*BYTE_AMNT-1:0] cpu_DAT_I,
    input wire [8*BYTE_AMNT-1:0] cpu_ADR_I,

    output wire [8*BYTE_AMNT-1:0] cpu_DAT_O,
    output wire cpu_ACK_O
    /* //// */
);

  /* Sinais de controle */
  wire s_rom_enable = cpu_ADR_I[8*BYTE_AMNT-1:24] == 0 ? 1'b1 : 1'b0;  // 16 MiB para a ROM
  wire s_ram_chip_select =
    cpu_ADR_I[8*BYTE_AMNT-1:24] <= 'b100 && cpu_ADR_I[8*BYTE_AMNT-1:24] >= 'b1 ? 1'b1
    : 1'b0;  // 64 MiB para a RAM
`ifdef UART_0
  wire uart_0_cs =
    cpu_ADR_I[8*BYTE_AMNT-1:12] >= 'h10013 && cpu_ADR_I[8*BYTE_AMNT-1:0] <= 'h10013018 ? 1'b1
    : 1'b0;
`endif

  wire msip_cs = (cpu_ADR_I == MSIP_ADDR);
  wire mtime_cs, mtimecmp_cs;
  `ifdef RV64I
    assign mtime_cs = cpu_ADR_I == MTIME_ADDR;
    assign mtimecmp_cs = cpu_ADR_I == MTIMECMP_ADDR;
  `else
    assign mtime_cs = (cpu_ADR_I[8*BYTE_AMNT-1:3] == MTIME_ADDR/8) &&
            (cpu_ADR_I[1:0] == MTIME_ADDR%4);
    assign mtimecmp_cs = cpu_ADR_I[8*BYTE_AMNT-1:3] == MTIMECMP_ADDR/8 &&
            (cpu_ADR_I[1:0] == MTIMECMP_ADDR%4);
  `endif
  wire csr_mem_cs = msip_cs | mtime_cs | mtimecmp_cs;

  assign inst_cache_enable = s_rom_enable & mem_rd_en;
  assign ram_chip_select = s_ram_chip_select;

  // Trocar por OR invés de mux?
  assign cpu_ACK_O =
    s_rom_enable ? inst_cache_ACK_I
    : s_ram_chip_select ? ram_ACK_I
    `ifdef UART_0
        : uart_0_cs ? uart_0_ACK_I
    `endif
    : csr_mem_cs ? csr_mem_ACK_I
    : 1'b0;

  assign ram_output_enable = s_ram_chip_select ? mem_rd_en : 1'b0;
  assign ram_write_enable = s_ram_chip_select ? mem_wr_en : 1'b0;
  assign ram_byte_enable = s_ram_chip_select ? mem_byte_en : 0;

`ifdef UART_0
  assign uart_0_rd_en = uart_0_cs ? mem_rd_en : 1'b0;
  assign uart_0_wr_en = uart_0_cs ? mem_wr_en : 1'b0;
`endif

  assign msip_en = msip_cs;
  assign mtime_en = mtime_cs;
  assign mtimecmp_en = mtimecmp_cs;

  assign csr_mem_wr_en = csr_mem_cs & mem_wr_en;
  assign csr_mem_rd_en = csr_mem_cs & mem_rd_en;
  /* //// */

  /* Endereçamento */
  assign inst_cache_ADR_O[23:0] = cpu_ADR_I[23:0];
  assign inst_cache_ADR_O[8*BYTE_AMNT-1:24] = 'b0;

  wire ram_address24 = (~cpu_ADR_I[24]) & (cpu_ADR_I[26] ^ cpu_ADR_I[25]);
  wire ram_address25 =
    (~cpu_ADR_I[26])&(cpu_ADR_I[25]&cpu_ADR_I[24])|cpu_ADR_I[26]&(~cpu_ADR_I[25])&(~cpu_ADR_I[24]);
  assign ram_address[25:0] = {ram_address25, ram_address24, cpu_ADR_I[23:0]};
  assign ram_address[8*BYTE_AMNT-1:26] = 'b0;

`ifdef UART_0
  assign uart_0_ADR_O = cpu_ADR_I[4:0];
`endif

  assign csr_mem_ADR_O[1:0] = msip_cs ? 2'b00 :
                            (mtime_cs ? 2'b10 :
                            (mtimecmp_cs ? 2'b11 : 2'b00));
  assign csr_mem_ADR_O[2] = cpu_ADR_I[2];
  /* //// */

  /* Entradas de dados  */
  assign cpu_DAT_O =
    s_rom_enable ? inst_cache_DAT_I
    : s_ram_chip_select ? ram_DAT_I
    `ifdef UART_0
       : uart_0_cs ? uart_0_DAT_I
    `endif
    : csr_mem_cs ? csr_mem_DAT_I
    : 0;
  /* //// */

  /* Saídas de dados */
  assign ram_DAT_O = cpu_DAT_I;

`ifdef UART_0
  assign uart_0_DAT_O = cpu_DAT_I;
`endif

  assign csr_mem_DAT_O = cpu_DAT_I;
  /* //// */

endmodule
