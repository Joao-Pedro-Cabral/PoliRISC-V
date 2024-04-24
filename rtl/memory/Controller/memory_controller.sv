
module memory_controller #(
    parameter integer PRIMARY_INTERFACES = 2,
    parameter integer SECONDARY_INTERFACES = 8,
    parameter [63:0] PRIMARY_MASKS [PRIMARY_INTERFACES-1:0],
    parameter [63:0] SECONDARY_MASKS [SECONDARY_INTERFACES-1:0]
) (
    wishbone_if.primary [PRIMARY_INTERFACES-1:0] wish_p_array,
    wishbone_if.secondary [SECONDARY_INTERFACES-1:0] wish_s_array
);

genvar i, j;

// Secondary Bus -> Primary Bus
logic [PRIMARY_INTERFACES-1:0] [SECONDARY_INTERFACES-1:0] primary_cs_array;
logic [PRIMARY_INTERFACES-1:0] [$clog2(SECONDARY_INTERFACES)-1:0] primary_sel_array;

generate;
  for(i = 0; i < PRIMARY_INTERFACES; i ++) begin: gen_primary_cs_array_row
    for(j = 0; j < SECONDARY_INTERFACES; j++) begin: gen_primary_cs_array_column
      assign primary_cs_array[i][j] = wish_s_array[j].cyc & wish_s_array[j].stb &
        ((wish_s_array[j].addr & PRIMARY_MASKS[i]) == PRIMARY_MASKS[i]);
    end
    priority_encoder #(
      .N(SECONDARY_INTERFACES)
    ) primary_sel_encoder (
      .A(primary_cs_array[i]),
      .Y(primary_sel_array[i])
    );
    assign wish_p_array[i].cyc = wish_s_array[primary_sel_array[i]].cyc &
                                  primary_cs_array[primary_sel_array[i]];
    assign wish_p_array[i].stb = wish_s_array[primary_sel_array[i]].stb &
                                  primary_cs_array[primary_sel_array[i]];
    assign wish_p_array[i].we = wish_s_array[primary_sel_array[i]].we &
                                  primary_cs_array[primary_sel_array[i]];
    assign wish_p_array[i].addr = wish_s_array[primary_sel_array[i]].addr;
    assign wish_p_array[i].sel = wish_s_array[primary_sel_array[i]].sel;
    assign wish_p_array[i].tgd = wish_s_array[primary_sel_array[i]].tgd;
    assign wish_p_array[i].dat_i_p = wish_s_array[primary_sel_array[i]].dat_o_s;
  end
endgenerate

// Primary Bus -> Secondary Bus
logic [SECONDARY_INTERFACES-1:0] [PRIMARY_INTERFACES-1:0] secondary_cs_array;
logic [SECONDARY_INTERFACES-1:0] [$clog2(PRIMARY_INTERFACES)-1:0] secondary_sel_array;

generate;
  for(i = 0; i < SECONDARY_INTERFACES; i ++) begin: gen_secondary_cs_array_row
    for(j = 0; j < PRIMARY_INTERFACES; j++) begin: gen_secondary_cs_array_column
      assign secondary_cs_array[i][j] = primary_cs_array[j][i];
    end
    priority_encoder #(
      .N(PRIMARY_INTERFACES)
    ) secondary_sel_encoder (
      .A(secondary_cs_array[i]),
      .Y(secondary_sel_array[i])
    );
    assign wish_s_array[i].ack = wish_p_array[secondary_sel_array[i]].ack &
                                  (primary_sel_array[secondary_sel_array[i]] == i);
    assign wish_s_array[i].dat_i_s = wish_p_array[secondary_sel_array[i]].dat_o_p;
  end
endgenerate

endmodule
