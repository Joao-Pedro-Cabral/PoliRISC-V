
module left_barrel_shifter_tb;

  import macros_pkg::*;

  localparam integer QntdTestes = 32;

  // sinais do DUT
  reg  [31:0] in_data;
  reg  [ 4:0] shamt;
  wire [31:0] out_data;

  // Instanciação do DUT
  left_barrel_shifter #(
      .XLEN(32)
  ) DUT (
      .in_data(in_data),
      .shamt(shamt),
      .out_data(out_data)
  );

  // tabela com sinais de entrada e saídas esperadas
  reg [68:0] casos_de_teste[QntdTestes-1:0];

  integer i;
  initial begin
    $readmemb("./MIFs/core/Shifter/casos_de_teste_lbs.mif", casos_de_teste);
    {in_data, shamt} = 0;

    $display("SOT!");
    for (i = 0; i < QntdTestes; i = i + 1) begin
      in_data = casos_de_teste[i][31:0];
      shamt   = casos_de_teste[i][36:32];
      #10;
      if (out_data != casos_de_teste[i][68:37])
        $display(
            "Caso %d: ERRO --- recebeu: %b esperava: %b\n\tshamt: %b",
            i,
            out_data,
            casos_de_teste[i][68:37],
            shamt
        );
      else $display("Caso %d: ACERTO", i);
    end

  end

endmodule

