//
//! @file   RV32I_uart_tb.v
//! @brief  Testbench do RV32I com UART sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

// Checar se o processador consegue escrever/ler da UART
// Escreve dado no TX -> Recebe o mesmo dado pelo RX
// Subtrai o valor escrito e o recebido
// Escreve o resultado no endereço

`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module RV32I_uart_tb ();

  // Parâmetros da Simulação
  localparam integer AmntOfTests = 100;
  localparam integer ClockPeriod = 20;

  // sinais do DUT
  reg            clock;
  reg            reset;
  // Data Memory
  wire    [31:0] rd_data;
  wire    [31:0] wr_data;
  wire    [31:0] mem_addr;
  wire           mem_busy;
  wire           mem_rd_en;
  wire           mem_wr_en;
  wire    [ 3:0] mem_byte_en;
  // Sinais do Barramento
  // Instruction Memory
  wire    [31:0] rom_data;
  wire    [31:0] rom_addr;
  wire           rom_enable;
  wire           rom_busy;
  // Data Memory
  wire    [31:0] ram_address;
  wire    [31:0] ram_write_data;
  wire    [31:0] ram_read_data;
  wire           ram_output_enable;
  wire           ram_write_enable;
  wire           ram_chip_select;
  wire    [ 3:0] ram_byte_enable;
  wire           ram_busy;
  // Sinais da UART
  wire           uart_rd_en;
  wire           uart_wr_en;
  wire    [ 4:0] uart_addr;
  wire           uart_rxd;
  wire    [31:0] uart_wr_data;
  wire           uart_txd;
  wire    [31:0] uart_rd_data;
  wire           uart_busy;

  integer        i;  // variável de iteração

  // DUT
  core #(
      .RV64I(0),
      .DATA_SIZE(32)
  ) DUT (
      .clock(clock),
      .reset(reset),
      .rd_data(rd_data),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .mem_busy(mem_busy),
      .mem_rd_en(mem_rd_en),
      .mem_byte_en(mem_byte_en),
      .mem_wr_en(mem_wr_en)
  );

  // Instruction Memory
  ROM #(
      .rom_init_file("./ROM.mif"),
      .word_size(8),
      .addr_size(10),
      .offset(2),
      .busy_cycles(2)
  ) Instruction_Memory (
      .clock (clock),
      .enable(rom_enable),
      .addr  (rom_addr[9:0]),
      .data  (rom_data),
      .busy  (rom_busy)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(12),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) Data_Memory (
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

  // UART
  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
  ) UART_0 (
      .clock  (clock),
      .reset  (reset),
      .rd_en  (uart_rd_en),
      .wr_en  (uart_wr_en),
      .addr   (uart_addr),     // 0x00 a 0x18
      .rxd    (uart_rxd),      // dado serial
      .wr_data(uart_wr_data),
      .txd    (uart_txd),      // dado de transmissão
      .rd_data(uart_rd_data),
      .busy   (uart_busy)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(4)
  ) BUS (
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .mem_byte_en(mem_byte_en),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .rd_data(rd_data),
      .mem_busy(mem_busy),
      .inst_cache_data(rom_data),
      .inst_cache_busy(rom_busy),
      .inst_cache_enable(rom_enable),
      .inst_cache_addr(rom_addr),
      .ram_read_data(ram_read_data),
      .ram_busy(ram_busy),
      .ram_address(ram_address),
      .ram_write_data(ram_write_data),
      .ram_output_enable(ram_output_enable),
      .ram_write_enable(ram_write_enable),
      .ram_chip_select(ram_chip_select),
      .ram_byte_enable(ram_byte_enable),
      .uart_0_rd_data(uart_rd_data),
      .uart_0_busy(uart_busy),
      .uart_0_rd_en(uart_rd_en),
      .uart_0_wr_en(uart_wr_en),
      .uart_0_addr(uart_addr),
      .uart_0_wr_data(uart_wr_data)
  );

  // curto circuito da serial da UART
  assign uart_rxd = 1'b1;

  // Geração de clock
  always #(ClockPeriod / 2) clock = ~clock;

  // testbench
  initial begin
    {i, clock, reset} = 0;
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    @(negedge clock);
    $display("[%0t] SOT", $time);
    while (i < AmntOfTests) begin
      // Se for uma operação de escrita na RAM
      if (ram_write_enable === 1'b1 && ram_chip_select === 1'b1) begin
        @(negedge clock);
        @(negedge clock);  // Espera 2 ciclos
        // Confere se é um SW
        `ASSERT(ram_byte_enable === 4'hF);
        // Confere o endereço de escrita
        `ASSERT(ram_address === 0);
        // Confere se está escrevendo 0: rx_data == tx_data
        `ASSERT(ram_write_data === 0);
        i = i + 1;
      end
      @(negedge clock);
    end
    $display("[%0t] EOT", $time);
    $stop;
  end
endmodule
