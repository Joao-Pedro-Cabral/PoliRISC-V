
module priority_encoder_tb();

  import macros_pkg::*;

  localparam integer N = 16;

  logic [N-1:0] A;
  logic [N == 1 ? 0 : $clog2(N)-1:0] Y, expected_data;

  priority_encoder #(
    .N(N)
  ) DUT (
    .A(A),
    .Y(Y)
  );

  initial begin
    $display("SOT!");
    A = 0;
    #5;
    for(int i = 0; i < 2**N; i ++) begin
      A = i;
      if(i == 0) expected_data = 0;
      else expected_data = $clog2(A+1) - 1;
      #2;
      CHK_Y: assert(Y === expected_data);
      #3;
    end
    $display("EOT!");
  end

endmodule
