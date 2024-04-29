
module rom_tb ();

  import macros_pkg::*;

  // sinais do DUT
  logic clock = 1'b0, reset = 1'b0;
  wishbone_if #(.DATA_SIZE(32), .BYTE_SIZE(8), .ADDR_SIZE(6)) wb_if (.*);
  // sinais intermediários
  reg [31:0] memory[15:0];
  reg [5:0] addr;
  int i;

  // instanciar o DUT
  rom #(
      .ROM_INIT_FILE("./MIFs/memory/ROM/rom_init_file.mif"),
      .BUSY_CYCLES(2)
  ) DUT (
      .wb_if_s(wb_if)
  );

  // geração do clock
  always #3 clock = ~clock;

  // testar o DUT
  initial begin : Testbench
    $readmemb("./MIFs/memory/ROM/rom_init_file_tb.mif", memory);  // instanciar a memória do tb
    $display("SOT!");
    wb_if.cyc = 0;
    wb_if.stb = 0;
    wb_if.we = 0;
    wb_if.tgd = 0;
    wb_if.sel = 0;
    wb_if.addr = 0;
    @(negedge clock);
    for (i = 0; i < 256; i = i + 1) begin
      wb_if.cyc = i % 2;
      wb_if.stb = (i % 4) / 2;
      addr = i / 4;
      wb_if.addr = addr;
      CHK_ACK_LOW: assert(wb_if.ack === 1'b0);
      if (wb_if.cyc && wb_if.stb) begin
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        CHK_ACK_HIGH: assert(wb_if.ack === 1'b1);
        CHK_DAT_O: assert(wb_if.dat_i_p === memory[addr/4]);
      end
      @(negedge clock);
    end
    $display("EOT!");
    $stop;
  end

endmodule
