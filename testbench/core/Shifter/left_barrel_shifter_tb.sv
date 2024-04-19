
module left_barrel_shifter_tb;

  import macros_pkg::*;

  localparam integer QntdTestes = 10_000;

  // sinais do DUT
  reg  [31:0] [3:0] in_data;
  reg  [ 4:0] shamt;
  wire [31:0] [3:0] out_data;

  // Instanciação do DUT
  left_barrel_shifter #(
      .XLEN(32),
      .YLEN(4)
  ) DUT (
      .in_data(in_data),
      .shamt(shamt),
      .out_data(out_data)
  );

  initial begin
    {in_data, shamt} = 0;

    $display("SOT!");
    for (int i = 0; i < QntdTestes; i = i + 1) begin
      in_data = {$urandom(), $urandom(), $urandom(), $urandom()};
      shamt   = $urandom();
      #5;
      CHK_DATA: assert(out_data === in_data << (shamt*4));
      #5;
    end

    $display("EOT!");

  end

endmodule

