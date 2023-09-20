//
//! @file   ROM_tb.v
//! @brief  Testbench para a Memória ROM
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

`timescale 1 ns / 100 ps

module ROM_tb ();

  // sinais do DUT
  reg CLK_I;
  reg CYC_I;
  reg [5:0] ADR_I;
  wire [31:0] DAT_O;
  wire ACK_O;
  // sinais intermediários
  reg [31:0] memory[15:0];
  integer i;

  // instanciar o DUT
  ROM #(
      .rom_init_file("./MIFs/memory/ROM/rom_init_file.mif"),
      .word_size(8),
      .addr_size(6),
      .offset(2),
      .busy_cycles(2)
  ) DUT (
      .CLK_I (CLK_I),
      .CYC_I (CYC_I),
      .ADR_I (ADR_I),
      .DAT_O (DAT_O),
      .ACK_O (ACK_O)
  );

  // geração do CLK_I
  always begin
    CLK_I = 1'b0;
    #3;
    CLK_I = 1'b1;
    #3;
  end

  // testar o DUT
  initial begin : Testbench
    $readmemb("./ROM.mif", memory);  // instanciar a memória do tb
    $display("SOT!");
    #8;
    for (i = 0; i < 128; i = i + 1) begin
      $display("Test: %d", i);
      CYC_I = i % 2;
      ADR_I   = i / 2;
      /* #2; */
      if (CYC_I === 1) begin
        @(negedge ACK_O) CYC_I = 0;
        if (ACK_O !== 0) $display("Error ACK_O !== 0: CYC_I = %b, ACK_O = %b", CYC_I, ACK_O);
        @(posedge ACK_O)
        if (ACK_O !== 1 || DAT_O !== memory[ADR_I/4])
          $display("Error: CYC_I = %b, ADR_I = %b, DAT_O = %b, ACK_O = %b", CYC_I, ADR_I, DAT_O, ACK_O);
      end else if (ACK_O !== 1) $display("Error ACK_O !== 1: CYC_I = %b, ACK_O = %b", CYC_I, ACK_O);
      #4;
    end
    $display("EOT!");
    $stop;
  end

endmodule
