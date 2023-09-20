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
  reg TAG_I;
  reg WE_I;
  reg STB_I;
  reg [3:0] SEL_I;

  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(4),
      .BYTE_SIZE(8),
      .DATA_SIZE(32),
      .BUSY_CYCLES(6)
  ) DUT (
      .CLK_I(CLK_I),
      .ADR_I(ADR_I),
      .DAT_I(DAT_I),
      .TAG_I(TAG_I),
      .WE_I(WE_I),
      .STB_I(STB_I),
      .SEL_I(SEL_I),
      .DAT_O(DAT_O),
      .ACK_O(ACK_O)
  );

  always #10 CLK_I = ~CLK_I;
  assign DAT_I = tb_data;

  integer i;
  initial begin
    {CLK_I, ADR_I, tb_data, TAG_I, STB_I, SEL_I} = 0;

    // gerando valores aleatórios
    for (i = 0; i < AMOUNT_OF_TESTS; i = i + 1) begin
      tb_mem[i] = $random;
      $display("dado %d: 0x%h", i, tb_mem[i]);
    end

    // aciona memória
    STB_I = 1'b1;

    // escreve e testa leitura
    for (i = 0; i < AMOUNT_OF_TESTS - 1; i = i + 1) begin
      ADR_I      = 4 * i;
      tb_data      = tb_mem[i];
      STB_I  = 1'b1;
      WE_I = 1'b1;
      SEL_I  = 4'hF;
      @(posedge CLK_I);
      WE_I  = 1'b0;
      SEL_I   = 4'hF;
      TAG_I = 1'b1;
      @(negedge ACK_O);
      @(posedge ACK_O);
      if (DAT_O != tb_data) begin
        $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", DAT_O, tb_data);
      end else begin
        $display("teste %d correto: 0x%h", i + 1, DAT_O);
      end
      TAG_I = 1'b0;
    end

    // testa leitura e escrita desalinhada
    tb_data      = 0;
    ADR_I      = 4 * 3 + 2;
    WE_I = 1'b1;
    SEL_I  = 4'hF;
    @(posedge CLK_I);
    WE_I  = 1'b0;
    SEL_I   = 4'hF;
    TAG_I = 1'b1;
    @(negedge ACK_O);
    @(posedge ACK_O);
    if (DAT_O != tb_data) begin
      $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", DAT_O, tb_mem[4*3+2]);
    end else begin
      $display("teste %d correto: 0x%h", AMOUNT_OF_TESTS, DAT_O);
    end
    TAG_I = 1'b0;

    // desativa memória
    STB_I   = 1'b0;
    $display("EOT!");
    $stop;
  end

endmodule
