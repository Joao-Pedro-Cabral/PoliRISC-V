
module full_barrel_shifter_tb;

  import macros_pkg::*;

  localparam integer QntdTestes = 10;

  // sinais do DUT
  reg [31:0] [3:0] in_data;
  reg [4:0] shamt;
  reg left_or_right_shift;
  reg arithmetic_right_shift;
  wire [31:0] [3:0] out_data;

  // Instanciação do DUT
  full_barrel_shifter #(
      .XLEN(32),
      .YLEN(4)
  ) DUT (
      .in_data(in_data),
      .shamt(shamt),
      .left_or_right_shift(left_or_right_shift),
      .arithmetic_right_shift(arithmetic_right_shift),
      .out_data(out_data)
  );

  initial begin
    {in_data, shamt, left_or_right_shift, arithmetic_right_shift} = 0;

    $display("SOT!");
    for (int i = 0; i < QntdTestes; i = i + 1) begin
      in_data = {$urandom(), $urandom(), $urandom(), $urandom()};
      shamt = $urandom();
      left_or_right_shift = $urandom();
      arithmetic_right_shift =$urandom();
      #5;
      if(left_or_right_shift) begin
        if(arithmetic_right_shift) CHK_RIGHT_ARITH_SHIFT:
          assert($signed(out_data) === ($signed(in_data) >>> $signed(shamt*4)));
        else
          CHK_RIGHT_LOGIC_SHIFT: assert(out_data === (in_data >> shamt*4));
      end
      else CHK_LEFT_SHIFT: assert(out_data === in_data << (shamt*4));
      #5;
    end
    $display("EOT!");

  end

endmodule
