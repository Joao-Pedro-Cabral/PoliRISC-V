//
//! @file   memory_controller_tb.v
//! @brief  Testbench para a implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`timescale 1 ns / 100 ps

module memory_controller_tb;

  // Sinais do testbench
  reg  clock;
  reg [63:0] rom_memory [7:0];
  reg [63:0] ram_memory [7:0];
  integer i;

  // Entradas
  reg transfer_enable;
  reg [7:0] byte_write_enable;
  reg [63:0] write_data;
  reg [63:0] mem_address;
  
  // Saídas
  wire [63:0] read_data;
  wire transfer_busy;
  
  // Interface da ROM
  wire [63:0] rom_data;
  wire rom_busy;
  wire rom_enable;
  wire [63:0] rom_addr;
  
  // Interface da RAM
  wire [63:0] ram_read_data;
  wire ram_busy;
  wire [63:0] ram_address;
  wire [63:0] ram_write_data;
  wire ram_output_enable;
  wire ram_chip_select;
  wire [7:0] ram_byte_write_enable;

  // Instanciação do DUT
  memory_controller DUT (
    .transfer_enable(transfer_enable),
    .byte_write_enable(byte_write_enable),
    .write_data(write_data),
    .mem_address(mem_address),
    .read_data(read_data),
    .transfer_busy(transfer_busy),
    .rom_data(rom_data),
    .rom_busy(rom_busy),
    .rom_enable(rom_enable),
    .rom_addr(rom_addr),
    .ram_read_data(ram_read_data),
    .ram_busy(ram_busy),
    .ram_address(ram_address),
    .ram_write_data(ram_write_data),
    .ram_output_enable(ram_output_enable),
    .ram_chip_select(ram_chip_select),
    .ram_byte_write_enable(ram_byte_write_enable)
  );

  // Instanciação da memória ROM
  ROM #(.rom_init_file("./MIFs/memory/ROM/rom_init_file.mif"), .word_size(8), .addr_size(6), .offset(3), .busy_time(12))
      rom (.clock(clock), .enable(rom_enable), .addr(rom_addr), .data(rom_data), .busy(rom_busy));

  // Instanciação da memória RAM
  single_port_ram
  #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"),
      .ADDR_SIZE(6),
      .BYTE_SIZE(8),
      .DATA_SIZE(64),
      .BUSY_TIME(30)
  )
  ram
  (
      .clk(clock),
      .address(ram_address),
      .write_data(ram_write_data),
      .output_enable(ram_output_enable),
      .chip_select(ram_chip_select),
      .byte_write_enable(ram_byte_write_enable),
      .read_data(ram_read_data),
      .busy(ram_busy)
  );

      
  // Geração do clock
  always #3 clock = ~clock;

  initial begin
    $readmemb("./MIFs/memory/ROM/rom_tb_file.mif", rom_memory);
    $readmemb("./MIFs/memory/RAM/ram_tb_file.mif", ram_memory);

    // Inicialização das entradas
    clock = 0;
    transfer_enable = 0;
    byte_write_enable = 0;
    write_data = 0;
    mem_address = 0;

    // Teste da ROM
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_address = 8*i; // acesso da ROM
      transfer_enable = 1;
      @(posedge rom_busy);
      @(negedge rom_busy);
      if(read_data !== rom_memory[i]) 
        $warning("Erro no teste %d da rom:\n\trom = 0x%h\n\tcontrolador = 0x%h\n", i+1, rom_memory[i], read_data);
      else
        $display("Acerto no teste %d da ROM", i+1);
      transfer_enable = 0;
    end
    

    // Teste de leitura da RAM
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_address = 2**24 + 8*i; // acesso da RAM, começando no endereço 2^24
      transfer_enable = 1;
      @(posedge ram_busy);
      @(negedge ram_busy);
      if(read_data !== ram_memory[i]) 
        $warning("Erro no teste %d de leitura da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n", i+1, ram_memory[i], read_data);
      else
        $display("Acerto no teste %d de leitura da RAM", i+1);
      transfer_enable = 0;
      
      // Escreve na RAM para teste de escrita a seguir
      @(negedge clock);
      write_data = i;
      ram_memory[i] = i; // atualiza conteúdo de memória da RAM
      byte_write_enable = 8'hFF;
      @(posedge ram_busy);
      @(negedge ram_busy);
      byte_write_enable = 8'h00;
    end

    // Teste de escrita da RAM
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_address = 2**24 + 8*i; // acesso da RAM, começando no endereço 2^24
      transfer_enable = 1;
      @(posedge ram_busy);
      @(negedge ram_busy);
      if(read_data !== ram_memory[i]) 
        $warning("Erro no teste %d de escrita da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n", i+1, ram_memory[i], read_data);
      else
        $display("Acerto no teste %d de escrita da RAM", i+1);
      transfer_enable = 0;
    end

    $stop;
  end
endmodule
