
module priority_encoder #(
  parameter integer N = 8
) (
  input wire [N-1:0] A,
  output wire [N == 1 ? 0 : $clog2(N)-1:0] Y
);

genvar i;
wire [N == 1 ? 0 : $clog2(N)-1:0] temp [N:0];

generate
  for(i = 0; i <= N; i = i + 1) begin: gen_output
    if(i == 0) assign temp[0] = 0;
    else assign temp[i] = A[i-1] ? (i-1) : temp[i-1];
  end
endgenerate

assign Y = temp[N];

endmodule
