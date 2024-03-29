
module sklansky_adder #(
    // quantidade de bits em cada número
    parameter integer INPUT_SIZE = 4
) (
    input wire [INPUT_SIZE-1:0] A,
    input wire [INPUT_SIZE-1:0] B,
    input wire c_in,  // carry in
    output wire c_out,  // carry out
    output wire [INPUT_SIZE-1:0] S  // resultado da soma
);

  wire [INPUT_SIZE:0] G[INPUT_SIZE:0];
  wire [INPUT_SIZE:0] P[INPUT_SIZE:0];
  wire half_sum_carry_out;
  wire propagate_carry_out;
  wire generate_carry_out;

  assign G[0][0] = c_in;
  assign P[0][0] = 1'b0;

  function automatic integer min(input integer a, input integer b);
    begin
      min = a;
      if (a > b) min = b;
    end
  endfunction

  genvar i, m, n;
  generate

    // prefixos (propagates e generates) iniciais
    for (i = 1; i <= INPUT_SIZE; i = i + 1) begin : g_precomputation
      and (G[i][i], A[i-1], B[i-1]);
      or (P[i][i], A[i-1], B[i-1]);
    end

    for (i = 0; i < $clog2(INPUT_SIZE); i = i + 1) begin : g_levels  // camadas de prefixos
      for (m = 2 ** i - 1; m < INPUT_SIZE; m = m + 2 ** (i + 1)) begin : g_blocks  // blocos
        for (n = m + 1; n < min(INPUT_SIZE, m + 1 + 2 ** i); n = n + 1) begin : g_prefixes
          prefix_operator propagate_generate (  // cálculo dos prefixos
              .g_i(G[n][m+1]),
              .g_j(G[m][m-2**i+1]),
              .p_i(P[n][m+1]),
              .p_j(P[m][m-2**i+1]),
              .g  (G[n][m-2**i+1]),
              .p  (P[n][m-2**i+1])
          );
        end
      end
    end

    for (i = 0; i < INPUT_SIZE; i = i + 1) begin : g_result
      xor (S[i], A[i], B[i], G[i][0]);
    end
  endgenerate

  // cálculo do carry out
  and (generate_carry_out, A[INPUT_SIZE-1], B[INPUT_SIZE-1]);
  xor (half_sum_carry_out, A[INPUT_SIZE-1], B[INPUT_SIZE-1]);
  and (propagate_carry_out, half_sum_carry_out, G[INPUT_SIZE-1][0]);
  or (c_out, propagate_carry_out, generate_carry_out);

endmodule
