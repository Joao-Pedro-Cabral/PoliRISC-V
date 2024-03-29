
module prefix_operator (
    input  wire g_i,
    input  wire g_j,
    input  wire p_i,
    input  wire p_j,
    output wire g,
    output wire p
);

  wire p_i_g_j;

  and (p_i_g_j, p_i, g_j);

  or (g, g_i, p_i_g_j);
  and (p, p_i, p_j);

endmodule
