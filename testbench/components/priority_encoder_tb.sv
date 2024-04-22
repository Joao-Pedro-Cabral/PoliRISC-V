
module priority_encoder_tb();

  import macros_pkg::*;

  localparam integer NumberOfTests = 16;

  logic [15:0] A;
  logic [3:0] Y, expected_data;

  priority_encoder #(
    .N(16)
  ) DUT (
    .A(A),
    .Y(Y)
  );

  initial begin
    $display("SOT!");
    A = 0;
    #5;
    for(int i = 0; i < NumberOfTests; i ++) begin
      A = i;
      expected_data = $clog2(A+1);
      #2;
      CHK_Y: assert(Y === expected_data);
      #3;
    end
    $display("EOT!");
  end

endmodule
