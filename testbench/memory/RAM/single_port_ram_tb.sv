
module single_port_ram_tb;

  import macros_pkg::*;

  parameter integer AmountOfTests = 40;

  // sinais do DUT
  logic clock = 1'b0, reset = 1'b0;
  wishbone_if #(.DATA_SIZE(32), .BYTE_SIZE(8), .ADDR_SIZE(6)) wb_if (.*);
  reg [31:0] tb_data;
  reg [31:0] [AmountOfTests-1:0] tb_mem;

  single_port_ram #(
      .RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"),
      .BUSY_CYCLES(6)
  ) DUT (
      .wb_if_s(wb_if)
  );

  always #10 clock = ~clock;
  assign wb_if.dat_o_p = tb_data;

  integer i;
  initial begin
    {clock, reset, tb_data} = 0;
    $display("SOT!");
    wb_if.cyc = 0;
    wb_if.stb = 0;
    wb_if.we = 0;
    wb_if.tgd = 0;
    wb_if.sel = 0;
    wb_if.addr = 0;

    // gerando valores aleatórios
    for (i = 0; i < AmountOfTests; i = i + 1) begin
      tb_mem[i] = $urandom;
    end

    // escreve e testa leitura
    for (i = 0; i < AmountOfTests - 1; i = i + 1) begin
      @(negedge clock);
      wb_if.addr = 4 * i;
      tb_data = tb_mem[i];
      wb_if.stb = 1'b1;
      wb_if.cyc = 1'b1;
      wb_if.we  = 1'b1;
      wb_if.sel = 4'hF;
      @(posedge clock);
      wb_if.we = 1'b0;
      @(posedge wb_if.ack);
      @(negedge clock);
      CHK_DAT_ALIGNED: assert(wb_if.dat_i_p === tb_data);
      @(negedge wb_if.ack);
      wb_if.stb = 1'b0;
      wb_if.cyc = 1'b0;
      wb_if.sel = 4'h0;
    end

    // testa leitura e escrita desalinhada
    tb_data = 0;
    wb_if.addr = 4 * 3 + 2;
    wb_if.stb  = 1'b1;
    wb_if.cyc  = 1'b1;
    wb_if.we   = 1'b1;
    wb_if.sel  = 4'hF;
    @(posedge clock);
    wb_if.we  = 1'b0;
    wb_if.cyc = 1'b1;
    @(posedge wb_if.ack);
    @(negedge clock);
    CHK_DAT_DISALIGNED: assert(wb_if.dat_i_p === tb_data);
    @(negedge wb_if.ack);

    // desativa memória
    wb_if.stb = 1'b0;
    wb_if.cyc = 1'b0;
    wb_if.sel = 4'h0;
    $display("EOT!");
    $stop;
  end

endmodule
