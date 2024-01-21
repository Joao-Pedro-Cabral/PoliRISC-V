//
//! @file   memory_controller_tb.v
//! @brief  Testbench para a implementação de um controlador de barramento para memórias
//          e dispositivos
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-04-24
//

`define ASSERT(condition) if (!(condition)) $stop

`timescale 1 ns / 100 ps

module memory_controller_tb;

  localparam integer ClockPeriod = 20;
  localparam integer BusyCycles = 10;
  localparam reg [31:0] RomAddrInit = 0;
  localparam reg [31:0] RamAddrInit = 32'h01000000;
  localparam reg [31:0] Uart0AddrInit = 32'h10013000;
  localparam reg [31:0] MsipAddr = 32'hFFFFFFC0;
  localparam reg [31:0] MtimeAddr = 32'hFFFFFFE0;
  localparam reg [31:0] MtimeCmpAddr = 32'hFFFFFFF0;

  // Sinais do testbench
  reg CLK_I;
  reg RST_I;
  reg [31:0] rom_memory[127:0];
  reg [31:0] ram_memory[127:0];
  reg [7:0] tx_data;
  reg rx_empty;
  integer i;

  // Entradas
  reg WE_I;
  reg CYC_I;
  wire STB_I = CYC_I;
  reg [3:0] SEL_I;
  reg [31:0] DAT_I;
  reg [31:0] ADR_I;

  // Saídas
  wire [31:0] DAT_O;
  wire ACK_O;

  // Interface da Cache
  wire [31:0] rom_DAT_O;
  wire [31:0] rom_DAT_I = rom_DAT_O;
  wire rom_ACK_O;
  wire rom_ACK_I = rom_ACK_O;
  wire rom_CYC_O;
  wire rom_CYC_I = rom_CYC_O;
  wire rom_STB_O;
  wire rom_STB_I = rom_STB_O;
  wire [31:0] rom_ADR_O;
  wire [31:0] rom_ADR_I = rom_ADR_O;

  // Interface da ROM com a Cache
  wire [127:0] inst_DAT_O;
  wire [127:0] inst_DAT_I = inst_DAT_O;
  wire inst_ACK_O;
  wire inst_ACK_I = inst_ACK_O;
  wire inst_CYC_O;
  wire inst_CYC_I = inst_CYC_O;
  wire inst_STB_O;
  wire inst_STB_I = inst_STB_O;
  wire [31:0] inst_ADR_O;
  wire [31:0] inst_ADR_I = inst_ADR_O;

  // Interface da RAM
  wire [31:0] ram_DAT_O;
  wire [31:0] ram_rd_DAT_I = ram_DAT_O;
  wire ram_ACK_O;
  wire ram_ACK_I = ram_ACK_O;
  wire [31:0] ram_ADR_O;
  wire [31:0] ram_ADR_I = ram_ADR_O;
  wire [31:0] ram_wr_DAT_O;
  wire [31:0] ram_DAT_I = ram_wr_DAT_O;
  wire ram_STB_O;
  wire ram_STB_I = ram_STB_O;
  wire ram_CYC_O;
  wire ram_CYC_I = ram_CYC_O;
  wire ram_WE_O;
  wire ram_WE_I = ram_WE_O;
  wire [3:0] ram_SEL_O;
  wire [3:0] ram_SEL_I = ram_SEL_O;

  // Interface do CSR_mem
  wire [31:0] csr_mem_DAT_O;
  wire [31:0] csr_mem_rd_DAT_I = csr_mem_DAT_O;
  wire csr_mem_ACK_O;
  wire csr_mem_ACK_I = csr_mem_ACK_O;
  wire [2:0] csr_mem_ADR_O;
  wire [2:0] csr_mem_ADR_I = csr_mem_ADR_O;
  wire [31:0] csr_mem_wr_DAT_O;
  wire [31:0] csr_mem_DAT_I = csr_mem_wr_DAT_O;
  wire csr_mem_STB_O;
  wire csr_mem_STB_I = csr_mem_STB_O;
  wire csr_mem_CYC_O;
  wire csr_mem_CYC_I = csr_mem_CYC_O;
  wire csr_mem_WE_O;
  wire csr_mem_WE_I = csr_mem_WE_O;

  // Interface da UART
  wire [31:0] uart_0_DAT_O;
  wire [31:0] uart_0_rd_DAT_I = uart_0_DAT_O;
  wire uart_0_ACK_O;
  wire uart_0_ACK_I = uart_0_ACK_O;
  wire [4:0] uart_0_ADR_O;
  wire [4:0] uart_0_ADR_I = uart_0_ADR_O;
  wire [31:0] uart_0_wr_DAT_O;
  wire [31:0] uart_0_DAT_I = uart_0_wr_DAT_O;
  wire uart_0_STB_O;
  wire uart_0_STB_I = uart_0_STB_O;
  wire uart_0_CYC_O;
  wire uart_0_CYC_I = uart_0_CYC_O;
  wire uart_0_WE_O;
  wire uart_0_WE_I = uart_0_WE_O;
  wire rx_tx;

  // Instanciação do DUT
  memory_controller #(
      .BYTE_AMNT(4),
      .ROM_ADDR_INIT(0),
      .ROM_ADDR_END(32'h00FFFFFF),
      .RAM_ADDR_INIT(RamAddrInit),
      .RAM_ADDR_END(32'h04FFFFFF),
      .UART_0_ADDR_INIT(Uart0AddrInit),
      .MSIP_ADDR(MsipAddr),
      .MTIME_ADDR(MtimeAddr),
      .MTIMECMP_ADDR(MtimeCmpAddr)
  ) DUT (
      .cpu_WE_I     (WE_I),
      .cpu_CYC_I    (CYC_I),
      .cpu_STB_I    (STB_I),
      .cpu_SEL_I    (SEL_I),
      .cpu_DAT_I    (DAT_I),
      .cpu_ADR_I    (ADR_I),
      .cpu_DAT_O    (DAT_O),
      .cpu_ACK_O    (ACK_O),
      .rom_DAT_I    (rom_DAT_I),
      .rom_ACK_I    (rom_ACK_I),
      .rom_CYC_O    (rom_CYC_O),
      .rom_STB_O    (rom_STB_O),
      .rom_ADR_O    (rom_ADR_O),
      .ram_DAT_I    (ram_rd_DAT_I),
      .ram_ACK_I    (ram_ACK_I),
      .ram_ADR_O    (ram_ADR_O),
      .ram_DAT_O    (ram_wr_DAT_O),
      .ram_CYC_O    (ram_CYC_O),
      .ram_WE_O     (ram_WE_O),
      .ram_STB_O    (ram_STB_O),
      .ram_SEL_O    (ram_SEL_O),
      .csr_mem_DAT_I(csr_mem_rd_DAT_I),
      .csr_mem_ACK_I(csr_mem_ACK_I),
      .csr_mem_ADR_O(csr_mem_ADR_O),
      .csr_mem_DAT_O(csr_mem_wr_DAT_O),
      .csr_mem_CYC_O(csr_mem_CYC_O),
      .csr_mem_WE_O (csr_mem_WE_O),
      .csr_mem_STB_O(csr_mem_STB_O),
      .uart_0_DAT_I (uart_0_rd_DAT_I),
      .uart_0_ACK_I (uart_0_ACK_I),
      .uart_0_ADR_O (uart_0_ADR_O),
      .uart_0_DAT_O (uart_0_wr_DAT_O),
      .uart_0_CYC_O (uart_0_CYC_O),
      .uart_0_WE_O  (uart_0_WE_O),
      .uart_0_STB_O (uart_0_STB_O)
  );

  instruction_cache #(
      .L2_CACHE_SIZE(8),   // bytes
      .L2_BLOCK_SIZE(4),   // bytes
      .L2_ADDR_SIZE (32),  // bits
      .L2_DATA_SIZE (2)    // bytes
  ) cache (
      .CLK_I           (CLK_I),
      .RST_I           (RST_I),
      .inst_DAT_I      (inst_DAT_I),
      .inst_ACK_I      (inst_ACK_I),
      .inst_CYC_O      (inst_CYC_O),
      .inst_STB_O      (inst_STB_O),
      .inst_ADR_O      (inst_ADR_O),
      .inst_cache_CYC_I(rom_CYC_I),
      .inst_cache_STB_I(rom_STB_I),
      .inst_cache_ADR_I(rom_ADR_I),
      .inst_cache_DAT_O(rom_DAT_O),
      .inst_cache_ACK_O(rom_ACK_O)
  );

  // Instanciação da memória ROM
  ROM #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/rom_init_file.mif"),
      .WORD_SIZE(8),
      .ADDR_SIZE(9),
      .OFFSET(4),
      .BUSY_CYCLES(BusyCycles)
  ) rom (
      .CLK_I(CLK_I),
      .CYC_I(inst_CYC_I),
      .STB_I(inst_STB_I),
      .ADR_I(inst_ADR_I[8:0]),
      .DAT_O(inst_DAT_O),
      .ACK_O(inst_ACK_O)
  );

  // Instanciação da memória RAM
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"),
      .ADDR_SIZE(9),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(BusyCycles)
  ) ram (
      .CLK_I(CLK_I),
      .ADR_I(ram_ADR_I),
      .DAT_I(ram_DAT_I),
      .CYC_I(ram_CYC_I),
      .STB_I(ram_STB_I),
      .WE_I (ram_WE_I),
      .SEL_I(ram_SEL_I),
      .DAT_O(ram_DAT_O),
      .ACK_O(ram_ACK_O)
  );

  // Instaciação do CSR mapeados em memória
  CSR_mem #(
      .CLOCK_CYCLES(10)
  ) csr_mem (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .ADR_I(csr_mem_ADR_I),
      .DAT_I(csr_mem_DAT_I),
      .CYC_I(csr_mem_CYC_I),
      .STB_I(csr_mem_STB_I),
      .WE_I(csr_mem_WE_I),
      .DAT_O(csr_mem_DAT_O),
      .ACK_O(csr_mem_ACK_O),
      .msip(),
      .mtime(),
      .mtimecmp()
  );

  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .ADR_I(uart_0_ADR_I[4:2]),
      .DAT_I(uart_0_DAT_I),
      .CYC_I(uart_0_CYC_I),
      .STB_I(uart_0_STB_I),
      .WE_I (uart_0_WE_I),
      .DAT_O(uart_0_DAT_O),
      .ACK_O(uart_0_ACK_O),
      .rxd  (rx_tx),
      .txd  (rx_tx)
  );

  task automatic WriteRam(input integer j);
    begin
      case (j % 4)
        0: begin
          ram_memory[j/4][7:0]   = DAT_I[7:0];
          ram_memory[j/4][23:16] = DAT_I[23:16];
        end
        1: begin
          ram_memory[j/4][15:8]  = DAT_I[7:0];
          ram_memory[j/4][31:24] = DAT_I[23:16];
        end
        2: begin
          ram_memory[j/4][23:16] = DAT_I[7:0];
          ram_memory[j/4+1][7:0] = DAT_I[23:16];
        end
        default: begin  // 3
          ram_memory[j/4][31:24]  = DAT_I[7:0];
          ram_memory[j/4+1][15:8] = DAT_I[23:16];
        end
      endcase
    end
  endtask

  function automatic [31:0] ReadRam(input integer j);
    reg [31:0] rd_data = 0;
    begin
      case (j % 4)
        0: begin
          rd_data[7:0]   = ram_memory[j/4][7:0];
          rd_data[23:16] = ram_memory[j/4][23:16];
        end
        1: begin
          rd_data[7:0]   = ram_memory[j/4][15:8];
          rd_data[23:16] = ram_memory[j/4][31:24];
        end
        2: begin
          rd_data[7:0]   = ram_memory[j/4][23:16];
          rd_data[23:16] = ram_memory[j/4+1][7:0];
        end
        default: begin  // 3
          rd_data[7:0]   = ram_memory[j/4][31:24];
          rd_data[23:16] = ram_memory[j/4+1][15:8];
        end
      endcase
      ReadRam = rd_data;
    end
  endfunction

  task automatic CsrTest(input reg [31:0] addr);
    reg [31:0] data;
    begin
      @(negedge CLK_I);
      CYC_I = 1'b1;
      WE_I  = 1'b1;
      ADR_I = addr;
      DAT_I = $urandom;
      data  = DAT_I;
      @(posedge ACK_O);
      @(negedge CLK_I);
      DAT_I = 0;
      WE_I  = 1'b0;
      @(posedge ACK_O);
      @(negedge CLK_I);
      `ASSERT((DAT_O === data) || (DAT_O === data + 1));  // MTIME
      CYC_I = 1'b0;
      ADR_I = 0;
    end
  endtask

  // Geração do CLK_I
  always #(ClockPeriod / 2) CLK_I = ~CLK_I;

  initial begin
    $readmemb("./MIFs/memory/ROM/rom_init_file_tb.mif", rom_memory);

    // Inicialização das entradas
    CLK_I = 0;
    RST_I = 0;
    CYC_I = 0;
    SEL_I = 0;
    DAT_I = 0;
    ADR_I = 0;

    // Resetando a cache
    @(negedge CLK_I);
    RST_I = 1;
    @(negedge CLK_I);
    RST_I = 0;

    // Teste da ROM
    SEL_I = 8'hFF;  // Don't care
    for (i = 0; i < 128; i = i + 1) begin
      @(negedge CLK_I);
      ADR_I = 4 * i + RomAddrInit;  // acesso da ROM
      CYC_I = 1'b1;
      WE_I  = 1'b0;
      @(posedge ACK_O);
      @(negedge CLK_I);
      `ASSERT(DAT_O[31:0] === rom_memory[i][31:0]);
      CYC_I = 1'b0;
      WE_I  = 1'b0;
    end

    // Teste da RAM
    SEL_I = 8'h05;
    // Escrita
    for (i = 0; i < 510; i = i + 1) begin
      @(negedge CLK_I);
      CYC_I = 1'b1;
      WE_I  = 1'b1;
      ADR_I = i + RamAddrInit;
      DAT_I = $urandom;
      WriteRam(i);
      @(posedge ACK_O);
      @(negedge CLK_I);
      `ASSERT(DAT_O === ReadRam(i));
      CYC_I = 1'b0;
      WE_I  = 1'b0;
    end
    // Leitura
    for (i = 0; i < 510; i = i + 1) begin
      @(negedge CLK_I);
      CYC_I = 1'b1;
      ADR_I = i + RamAddrInit;
      @(posedge ACK_O);
      @(negedge CLK_I);
      `ASSERT(DAT_O === ReadRam(i));
      CYC_I = 1'b0;
    end

    // Teste do CSR_mem
    SEL_I = 8'hFF;  // Don't care
    CsrTest(MsipAddr);  // MSIP
    CsrTest(MtimeAddr);  // MTIME
    CsrTest(MtimeCmpAddr);  // MTIMECMP

    // Teste da UART
    // Habilitar RX
    CYC_I = 1'b1;
    WE_I  = 1'b1;
    ADR_I = Uart0AddrInit + 5'h0C;
    DAT_I = 32'hFFFFFFFF;
    @(posedge ACK_O);
    // Habilitar TX
    ADR_I = Uart0AddrInit + 5'h08;
    @(posedge ACK_O);
    // Configurando baud rate
    ADR_I       = Uart0AddrInit + 5'h18;
    DAT_I[15:0] = 16'h001F;
    @(posedge ACK_O);
    // Escrevendo dado no TX
    ADR_I   = Uart0AddrInit;
    DAT_I   = $urandom;
    tx_data = DAT_I;
    @(posedge ACK_O);
    @(negedge CLK_I);
    CYC_I = 1'b0;
    WE_I = 1'b0;
    DAT_I = 0;
    ADR_I = 0;
    rx_empty = 1'b1;
    // Esperando o dado chegar no RX
    ADR_I = Uart0AddrInit + 5'h04;
    while (rx_empty) begin
      CYC_I = 1'b1;
      @(posedge ACK_O);
      @(negedge CLK_I);
      CYC_I = 1'b0;
      rx_empty = DAT_O[31];
    end
    `ASSERT(DAT_O[7:0] === tx_data);

    $stop;
  end
endmodule
