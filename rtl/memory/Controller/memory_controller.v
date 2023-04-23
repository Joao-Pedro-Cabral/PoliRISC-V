module memory_controller
(
  /* Interface com o processador */
  input  wire transfer_enable,         
  input  wire [7:0] byte_write_enable, 
  input  wire [63:0] write_data,       
  input  wire [63:0] mem_address,      

  output wire [63:0] read_data,
  output wire transfer_busy,
  /* //// */

  /* Interface com a memória ROM */
  input  [63:0] rom_data;
  input  rom_busy;
  output wire rom_enable;
  output wire [63:0] rom_addr;
  /* //// */
  
  /* Interface com a memória RAM */
  input  [63:0] ram_read_data,
  input  ram_busy,
  output [63:0] ram_address,
  output [63:0] ram_write_data,
  output ram_output_enable,
  output ram_chip_select,
  output [7:0] ram_byte_write_enable
  /* //// */

  /* Interface com a UART */
  /* //// */
);

  /* Sinais de controle */
  wire   s_rom_enable          = mem_address[63:24] == 0     && transfer_enable           ? 1'b1 : 1'b0; // 16 MiB para a ROM
  wire   s_ram_chip_select     = mem_address[63:24] <= 'b100 && mem_address[63:24] >= 'b1 ? 1'b1 : 1'b0; // 64 MiB para a RAM
  assign rom_enable            = s_rom_enable;
  assign ram_chip_select       = s_ram_chip_select;

  assign transfer_busy         = s_rom_enable ? rom_busy : s_ram_chip_select ? ram_busy : 1'b0;

  assign ram_output_enable     = s_ram_chip_select ? transfer_enable   : 1'b0;

  assign ram_byte_write_enable = s_ram_chip_select ? byte_write_enable : 8'b0;
  /* //// */

  /* Endereçamento */
  assign rom_addr    = mem_address;
  assign ram_address = mem_address;
  /* //// */
  
  /* Entradas de dados  */
  assign read_data = s_rom_enable ? rom_data : s_ram_chip_select ? ram_read_data : 64'b0;
  /* //// */

  /* Saídas de dados */
  assign write_data = s_ram_chip_select ? ram_write_data : 64'b0;
  /* //// */

endmodule
