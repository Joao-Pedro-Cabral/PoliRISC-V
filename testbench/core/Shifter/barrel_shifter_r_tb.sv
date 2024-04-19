
module barrel_shifter_r_tb ();

  import macros_pkg::*;

  // portas do DUT
  reg [7:0] [3:0] A;
  reg [2:0] shamt;
  reg arithmetic;
  wire [7:0] [3:0] Y;
  // auxiliares
  reg [7:0] [3:0] B[7:0];
  // variáveis de iteração
  genvar i;
  integer j;

  // instanciando o DUT
  barrel_shifter_r #(
      .N(3),
      .M(4)
  ) DUT (
      .A(A),
      .shamt(shamt),
      .Y(Y),
      .arithmetic(arithmetic)
  );

  // initial para testar o DUT
  initial begin
    $display("SOT!");
    for(int i = 0; i < 8; i ++)
      B[i] = $urandom();
    $display("0!");
    #2;
    arithmetic = 1'b0;  // SRL
    for (j = 0; j < 8; j = j + 1) begin
      A = B[j];
      shamt = j;
      #1;
      CHK_LOGIC_SHIFT: assert(Y === (B[j] >> 4*j));
      #1;
    end
    arithmetic = 1'b1;  // SRA
    $display("1!");
    for (j = 0; j < 8; j = j + 1) begin
      A = B[j];
      shamt = j;
      #1;
      CHK_ARITHMETIC_SHIFT: assert($signed(Y) === ($signed(B[j]) >>> $signed(4*j)));
      #1;
    end
    $display("EOT!");
  end

endmodule
