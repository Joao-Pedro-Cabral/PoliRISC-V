//
//! @file   ROM_tb.v
//! @brief  Testbench para a Memória ROM
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

`include "macros.vh"

`define ASSERT(condition) if (!(condition)) $stop

module ROM_tb ();

  // sinais do DUT
  reg CLK_I;
  reg CYC_I;
  reg STB_I;
  reg [5:0] ADR_I;
  wire [31:0] DAT_O;
  wire ACK_O;
  // sinais intermediários
  reg [31:0] memory[15:0];
  integer i;

  // instanciar o DUT
  ROM #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/rom_init_file.mif"),
      .WORD_SIZE(8),
      .ADDR_SIZE(6),
      .OFFSET(2),
      .BUSY_CYCLES(2)
  ) DUT (
      .CLK_I(CLK_I),
      .CYC_I(CYC_I),
      .STB_I(STB_I),
      .ADR_I(ADR_I),
      .DAT_O(DAT_O),
      .ACK_O(ACK_O)
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
    $readmemb("./MIFs/memory/ROM/rom_init_file_tb.mif", memory);  // instanciar a memória do tb
    $display("SOT!");
    @(negedge CLK_I);
    for (i = 0; i < 256; i = i + 1) begin
      $display("Test: %d", i);
      CYC_I = i % 2;
      STB_I = (i % 4) / 2;
      ADR_I = i / 4;
      `ASSERT(ACK_O === 1'b0);
      if (CYC_I && STB_I) begin
        @(negedge CLK_I);
        @(negedge CLK_I);
        @(negedge CLK_I);
        `ASSERT(ACK_O === 1'b1);
        `ASSERT(DAT_O === memory[ADR_I/4]);
      end
      @(negedge CLK_I);
    end
    $display("EOT!");
    $stop;
  end

endmodule
