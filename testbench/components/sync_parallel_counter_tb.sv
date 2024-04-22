
module sync_parallel_counter_tb ();

  import macros_pkg::*;

  // DUT
  reg clock, reset, inc_enable, dec_enable, load;
  reg  [2:0] load_value;
  wire [2:0] value;

  integer i, j;

  // instanciação do DUT
  sync_parallel_counter #(
      .size(3),
      .init_value(2)
  ) DUT (
      .clock(clock),
      .load(load),
      .load_value(load_value),
      .reset(reset),
      .inc_enable(inc_enable),
      .dec_enable(dec_enable),
      .value(value)
  );

  // geração do clock
  always begin
    clock = 0;
    #5;
    clock = 1;
    #5;
  end

  // testando o DUT
  initial begin
    #4 $display("SOT!");
    j = 0;
    for (i = 0; i < 1000; i = i + 1) begin
      // entradas aleatórias
      reset      = $urandom;
      inc_enable = $urandom;
      dec_enable = $urandom;
      load       = $urandom;
      load_value = $urandom;
      #1;
      // A partir das novas entradas, gero o novo j
      if (reset) j = 2;
      else if (load) j = load_value;
      else begin
        if (inc_enable) j = (j + 1) % 8;
        if (dec_enable) j = (j + 7) % 8;  // j - 1 = j + 7 (mod 8)
      end
      #4;
      if (value !== j) begin
        $display("Error(teste: %d) value = %d, j = %d", i, value, j);
        $stop;
      end
      #5;
    end
    $display("EOT!");
    $stop;
  end
endmodule
