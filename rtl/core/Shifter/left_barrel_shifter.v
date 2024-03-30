
module left_barrel_shifter #(
    parameter integer XLEN = 32
) (
    input wire [XLEN-1:0] in_data,
    input wire [$clog2(XLEN)-1:0] shamt,
    output wire [XLEN-1:0] out_data
);

  wire [XLEN-1:0] O[$clog2(XLEN):0];
  assign O[0] = in_data;
  assign out_data = O[$clog2(XLEN)];
  wire [XLEN-1:0] b_in_wire[$clog2(XLEN)-1:0];


  genvar i, j;
  generate

    for (i = 0; i < $clog2(XLEN); i = i + 1) begin : g_columns
      for (j = 0; j < XLEN; j = j + 1) begin : g_rows
        assign b_in_wire[i][j] = (j < ('b01 << i)) ? (1'b0) : (O[i][j-('sb01<<i)]);
      end
    end

    for (i = 1; i <= $clog2(XLEN); i = i + 1) begin : g_columns2
      for (j = 0; j < XLEN; j = j + 1) begin : g_rows2
        mux2to1 #(
            .size(1)
        ) O_i_j (
            .A(O[i-1][j]),
            .B(b_in_wire[i-1][j]),
            .S(shamt[i-1]),
            .Y(O[i][j])
        );
      end
    end
  endgenerate

endmodule
