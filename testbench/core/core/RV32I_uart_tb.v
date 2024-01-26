//
//! @file   RV32I_uart_tb.v
//! @brief  Testbench do RV32I com UART sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

// 2 TBs em 1
// Primeiro TB (uart_test.mif)
// Checar se o processador consegue escrever/ler da UART
// Escreve dado no TX -> Recebe o mesmo dado pelo RX
// Subtrai o valor escrito e o recebido
// Escreve o resultado no endereço
// Segundo TB (uart_tx_full_test.mif)
// Checar o comportamento do processador ao escrever no TX
// Observar como o processador ve o tx_full

`include "macros.vh"

`define ASSERT(condition) if (!(condition)) $stop

module RV32I_uart_tb ();

  // Parâmetros da Simulação
  //localparam integer AmntOfTests = 10;  // modo echo
  localparam integer AmntOfTests = 1;  // tx_full = 1 -> Escrever 0 na RAM -> EOT
  localparam integer ClockPeriod = 20;

  // sinais do DUT
  reg            clock;
  reg            reset;
  // Data Memory
  wire    [31:0] rd_data;
  wire    [31:0] wr_data;
  wire    [31:0] mem_addr;
  wire           mem_ack;
  wire           mem_CYC_O;
  wire           mem_STB_O;
  wire           mem_wr_en;
  wire    [ 3:0] mem_SEL_O;
  // Sinais do Barramento
  // Instruction Memory
  wire    [31:0] rom_ADR_I;
  wire    [31:0] rom_DAT_O;
  wire           rom_CYC_I;
  wire           rom_STB_I;
  wire           rom_ACK_O;
  // Data Memory
  wire    [31:0] ram_ADR_I;
  wire    [31:0] ram_DAT_I;
  wire    [31:0] ram_DAT_O;
  wire           ram_WE_I;
  wire           ram_CYC_I;
  wire           ram_STB_I;
  wire    [ 3:0] ram_SEL_I;
  wire           ram_ACK_O;
  // Sinais da UART
  wire           uart_0_CYC_I;
  wire           uart_0_STB_I;
  wire           uart_0_WE_I;
  wire    [ 4:0] uart_0_ADR_I;
  wire           uart_0_rxd;
  wire    [31:0] uart_0_DAT_I;
  wire           uart_0_txd;
  wire    [31:0] uart_0_DAT_O;
  wire           uart_0_ACK_O;

  integer        i;  // variável de iteração

  // DUT
  core DUT (
      .clock(clock),
      .reset(reset),
      .DAT_I(rd_data),
      .DAT_O(wr_data),
      .mem_ADR_O(mem_addr),
      .mem_ACK_I(mem_ack),
      .mem_CYC_O(mem_CYC_O),
      .mem_STB_O(mem_STB_O),
      .mem_SEL_O(mem_SEL_O),
      .mem_WE_O(mem_wr_en),
      .external_interrupt(1'b0),
      .mem_msip(0),
      .mem_mtime(64'b0),
      .mem_mtimecmp(64'b0)
  );

  // Instruction Memory
  ROM #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/uart_tx_full_test.mif"),
      .WORD_SIZE(8),
      .ADDR_SIZE(10),
      .OFFSET(2),
      .BUSY_CYCLES(2)
  ) Instruction_Memory (
      .CLK_I(clock),
      .CYC_I(rom_CYC_I),
      .STB_I(rom_STB_I),
      .ADR_I(rom_ADR_I[9:0]),
      .DAT_O(rom_DAT_O),
      .ACK_O(rom_ACK_O)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/core.mif"),
      .ADDR_SIZE(12),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(2)
  ) Data_Memory (
      .CLK_I(clock),
      .ADR_I(ram_ADR_I),
      .DAT_I(ram_DAT_I),
      .CYC_I(ram_CYC_I),
      .STB_I(ram_STB_I),
      .WE_I (ram_WE_I),
      .SEL_I(ram_SEL_I),
      .DAT_O(ram_DAT_O),
      .ACK_O(ram_ACK_O)
  );

  // UART
  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .CLK_I(clock),
      .RST_I(reset),
      .ADR_I(uart_0_ADR_I[4:2]),
      .DAT_I(uart_0_DAT_I),
      .CYC_I(uart_0_CYC_I),
      .STB_I(uart_0_STB_I),
      .WE_I (uart_0_WE_I),
      .DAT_O(uart_0_DAT_O),
      .ACK_O(uart_0_ACK_O),
      .rxd  (uart_0_rxd),
      .txd  (uart_0_txd)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(4),
      .ROM_ADDR_INIT(0),
      .ROM_ADDR_END(32'h00FFFFFF),
      .RAM_ADDR_INIT(32'h01000000),
      .RAM_ADDR_END(32'h04FFFFFF),
      .MTIME_ADDR({32'b0, 262142 * (2 ** 12)}),
      .MTIMECMP_ADDR({32'b0, 262143 * (2 ** 12)}),
      .MSIP_ADDR({32'b0, 262144 * (2 ** 12)})
  ) BUS (
      .cpu_WE_I     (mem_wr_en),
      .cpu_CYC_I    (mem_CYC_O),
      .cpu_STB_I    (mem_STB_O),
      .cpu_SEL_I    (mem_SEL_O),
      .cpu_DAT_I    (wr_data),
      .cpu_ADR_I    (mem_addr),
      .cpu_DAT_O    (rd_data),
      .cpu_ACK_O    (mem_ack),
      .rom_DAT_I    (rom_DAT_O),
      .rom_ACK_I    (rom_ACK_O),
      .rom_CYC_O    (rom_CYC_I),
      .rom_STB_O    (rom_STB_I),
      .rom_ADR_O    (rom_ADR_I),
      .ram_DAT_I    (ram_DAT_O),
      .ram_ACK_I    (ram_ACK_O),
      .ram_ADR_O    (ram_ADR_I),
      .ram_DAT_O    (ram_DAT_I),
      .ram_CYC_O    (ram_CYC_I),
      .ram_WE_O     (ram_WE_I),
      .ram_STB_O    (ram_STB_I),
      .ram_SEL_O    (ram_SEL_I),
      .csr_mem_DAT_I(0),
      .csr_mem_ACK_I(1'b0),
      .csr_mem_ADR_O(),
      .csr_mem_DAT_O(),
      .csr_mem_CYC_O(),
      .csr_mem_WE_O (),
      .csr_mem_STB_O(),
      .uart_0_DAT_I (uart_0_DAT_O),
      .uart_0_ACK_I (uart_0_ACK_O),
      .uart_0_ADR_O (uart_0_ADR_I),
      .uart_0_DAT_O (uart_0_DAT_I),
      .uart_0_CYC_O (uart_0_CYC_I),
      .uart_0_WE_O  (uart_0_WE_I),
      .uart_0_STB_O (uart_0_STB_I)
  );

  // curto circuito da serial da UART
  //assign uart_0_rxd = uart_0_txd;  // modo echo
  assign uart_0_rxd = 1'b1;  // checar tx_full

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
      if (ram_WE_I && ram_CYC_I && ram_STB_I) begin
        @(negedge clock);
        @(negedge clock);  // Espera 2 ciclos
        // Confere se é um SW
        `ASSERT(ram_SEL_I === 4'hF);
        // Confere o endereço de escrita
        `ASSERT(ram_ADR_I[9:0] === 0);
        // Confere se está escrevendo 0: rx_data == tx_data
        `ASSERT(ram_DAT_I === 0);
        i = i + 1;
      end
      @(negedge clock);
    end
    $display("[%0t] EOT", $time);
    $stop;
  end
endmodule
