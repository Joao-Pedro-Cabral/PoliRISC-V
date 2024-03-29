
module mux2to1 (
    A,
    B,
    S,
    Y
);
  parameter integer size = 4;
  input wire [size - 1:0] A;
  input wire [size - 1:0] B;
  input wire S;
  output wire [size - 1:0] Y;

  assign Y = (S == 1'b1) ? B : A;

endmodule
