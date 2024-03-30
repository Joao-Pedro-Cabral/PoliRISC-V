
module full_barrel_shifter_tb;

  import macros_pkg::*;

  localparam integer QntdTestes = 96;

  // sinais do DUT
  reg [31:0] in_data;
  reg [4:0] shamt;
  reg left_or_right_shift;
  reg arithmetic_right_shift;
  wire [31:0] out_data;

  // Instanciação do DUT
  full_barrel_shifter #(
      .XLEN(32)
  ) DUT (
      .in_data(in_data),
      .shamt(shamt),
      .left_or_right_shift(left_or_right_shift),
      .arithmetic_right_shift(arithmetic_right_shift),
      .out_data(out_data)
  );

  // tabela com sinais de entrada e saídas esperadas
  reg [70:0] casos_de_teste[QntdTestes-1:0];

  integer i;
  initial begin
    $readmemb("./MIFs/core/Shifter/casos_de_teste_fbs.mif", casos_de_teste);
    {in_data, shamt, left_or_right_shift, arithmetic_right_shift} = 0;

    $display("SOT!");
    for (i = 0; i < QntdTestes; i = i + 1) begin
      in_data = casos_de_teste[i][31:0];
      shamt = casos_de_teste[i][36:32];
      left_or_right_shift = casos_de_teste[i][37];
      arithmetic_right_shift = casos_de_teste[i][38];
      #10;
      if (out_data != casos_de_teste[i][70:39])
        $display(
            "Caso %d: ERRO --- recebeu: %b esperava: %b", i, out_data, casos_de_teste[i][70:39]
        );
      else $display("Caso %d: ACERTO", i);
    end

  end

endmodule
