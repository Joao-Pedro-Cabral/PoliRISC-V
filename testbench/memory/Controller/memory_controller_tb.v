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
  reg  reset;
  reg [63:0] inst_cache_memory [7:0];
  reg [63:0] ram_memory [7:0];
  integer i;

  // Entradas
  reg mem_rd_en;
  reg mem_wr_en;
  reg [7:0] mem_byte_en;
  reg [63:0] wr_data;
  reg [63:0] mem_addr;
  
  // Saídas
  wire [63:0] rd_data;
  wire mem_busy;
  
  // Interface da Cache
  wire [63:0] inst_cache_data;
  wire inst_cache_busy;
  wire inst_cache_enable;
  wire [63:0] inst_cache_addr;

  // Interface da ROM com a Cache
  wire [63:0] inst_data;
  wire inst_busy;
  wire inst_enable;
  wire [63:0] inst_addr;
  
  // Interface da RAM
  wire [63:0] ram_read_data;
  wire ram_busy;
  wire [63:0] ram_address;
  wire [63:0] ram_write_data;
  wire ram_output_enable;
  wire ram_write_enable;
  wire ram_chip_select;
  wire [7:0] ram_byte_enable;

  // Instanciação do DUT
  memory_controller DUT(
    .mem_rd_en(mem_rd_en),
    .mem_wr_en(mem_wr_en),
    .mem_byte_en(mem_byte_en),
    .wr_data(wr_data),
    .mem_addr(mem_addr),
    .rd_data(rd_data),
    .mem_busy(mem_busy),
    .inst_cache_data(inst_cache_data),
    .inst_cache_busy(inst_cache_busy),
    .inst_cache_enable(inst_cache_enable),
    .inst_cache_addr(inst_cache_addr),
    .ram_read_data(ram_read_data),
    .ram_busy(ram_busy),
    .ram_address(ram_address),
    .ram_write_data(ram_write_data),
    .ram_output_enable(ram_output_enable),
    .ram_write_enable(ram_write_enable),
    .ram_chip_select(ram_chip_select),
    .ram_byte_enable(ram_byte_enable)
  );

  instruction_cache cache (
    .clock(clock),
    .reset(reset),
    .inst_data(inst_data),
    .inst_busy(inst_busy),
    .inst_enable(inst_enable),
    .inst_addr(inst_addr),
    .inst_cache_enable(inst_cache_enable),
    .inst_cache_addr(inst_cache_addr),
    .inst_cache_data(inst_cache_data),
    .inst_cache_busy(inst_cache_busy)
  ); 
  
  // Instanciação da memória ROM
  ROM #(.rom_init_file("./MIFs/memory/ROM/rom_init_file.mif"), .word_size(8), .addr_size(6), .offset(3), .busy_time(12))
      rom (.clock(clock), .enable(inst_enable), .addr(inst_addr[5:0]), .data(inst_data), .busy(inst_busy));

  // Instanciação da memória RAM
  single_port_ram
  #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"),
      .ADDR_SIZE(24),
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
      .write_enable(ram_write_enable),
      .chip_select(ram_chip_select),
      .byte_enable(ram_byte_enable),
      .read_data(ram_read_data),
      .busy(ram_busy)
  );

      
  // Geração do clock
  always #3 clock = ~clock;

  initial begin
    $readmemb("./MIFs/memory/ROM/rom_tb_file.mif", inst_cache_memory);
    $readmemb("./MIFs/memory/RAM/ram_tb_file.mif", ram_memory);

    // Inicialização das entradas
    clock = 0;
    reset = 0;
    mem_rd_en = 0;
    mem_byte_en = 0;
    wr_data = 0;
    mem_addr = 0;

    // Resetando a cache
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;

    // Teste da ROM
    mem_byte_en = 8'hFF;
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_addr = 8*i; // acesso da ROM
      mem_rd_en = 1;
      @(posedge mem_busy);
      @(negedge mem_busy);
      if(rd_data[31:0] !== inst_cache_memory[i][31:0]) begin
        $warning("Erro no teste %d.1 da rom[31:0]:\n\trom[31:0] = 0x%h\n\tcontrolador[31:0] = 0x%h\n", i+1, inst_cache_memory[i][31:0], rd_data[31:0]);
        $warning("Erro no teste %d.1 da rom:\n\trom = 0x%h\n\tcontrolador = 0x%h\n", i+1, inst_cache_memory[i], rd_data);
      end
      else
        $display("Acerto no teste %d.1 da ROM", i+1);

      mem_rd_en = 0;

      @(negedge clock);
      mem_addr = 8*i + 4; // acesso da ROM
      mem_rd_en = 1;
      @(posedge mem_busy);
      @(negedge mem_busy);
      if(rd_data[31:0] !== inst_cache_memory[i][63:32]) begin
        $warning("Erro no teste %d.2 da rom[63:32]:\n\trom[63:32] = 0x%h\n\tcontrolador[31:0] = 0x%h\n", i+1, inst_cache_memory[i][63:32], rd_data[31:0]);
        $warning("Erro no teste %d.2 da rom:\n\trom = 0x%h\n\tcontrolador = 0x%h\n", i+1, inst_cache_memory[i], rd_data);
      end
      else
        $display("Acerto no teste %d.2 da ROM", i+1);
      mem_rd_en = 0;
    end
    

    // Teste de leitura da RAM
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_addr = 2**24 + 8*i; // acesso da RAM, começando no endereço 2^24
      mem_rd_en = 1;
      @(posedge mem_busy);
      @(negedge mem_busy);
      if(rd_data !== ram_memory[i]) 
        $warning("Erro no teste %d de leitura da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n", i+1, ram_memory[i], rd_data);
      else
        $display("Acerto no teste %d de leitura da RAM", i+1);
      mem_rd_en = 0;
      
      // Escreve na RAM para teste de escrita a seguir
      @(negedge clock);
      wr_data = i;
      ram_memory[i] = i; // atualiza conteúdo de memória da RAM
      mem_wr_en = 1'b1;
      @(posedge mem_busy);
      @(negedge mem_busy);
      mem_wr_en = 1'b0;
    end

    // Teste de escrita da RAM
    mem_byte_en = 8'hFF;
    for(i = 0; i < 8; i = i + 1) begin
      @(negedge clock);
      mem_addr = 2**24 + 8*i; // acesso da RAM, começando no endereço 2^24
      mem_rd_en = 1;
      @(posedge mem_busy);
      @(negedge mem_busy);
      if(rd_data !== ram_memory[i]) 
        $warning("Erro no teste %d de escrita da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n", i+1, ram_memory[i], rd_data);
      else
        $display("Acerto no teste %d de escrita da RAM", i+1);
      mem_rd_en = 0;
    end

    $stop;
  end
endmodule
