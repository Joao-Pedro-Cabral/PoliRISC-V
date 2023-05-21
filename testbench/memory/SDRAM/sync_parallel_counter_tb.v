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
  reg [2:0] load_value;
  wire [2:0] value;
  wire [2:0] tests[16:0];  // array de testes: {enable, reset}

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

  // inicialização do array de testes
  assign tests[0]  = 1'b1;
  assign tests[1]  = 2'b10;
  assign tests[2]  = 2'b10;
  assign tests[3]  = 3'b110;
  assign tests[4]  = 3'b100;
  assign tests[5]  = 2'b10;
  assign tests[6]  = 2'b11;
  assign tests[7]  = 3'b110;
  assign tests[8]  = 3'b110;
  assign tests[9]  = 2'b10;
  assign tests[10] = 2'b10;
  assign tests[11] = 3'b110;
  assign tests[12] = 1'b0;
  assign tests[13] = 2'b10;
  assign tests[14] = 2'b10;
  assign tests[15] = 2'b10;
  assign tests[16] = 3'b100;

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
    for (i = 0; i < 17; i = i + 1) begin
      reset      = $random;
      inc_enable = $random;
      dec_enable = ~inc_enable;
      load       = $random;
      load_value = $random;  // carga aleatória
      // incremento 1 em j quando enable está alto
      // testbench do contador
      if (reset) j = 0;
      else if (load) j = load_value;
      else if (inc_enable) j = (j + 1) % 8;
      // carga paralela
      if (tests[i][2] === 1'b1) j = load_value;
      #0.1;
      // j ultrapassou o limite 7
      if (j === 8) j = 0;
      #0.1;
      // reseto j quando reset = 1
      if (tests[i][0] === 1'b1) j = 2;
      #4.8;
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
