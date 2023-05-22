//
//! @file   memory_controller.v
//! @brief  Implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`timescale 1 ns / 100 ps
module memory_controller #(
    parameter integer BYTE_AMNT = 8
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

    /* Interface com a UART */
`ifdef UART
`endif
    /* //// */

    /* Interface com o processador */
    input mem_rd_en,
    input mem_wr_en,
    input [BYTE_AMNT-1:0] mem_byte_en,
    input [8*BYTE_AMNT-1:0] wr_data,
    input [8*BYTE_AMNT-1:0] mem_addr,

    output [8*BYTE_AMNT-1:0] rd_data,
    output mem_busy
    /* //// */

);

  /* Sinais de controle */
  wire s_rom_enable = mem_addr[8*BYTE_AMNT-1:24] == 0 ? 1'b1 : 1'b0;  // 16 MiB para a ROM
  // 64 MiB para a RAM
  wire   s_ram_chip_select     = mem_addr[8*BYTE_AMNT-1:24] <= 'b100
                                 && mem_addr[8*BYTE_AMNT-1:24] >= 'b1 ? 1'b1 : 1'b0;
  assign inst_cache_enable = s_rom_enable & mem_rd_en;
  assign ram_chip_select = s_ram_chip_select;

  assign mem_busy = s_rom_enable ? inst_cache_busy : s_ram_chip_select ? ram_busy : 1'b0;

  assign ram_output_enable = s_ram_chip_select ? mem_rd_en : 1'b0;
  assign ram_write_enable = s_ram_chip_select ? mem_wr_en : 1'b0;
  assign ram_byte_enable = s_ram_chip_select ? mem_byte_en : 0;
  /* //// */

  /* Endereçamento */
  assign inst_cache_addr[23:0] = mem_addr[23:0];
  assign inst_cache_addr[8*BYTE_AMNT-1:24] = 'b0;

  wire ram_address24 = (~mem_addr[24]) & (mem_addr[26] ^ mem_addr[25]);
  wire ram_address25 = (~mem_addr[26])&(mem_addr[25]&mem_addr[24])|
                        mem_addr[26]&(~mem_addr[25])&(~mem_addr[24]);
  assign ram_address[25:0] = {ram_address25, ram_address24, mem_addr[23:0]};
  assign ram_address[8*BYTE_AMNT-1:26] = 'b0;
  /* //// */

  /* Entradas de dados  */
  genvar i;
  generate
    for (i = 0; i < BYTE_AMNT; i = i + 1) begin : g_read_data
      assign rd_data[(i+1)*8-1 -: 8] = s_rom_enable ? inst_cache_data[(i+1)*8-1 -: 8] : (s_ram_chip_select ? ram_read_data[(i+1)*8-1 -: 8] : 'b0);
    end
  endgenerate
  /* //// */

  /* Saídas de dados */
  assign ram_write_data = s_ram_chip_select ? wr_data : 'b0;
  /* //// */

endmodule
