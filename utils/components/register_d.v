
module register_d (
    clock,
    reset,
    enable,
    D,
    Q
);
  parameter N = 4;
  parameter reset_value = 1;
  input wire clock, reset, enable;
  input wire [N - 1:0] D;
  output reg [N - 1:0] Q;

  always @(posedge clock, posedge reset)
    if (reset == 1) Q <= reset_value;
    else if (enable == 1) Q <= D;
    else Q <= Q;
endmodule
