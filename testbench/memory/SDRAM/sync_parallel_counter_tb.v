//
//! @file   sync_parallel_counter_tb.v
//! @brief  Testbench do Contador
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-29
//

`timescale 1ns / 100ps

module sync_parallel_counter_tb ();
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
      reset      = $random;
      inc_enable = $random;
      dec_enable = ~inc_enable;
      load       = $random;
      load_value = $random;
      #0.1;
      // A partir das novas entradas, gero o novo j
      if (reset) j = 2;
      else if (load) j = load_value;
      else if (inc_enable) j = (j + 1) % 8;
      else if (dec_enable) j = (j + 7) % 8;  // j - 1 = j + 7 (mod 8)
      #4.9;
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
