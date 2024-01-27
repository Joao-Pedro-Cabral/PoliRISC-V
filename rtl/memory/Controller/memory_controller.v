//
//! @file   memory_controller.v
//! @brief  Implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`include "macros.vh"
`include "extensions.vh"

module memory_controller #(
    parameter integer BYTE_AMNT = 8,
    parameter [63:0] ROM_ADDR_INIT = 0,
    parameter [63:0] ROM_ADDR_END = 32'h00FFFFFF,
    parameter [63:0] RAM_ADDR_INIT = 32'h01000000,
    parameter [63:0] RAM_ADDR_END = 32'h04FFFFFF,
    parameter [63:0] UART_0_ADDR_INIT = 32'h10013000, // UART has fixed size
    parameter [63:0] MSIP_ADDR = 32'hFFFFFFC0,
    parameter [63:0] MTIME_ADDR = 32'hFFFFFFE0, // Alinhado em 8 bytes
    parameter [63:0] MTIMECMP_ADDR = 32'hFFFFFFF0  // Alinhado em 8 bytes
) (
    /* Interface com o cache de instruções */
    input  wire [8*BYTE_AMNT-1:0] rom_DAT_I,
    input  wire rom_ACK_I,
    output wire rom_CYC_O,
    output wire rom_STB_O,
    output wire [8*BYTE_AMNT-1:0] rom_ADR_O,
    /* //// */

    /* Interface com a memória RAM */
    input  wire [8*BYTE_AMNT-1:0] ram_DAT_I,
    input  wire ram_ACK_I,
    output wire [8*BYTE_AMNT-1:0] ram_ADR_O,
    output wire [8*BYTE_AMNT-1:0] ram_DAT_O,
    output wire ram_CYC_O,
    output wire ram_STB_O,
    output wire ram_WE_O,
    output wire [BYTE_AMNT-1:0] ram_SEL_O,
    /* //// */

    /* Registradores do CSR mapeados em memória */
    input  wire csr_mem_ACK_I,
    input  wire [8*BYTE_AMNT-1:0] csr_mem_DAT_I,
    output wire [8*BYTE_AMNT-1:0] csr_mem_DAT_O,
    output wire csr_mem_CYC_O,
    output wire csr_mem_STB_O,
    output wire csr_mem_WE_O,
    output wire [2:0] csr_mem_ADR_O,

    /* Interface com a UART */
`ifdef UART_0
    input  wire  [8*BYTE_AMNT-1:0] uart_0_DAT_I,
    input  wire  uart_0_ACK_I,
    output wire  uart_0_CYC_O,
    output wire  uart_0_STB_O,
    output wire  uart_0_WE_O,
    output wire  [4:0] uart_0_ADR_O,
    output wire  [8*BYTE_AMNT-1:0] uart_0_DAT_O,
`endif
    /* //// */

    /* Interface com o processador */
    input wire cpu_CYC_I,
    input wire cpu_STB_I,
    input wire cpu_WE_I,
    input wire [BYTE_AMNT-1:0] cpu_SEL_I,
    input wire [8*BYTE_AMNT-1:0] cpu_DAT_I,
    input wire [8*BYTE_AMNT-1:0] cpu_ADR_I,

    output wire [8*BYTE_AMNT-1:0] cpu_DAT_O,
    output wire cpu_ACK_O
    /* //// */
);

  /* Sinais de controle */
  /* Chip Select */
  wire rom_cs = (cpu_ADR_I >= ROM_ADDR_INIT && cpu_ADR_I <= ROM_ADDR_END); // Normally 16 MiB
  wire ram_cs = (cpu_ADR_I >= RAM_ADDR_INIT && cpu_ADR_I <= RAM_ADDR_END); // Normally 64 MiB
`ifdef UART_0  // Always 24
  wire uart_0_cs = (cpu_ADR_I >= UART_0_ADDR_INIT && cpu_ADR_I <= (UART_0_ADDR_INIT + 24));
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

  /* CPU ACK */
  // Trocar por OR invés de mux?
  assign cpu_ACK_O =
    rom_cs ? rom_ACK_I
    : ram_cs ? ram_ACK_I
    `ifdef UART_0
        : uart_0_cs ? uart_0_ACK_I
    `endif
    : csr_mem_cs ? csr_mem_ACK_I
    : 1'b0;

  /* CYC */
  assign rom_CYC_O = rom_cs & cpu_CYC_I;
  assign ram_CYC_O = ram_cs & cpu_CYC_I;
  assign csr_mem_CYC_O = csr_mem_cs & cpu_CYC_I;
`ifdef UART_0
  assign uart_0_CYC_O = uart_0_cs & cpu_CYC_I;
`endif

  /* STB */
  assign rom_STB_O = rom_cs & cpu_STB_I;
  assign ram_STB_O = ram_cs & cpu_STB_I;
  assign csr_mem_STB_O = csr_mem_cs & cpu_STB_I;
`ifdef UART_0
  assign uart_0_STB_O = uart_0_cs & cpu_STB_I;
`endif

  /* WE */
  assign ram_WE_O = ram_cs & cpu_WE_I;
  assign csr_mem_WE_O = csr_mem_cs & cpu_WE_I;
`ifdef UART_0
  assign uart_0_WE_O = uart_0_cs & cpu_WE_I;
`endif

  /* SEL */
  assign ram_SEL_O = {BYTE_AMNT{ram_cs}} & cpu_SEL_I;

  /* //// */

  /* Endereçamento */
  /* ADR */
  assign rom_ADR_O = cpu_ADR_I;
  assign ram_ADR_O = cpu_ADR_I;
`ifdef UART_0
  assign uart_0_ADR_O = cpu_ADR_I[4:0];
`endif
  assign csr_mem_ADR_O[1:0] = msip_cs ? 2'b00 :
                            (mtime_cs ? 2'b10 :
                            (mtimecmp_cs ? 2'b11 : 2'b00));
  assign csr_mem_ADR_O[2] = cpu_ADR_I[2];
  /* //// */

  /* Dados */
  /* DAT_O */
  assign cpu_DAT_O =
    rom_cs ? rom_DAT_I
    : ram_cs ? ram_DAT_I
    `ifdef UART_0
       : uart_0_cs ? uart_0_DAT_I
    `endif
    : csr_mem_cs ? csr_mem_DAT_I
    : 0;

  /* DAT_I */
  assign ram_DAT_O = cpu_DAT_I;

`ifdef UART_0
  assign uart_0_DAT_O = cpu_DAT_I;
`endif

  assign csr_mem_DAT_O = cpu_DAT_I;
  /* //// */

endmodule
