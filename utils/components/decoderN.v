
module decoderN (
    A,
    enable,
    Y
);
  parameter integer N = 5;
  input wire [N - 1:0] A;
  input wire enable;
  output reg [2**N - 1:0] Y;

  always @(*) begin
    if (enable == 1) begin
      Y    = 0;
      Y[A] = 1;
    end else Y = 0;
  end
endmodule
