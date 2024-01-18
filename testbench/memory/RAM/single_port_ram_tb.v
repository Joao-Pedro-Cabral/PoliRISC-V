//
//! @file   single_port_ram_tb.v
//! @brief  Testbench da ram de porta única com byte enable write
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-01
//

`timescale 1ns / 100ps

module single_port_ram_tb;

  parameter AMOUNT_OF_TESTS = 40;

  reg CLK_I;
  reg [31:0] ADR_I;
  wire [31:0] DAT_O;
  wire [31:0] DAT_I;
  reg [31:0] tb_data;
  reg [31:0] tb_mem[AMOUNT_OF_TESTS-1:0];
  wire ACK_O;
  reg CYC_I;
  reg WE_I;
  reg STB_I;
  reg [3:0] SEL_I;

  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"),
      .ADDR_SIZE(6),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(6)
  ) DUT (
      .CLK_I(CLK_I),
      .ADR_I(ADR_I),
      .DAT_I(DAT_I),
      .CYC_I(CYC_I),
      .WE_I (WE_I),
      .STB_I(STB_I),
      .SEL_I(SEL_I),
      .DAT_O(DAT_O),
      .ACK_O(ACK_O)
  );

  always #10 CLK_I = ~CLK_I;
  assign DAT_I = tb_data;

  integer i;
  initial begin
    {CLK_I, ADR_I, tb_data, CYC_I, STB_I, WE_I, SEL_I} = 0;

    // gerando valores aleatórios
    for (i = 0; i < AMOUNT_OF_TESTS; i = i + 1) begin
      tb_mem[i] = $urandom;
      $display("dado %d: 0x%h", i, tb_mem[i]);
    end

    // escreve e testa leitura
    for (i = 0; i < AMOUNT_OF_TESTS - 1; i = i + 1) begin
      @(negedge CLK_I);
      ADR_I   = 4 * i;
      tb_data = tb_mem[i];
      STB_I   = 1'b1;
      CYC_I   = 1'b1;
      WE_I    = 1'b1;
      SEL_I   = 4'hF;
      @(posedge CLK_I);
      WE_I = 1'b0;
      @(posedge ACK_O);
      @(negedge ACK_O);
      STB_I = 1'b0;
      CYC_I = 1'b0;
      SEL_I = 4'h0;
      if (DAT_O != tb_data) begin
        $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", DAT_O, tb_data);
      end else begin
        $display("teste %d correto: 0x%h", i + 1, DAT_O);
      end
      @(negedge CLK_I);
    end

    // testa leitura e escrita desalinhada
    tb_data = 0;
    ADR_I   = 4 * 3 + 2;
    STB_I   = 1'b1;
    CYC_I   = 1'b1;
    WE_I    = 1'b1;
    SEL_I   = 4'hF;
    @(posedge CLK_I);
    WE_I  = 1'b0;
    CYC_I = 1'b1;
    @(posedge ACK_O);
    @(negedge ACK_O);
    if (DAT_O != tb_data) begin
      $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", DAT_O, tb_mem[4*3+2]);
    end else begin
      $display("teste %d correto: 0x%h", AMOUNT_OF_TESTS, DAT_O);
    end

    // desativa memória
    STB_I = 1'b0;
    CYC_I = 1'b0;
    SEL_I = 4'h0;
    $display("EOT!");
    $stop;
  end

endmodule
