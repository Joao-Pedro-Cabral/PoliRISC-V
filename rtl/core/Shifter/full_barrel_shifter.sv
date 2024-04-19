
module full_barrel_shifter #(
    parameter integer XLEN = 32,
    parameter integer YLEN = 4
) (
    input wire [XLEN-1:0] [YLEN-1:0] in_data,
    input wire [$clog2(XLEN)-1:0] shamt,
    input wire left_or_right_shift,  // 0 or 1: funct3[2] of SLL/SRL/SRA
    input wire arithmetic_right_shift,  // SRL/SRA instruction[30]
    output wire [XLEN-1:0] [YLEN-1:0] out_data
);

  wire [XLEN-1:0] [YLEN-1:0] O[$clog2(XLEN):0];
  wire [XLEN-1:0] [YLEN-1:0] b_in_wire[$clog2(XLEN)-1:0];
  wire [YLEN-1:0] msb;


  assign O[0] = in_data;
  assign out_data = O[$clog2(XLEN)];
  assign msb = {YLEN{arithmetic_right_shift & O[0][XLEN-1][YLEN-1]}};


  genvar i, j;
  generate

    for (i = 0; i < $clog2(XLEN); i = i + 1) begin : g_columns
      for (j = 0; j < XLEN; j = j + 1) begin : g_rows
        mux2to1  // decides b_in signal of main shift muxes
        #(
            .size(YLEN)
        ) b_i_j (
            .A((j < ('b01 << i))  // j < 2^i
 ? '0 : O[i][j-('b01<<i)]),
            .B(((j + ('b01 << i)) >= XLEN) ? msb : O[i][j+('b01<<i)]),
            .S(left_or_right_shift),
            .Y(b_in_wire[i][j])
        );
      end
    end


    for (i = 1; i <= $clog2(XLEN); i = i + 1) begin : g_columns2
      for (j = 0; j < XLEN; j = j + 1) begin : g_rows2
        mux2to1  // main shift muxes
        #(
            .size(YLEN)
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
