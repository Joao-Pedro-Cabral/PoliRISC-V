
module gen_mux_tb ();

  import macros_pkg::*;

  // portas do DUT
  wire [3:0] A [7:0];
  reg  [2:0] S;
  wire [3:0] Y;
  // variáveis de iteração
  genvar i;
  integer j;

  // inicializando A
  generate
    for (i = 0; i < 8; i = i + 1) begin
      assign A[i] = i + 5;
    end
  endgenerate

  // instanciando o DUT
  gen_mux #(
      .size(4),
      .N(3)
  ) DUT (
      {A[7], A[6], A[5], A[4], A[3], A[2], A[1], A[0]},
      S,
      Y
  );

  // initial para testar o DUT
  initial begin
    $display("SOT!");
    for (j = 0; j < 8; j = j + 1) begin
      S = j;
      #10;
      if (Y !== A[j]) begin
        $display("Error: A[%d] = %b, Y = %b", j, A[j], Y);
      end
      #10;
    end
    $display("EOT!");
  end
endmodule
