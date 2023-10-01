//
//! @file   memory_controller_tb.v
//! @brief  Testbench para a implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`timescale 1 ns / 100 ps

module memory_controller_tb;

  localparam integer ClockPeriod = 20;

  // Sinais do testbench
  reg CLK_I;
  reg RST_I;
  reg [63:0] inst_cache_memory[7:0];
  reg [63:0] ram_memory[7:0];
  integer i;

  // Entradas
  reg WE_I;
  reg CYC_I;
  reg [7:0] SEL_I;
  reg [63:0] DAT_I;
  reg [63:0] ADR_I;

  // Saídas
  wire [63:0] DAT_O;
  wire ACK_O;

  // Interface da Cache
  wire [63:0] inst_cache_DAT_O;
  wire [63:0] inst_cache_DAT_I = inst_cache_DAT_O;
  wire inst_cache_ACK_O;
  wire inst_cache_ACK_I = inst_cache_ACK_O;
  wire inst_cache_CYC_O;
  wire inst_cache_CYC_I = inst_cache_CYC_O;
  wire [63:0] inst_cache_ADR_O;
  wire [63:0] inst_cache_ADR_I = inst_cache_ADR_O;

  // Interface da ROM com a Cache
  wire [511:0] inst_DAT_O;
  wire [511:0] inst_DAT_I = inst_DAT_O;
  wire inst_ACK_O;
  wire inst_ACK_I = inst_ACK_O;
  wire inst_CYC_O;
  wire inst_CYC_I = inst_CYC_O;
  wire [63:0] inst_ADR_O;
  wire [63:0] inst_ADR_I = inst_ADR_O;

  // Interface da RAM
  wire [63:0] ram_DAT_O;
  wire [63:0] ram_rd_DAT_I = ram_DAT_O;
  wire ram_ACK_O;
  wire ram_ACK_I = ram_ACK_O;
  wire [63:0] ram_ADR_O;
  wire [63:0] ram_ADR_I = ram_ADR_O;
  wire [63:0] ram_wr_DAT_O;
  wire [63:0] ram_DAT_I = ram_wr_DAT_O;
  wire ram_TGC_O;
  wire ram_TGC_I = ram_TGC_O;
  wire ram_WE_O;
  wire ram_WE_I = ram_WE_O;
  wire ram_STB_O;
  wire ram_STB_I = ram_STB_O;
  wire [7:0] ram_SEL_O;
  wire [7:0] ram_SEL_I = ram_SEL_O;

  // Instanciação do DUT
  memory_controller DUT (
      .WE_I             (WE_I),
      .CYC_I            (CYC_I),
      .SEL_I            (SEL_I),
      .DAT_I          (DAT_I),
      .ADR_I         (ADR_I),
      .DAT_O          (DAT_O),
      .ACK_O         (ACK_O),
      .inst_cache_DAT_I  (inst_cache_DAT_I),
      .inst_cache_ACK_I  (inst_cache_ACK_I),
      .inst_cache_CYC_O(inst_cache_CYC_O),
      .inst_cache_ADR_O  (inst_cache_ADR_O),
      .ram_DAT_I    (ram_rd_DAT_I),
      .ram_ACK_I         (ram_ACK_I),
      .ram_ADR_O      (ram_ADR_O),
      .ram_DAT_O   (ram_wr_DAT_O),
      .ram_TGC_O(ram_TGC_O),
      .ram_WE_O (ram_WE_O),
      .ram_STB_O  (ram_STB_O),
      .ram_SEL_O  (ram_SEL_O)
  );

  instruction_cache #(
      .L2_CACHE_SIZE(8),  // bytes
      .L2_BLOCK_SIZE(6),  // bytes
      .L2_ADDR_SIZE (6),  // bits
      .L2_DATA_SIZE (3)   // bytes
  ) cache (
      .CLK_I            (CLK_I),
      .RST_I            (RST_I),
      .inst_DAT_I       (inst_DAT_I),
      .inst_ACK_I       (inst_ACK_I),
      .inst_CYC_O       (inst_CYC_O),
      .inst_ADR_O        (inst_ADR_O),
      .inst_cache_CYC_I (inst_cache_CYC_I),
      .inst_cache_ADR_I (inst_cache_ADR_I),
      .inst_cache_DAT_O (inst_cache_DAT_O),
      .inst_cache_ACK_O (inst_cache_ACK_O)
  );

  // Instanciação da memória ROM
  ROM #(
      .rom_init_file("./ROM.mif"),
      .word_size(64),
      .addr_size(6),
      .offset(3),
      .busy_cycles(12)
  ) rom (
      .CLK_I  (CLK_I),
      .CYC_I  (inst_CYC_I),
      .ADR_I  (inst_ADR_I[5:0]),
      .DAT_O  (inst_DAT_O),
      .ACK_O  (inst_ACK_O)
  );

  // Instanciação da memória RAM
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(24),
      .BYTE_SIZE(8),
      .DATA_SIZE(64),
      .BUSY_CYCLES(30)
  ) ram (
      .CLK_I        (CLK_I),
      .ADR_I        (ram_ADR_I),
      .DAT_I        (ram_DAT_I),
      .TGC_I        (ram_TGC_I),
      .WE_I         (ram_WE_I),
      .STB_I        (ram_STB_I),
      .SEL_I        (ram_SEL_I),
      .DAT_O        (ram_DAT_O),
      .ACK_O        (ram_ACK_O)
  );

  // Geração do CLK_I
  always #(ClockPeriod / 2) CLK_I = ~CLK_I;

  initial begin
    $readmemb("./ROM.mif", inst_cache_memory);
    $readmemb("./RAM.mif", ram_memory);

    // Inicialização das entradas
    CLK_I = 0;
    RST_I = 0;
    SEL_I = 0;
    DAT_I = 0;
    ADR_I = 0;

    // Resetando a cache
    @(negedge CLK_I);
    RST_I = 1;
    @(negedge CLK_I);
    RST_I = 0;

    // Teste da ROM
    SEL_I = 8'hFF;
    for (i = 0; i < 8; i = i + 1) begin
      @(negedge CLK_I);
      ADR_I  = 8 * i;  // acesso da ROM
      CYC_I = 1'b1;
      WE_I = 1'b0;
      @(negedge ACK_O);
      @(posedge ACK_O);
      if (DAT_O[31:0] !== inst_cache_memory[i][31:0]) begin
        $warning(
            "Erro no teste %d.1 da rom[31:0]:\n\trom[31:0] = 0x%h\n\tcontrolador[31:0] = 0x%h\n",
            i + 1, inst_cache_memory[i][31:0], DAT_O[31:0]);
        $warning("Erro no teste %d.1 da rom:\n\trom = 0x%h\n\tcontrolador = 0x%h\n", i + 1,
                 inst_cache_memory[i], DAT_O);
      end else $display("Acerto no teste %d.1 da ROM", i + 1);

      CYC_I = 1'b0;
      WE_I = 1'b0;

      @(negedge CLK_I);
      ADR_I  = 8 * i + 4;  // acesso da ROM
      CYC_I = 1'b1;
      WE_I = 1'b0;
      @(negedge ACK_O);
      @(posedge ACK_O);
      if (DAT_O[31:0] !== inst_cache_memory[i][63:32]) begin
        $warning(
            "Erro no teste %d.2 da rom[63:32]:\n\trom[63:32] = 0x%h\n\tcontrolador[31:0] = 0x%h\n",
            i + 1, inst_cache_memory[i][63:32], DAT_O[31:0]);
        $warning("Erro no teste %d.2 da rom:\n\trom = 0x%h\n\tcontrolador = 0x%h\n", i + 1,
                 inst_cache_memory[i], DAT_O);
      end else $display("Acerto no teste %d.2 da ROM", i + 1);
      CYC_I = 1'b0;
      WE_I = 1'b0;
    end


    // Teste de leitura da RAM
    for (i = 0; i < 8; i = i + 1) begin
      @(negedge CLK_I);
      ADR_I  = 2 ** 24 + 8 * i;  // acesso da RAM, começando no endereço 2^24
      CYC_I = 1'b1;
      WE_I = 1'b0;
      @(negedge ACK_O);
      @(posedge ACK_O);
      if (DAT_O !== ram_memory[i])
        $warning(
            "Erro no teste %d de leitura da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n",
            i + 1,
            ram_memory[i],
            DAT_O
        );
      else $display("Acerto no teste %d de leitura da RAM", i + 1);
      CYC_I = 1'b0;
      WE_I = 1'b0;

      // Escreve na RAM para teste de escrita a seguir
      @(negedge CLK_I);
      DAT_I = i;
      ram_memory[i] = i;  // atualiza conteúdo de memória da RAM
      CYC_I = 1'b1;
      WE_I = 1'b1;
      @(negedge ACK_O);
      @(posedge ACK_O);
      CYC_I = 1'b0;
      WE_I = 1'b0;
    end

    // Teste de escrita da RAM
    SEL_I = 8'hFF;
    for (i = 0; i < 8; i = i + 1) begin
      @(negedge CLK_I);
      ADR_I  = 2 ** 24 + 8 * i;  // acesso da RAM, começando no endereço 2^24
      CYC_I = 1'b1;
      WE_I = 1'b0;
      @(negedge ACK_O);
      @(posedge ACK_O);
      if (DAT_O !== ram_memory[i])
        $warning(
            "Erro no teste %d de escrita da ram:\n\tram = 0x%h\n\tcontrolador = 0x%h\n",
            i + 1,
            ram_memory[i],
            DAT_O
        );
      else $display("Acerto no teste %d de escrita da RAM", i + 1);
      CYC_I = 1'b1;
      WE_I = 1'b0;
    end

    $stop;
  end
endmodule
