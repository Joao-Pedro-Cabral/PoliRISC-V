//
//! @file   ROM_tb.v
//! @brief  Testbench para a Memória ROM
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

`timescale 1 ns / 100 ps

module ROM_tb ();

  // sinais do DUT
  reg clock;
  reg enable;
  reg [5:0] addr;
  wire [31:0] data;
  wire busy;
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
      .clock (clock),
      .enable(enable),
      .addr  (addr),
      .data  (data),
      .busy  (busy)
  );

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  // testar o DUT
  initial begin : Testbench
    $readmemb("./ROM.mif", memory);  // instanciar a memória do tb
    $display("SOT!");
    #8;
    for (i = 0; i < 128; i = i + 1) begin
      $display("Test: %d", i);
      enable = i % 2;
      addr   = i / 2;
      /* #2; */
      if (enable === 1) begin
        @(posedge busy) enable = 0;
        if (busy !== 1) $display("Error busy !== 1: enable = %b, busy = %b", enable, busy);
        @(negedge busy)
        if (busy !== 0 || data !== memory[addr/4])
          $display("Error: enable = %b, addr = %b, data = %b, busy = %b", enable, addr, data, busy);
      end else if (busy !== 0) $display("Error busy !== 0: enable = %b, busy = %b", enable, busy);
      #4;
    end
    $display("EOT!");
    $stop;
  end

endmodule
