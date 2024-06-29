import branch_decoder_unit_pkg::*;

module branch_decoder_unit #(
    parameter integer Width = 32
) (
    input branch_t branch_type,
    input cond_branch_t cond_branch_type,
    input logic [Width-1:0] read_data_1,
    input logic [Width-1:0] read_data_2,
    output pc_src_t pc_src
);

  logic cond_branch_taken;
  logic negative, carry_out, overflow, zero;
  logic [Width-1:0] sub_res;

  // Main Logic
  always_comb begin : pc_src_proc
    unique case (branch_type)
      NoBranch: pc_src = PcPlus4;
      Jump: pc_src = PcOrReadDataPlusImm;
      default: pc_src = cond_branch_taken ? PcOrReadDataPlusImm : PcPlus4;  // CondBranch
    endcase
  end : pc_src_proc

  always_comb begin : cond_branch_taken_proc
    cond_branch_taken = 1'b0;
    unique case (cond_branch_type)
      Beq: cond_branch_taken = zero;
      Bne: cond_branch_taken = ~zero;
      Blt: cond_branch_taken = negative ^ overflow;
      Bge: cond_branch_taken = ~(negative ^ overflow);
      Bltu: cond_branch_taken = ~carry_out;
      Bgeu: cond_branch_taken = carry_out;
      default: cond_branch_taken = 1'b0;
    endcase
  end : cond_branch_taken_proc

  // Sub Logic
  sklansky_adder #(
      .INPUT_SIZE(Width)
  ) subtractor (
      .A(read_data_1),
      .B(~read_data_2),
      .c_in(1'b1),
      .c_out(carry_out),
      .S(sub_res)
  );

  // flags da ALU
  assign negative = sub_res[Width-1];
  assign overflow = (read_data_1[Width-1] ^ read_data_2[Width-1]) &
                    (read_data_1[Width-1] ^ sub_res[Width-1]);
  assign zero = ~(|sub_res);

endmodule
