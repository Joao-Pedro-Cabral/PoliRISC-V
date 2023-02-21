module prefix_operator
(
    input  g_i,
    input  g_j,
    input  p_i,
    input  p_j,
    output wire g,
    output wire p
);

    wire p_i_g_j;

    and(p_i_g_j, p_i, g_j);

    or(g, g_i, p_i_g_j);
    and(p, p_i, p_j);

endmodule
