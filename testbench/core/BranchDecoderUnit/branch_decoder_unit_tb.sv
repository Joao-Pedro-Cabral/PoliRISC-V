
module branch_decoder_unit_tb;
  import branch_decoder_unit_pkg::*;
  import macros_pkg::*;

  localparam integer Seed = 69420;
  localparam integer Interval = 1;
  localparam integer Width = 64;

  branch_t branch_type;
  cond_branch_t cond_branch_type;
  logic [Width-1:0] read_data_1;
  logic [Width-1:0] read_data_2;
  pc_src_t pc_src;

  branch_decoder_unit #(.Width(Width)) DUT (.*);

  // test vars
  branch_t branch_type_vec[branch_type.num()];
  cond_branch_t cond_branch_type_vec[cond_branch_type.num()];

  initial begin
    $display("SOT!");
    init_test_vars;

    foreach (branch_type_vec[i]) begin
      branch_type = branch_type_vec[i];
      unique case (branch_type_vec[i])
        NoBranch: begin
          #Interval;
          NO_BRANCH :
          assert (pc_src == PcPlus4) $display("Case %s: OK", branch_type_vec[i].name());
          else $stop;
        end
        Jump: begin
          #Interval;
          JUMP :
          assert (pc_src == PcOrReadDataPlusImm) $display("Case %s: OK", branch_type_vec[i].name());
          else $stop;
        end
        CondBranch: begin
          test_cond_branch;
        end
        default: begin
          $display("ERROR: undefined branch");
          $stop;
        end
      endcase
    end
    $display("EOT!");
    $stop;
  end

  task automatic init_test_vars;
    branch_t branch_val = branch_val.first;
    cond_branch_t cond_branch_val = cond_branch_val.first;

    foreach (branch_type_vec[i]) begin
      branch_type_vec[i] = branch_val;
      branch_val = branch_val.next();
    end

    foreach (cond_branch_type_vec[i]) begin
      cond_branch_type_vec[i] = cond_branch_val;
      cond_branch_val = cond_branch_val.next();
    end

    void'($urandom(Seed));
  endtask

  task automatic test_cond_branch;
    foreach (cond_branch_type_vec[j]) begin
      cond_branch_type = cond_branch_type_vec[j];
      branch_taken(cond_branch_type_vec[j]);
      #Interval;
      COND_BRANCH_TAKEN :
      assert (pc_src == PcOrReadDataPlusImm)
        $display("Taken %s branch case: OK", cond_branch_type_vec[j].name());
      else $stop;

      branch_not_taken(cond_branch_type_vec[j]);
      #Interval;
      COND_BRANCH_NOT_TAKEN :
      assert (pc_src == PcPlus4)
        $display("Not taken %s branch case: OK", cond_branch_type_vec[j].name());
      else $stop;
    end
  endtask

  task automatic branch_taken(cond_branch_t cond_branch);
    read_data_1 = $urandom;
    do begin
      read_data_2 = cond_branch == Beq ? read_data_1 : $urandom;
      #Interval;
    end while (!is_cond_branch_taken(
        cond_branch, read_data_1, read_data_2
    ));
  endtask

  task automatic branch_not_taken(cond_branch_t cond_branch);
    read_data_1 = $urandom;
    do begin
      read_data_2 = cond_branch == Bne ? read_data_1 : $urandom;
      #Interval;
    end while (is_cond_branch_taken(
        cond_branch, read_data_1, read_data_2
    ));
  endtask

  function automatic bit is_cond_branch_taken(input cond_branch_t cond_branch,
                                              input logic [Width-1:0] rd_dat_1,
                                              input logic [Width-1:0] rd_dat_2);
    unique case (cond_branch)
      Beq:  return $signed(rd_dat_1) == $signed(rd_dat_2);
      Bne:  return $signed(rd_dat_1) != $signed(rd_dat_2);
      Blt:  return $signed(rd_dat_1) < $signed(rd_dat_2);
      Bge:  return $signed(rd_dat_1) >= $signed(rd_dat_2);
      Bltu: return rd_dat_1 < rd_dat_2;
      Bgeu: return rd_dat_1 >= rd_dat_2;

      default: begin
        $display("ERROR: undefined conditional branch");
        $stop;
      end
    endcase
  endfunction
endmodule
