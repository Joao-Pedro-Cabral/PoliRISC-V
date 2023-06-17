//
//! @file   sdram_tester2_tb.v
//! @brief  Testbench do Testador do Controlador da SDRAM
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-06-15
//

`timescale 1 ns / 1 ns

`define ASSERT(condition) if (!(condition)) $stop

module sdram_tester2_tb ();

  // Sinais do DUT
  // Processador
  reg clock;
  reg reset_n;
  reg ativar;
  wire check_op;
  wire [2:0] state;
  // SDRAM
  wire dram_clk;
  wire dram_cke;
  wire [12:0] dram_addr;
  wire [1:0] dram_ba;
  wire dram_cs_n;
  wire dram_ras_n;
  wire dram_cas_n;
  wire dram_we_n;
  wire dram_ldqm;
  wire dram_udqm;
  wire [15:0] dram_dq;
  reg [15:0] memory[127:0];  // memória simulada
  wire [3:0] command = {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n};
  // Sinais intermediários
  // Controlar a leitura na SDRAM
  reg rd_en;
  reg ldqm;
  reg udqm;
  reg [6:0] rd_addr;
  // variável de iteração
  integer i;

  // DUT
  sdram_tester2 #(
      .CLOCK_FREQ_HZ(10)
  ) DUT (
      .clock(clock),
      .reset_n(reset_n),
      .check_op(check_op),
      .state(state),
      .dram_clk(dram_clk),
      .dram_cke(dram_cke),
      .dram_addr(dram_addr),
      .dram_ba(dram_ba),
      .dram_cs_n(dram_cs_n),
      .dram_ras_n(dram_ras_n),
      .dram_cas_n(dram_cas_n),
      .dram_we_n(dram_we_n),
      .dram_ldqm(dram_ldqm),
      .dram_udqm(dram_udqm),
      .dram_dq(dram_dq)
  );

  // geração do clock
  always #10 clock = ~clock;

  // "Memória"
  assign dram_dq[7:0]  = rd_en & ~ldqm ? memory[rd_addr][7:0] : {{8'bz}};  // tri-state
  assign dram_dq[15:8] = rd_en & ~udqm ? memory[rd_addr][15:8] : {{8'bz}};  // tri-state

  // leitura
  always @(posedge dram_clk) begin
    rd_en   <= 0;  // alta impedância
    ldqm    <= 1'b1;
    udqm    <= 1'b1;
    rd_addr <= 0;
    if (command == 4'b0101) begin  // READ
      ldqm    <= dram_ldqm;
      udqm    <= dram_udqm;
      rd_addr <= dram_addr[6:0];
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);  // CAS latency = 3
      rd_en <= 1;
    end
  end

  // escrita
  always @(posedge dram_clk) begin
    if (command == 4'b0100) begin  // WRITE
      if (dram_ldqm == 1'b0) memory[dram_addr[6:0]][7:0] <= dram_dq[7:0];
      if (dram_udqm == 1'b0) memory[dram_addr[6:0]][15:8] <= dram_dq[15:8];
    end
  end

  // testbench
  initial begin : testbench
    {clock, reset_n, ativar} = 3'b010;
    $display("SOT!");
    @(negedge clock);
    reset_n = 1'b0;  // ativo baixo
    @(negedge clock);
    reset_n = 1'b1;
    // Realizar os 8 testes
    for (i = 0; i < 8; i = i + 1) begin
      $display("Time: [%0t], Test: %d", $time, i);
      // Esperando o after_write
      wait (state == DUT.AfterRead);
      `ASSERT(check_op === 1'b1);
      wait (state != DUT.AfterRead);
    end
    $display("[%0t] EOT!", $time);
    $stop;
  end

endmodule
