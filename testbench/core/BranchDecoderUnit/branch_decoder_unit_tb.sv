import branch_decoder_unit_pkg::*;

module branch_decoder_unit_tb;
  localparam integer Seed = 69420;
  localparam integer IntervalBetweenTests = 1;
  localparam integer Width = 32;

  branch_t branch_type;
  cond_branch_t cond_branch_type;
  logic [Width-1:0] read_data_1;
  logic [Width-1:0] read_data_2;
  logic [1:0] pc_src;

  localparam logic [1:0] PcPlus4Src = 2'b00;
  localparam logic [1:0] SepcSrc = 2'b01;
  localparam logic [1:0] MepcSrc = 2'b10;
  localparam logic [1:0] PcOrReadDataPlusImmSrc = 2'b11;

  branch_decoder_unit #(.Width) DUT (.*);

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
          #IntervalBetweenTests;
          assert (pc_src == PcPlus4Src);
        end
        Mret: begin
          #IntervalBetweenTests;
          assert (pc_src == MepcSrc);
        end
        Sret: begin
          #IntervalBetweenTests;
          assert (pc_src == SepcSrc);
        end
        Jump: begin
          #IntervalBetweenTests;
          assert (pc_src == PcOrReadDataPlusImmSrc);
        end
        CondBranch: begin
          test_cond_branch;
        end
        default: begin
          $display("ERROR: undefined branch value");
          $error;
        end
      endcase
      $display("Case %s: OK", branch_type_vec[i].name());
    end
    $display("EOT!");
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

    $urandom(Seed);
  endtask

  task automatic test_cond_branch;
    foreach (cond_branch_type_vec[j]) begin
      cond_branch_type = cond_branch_type_vec[j];
      branch_taken(cond_branch_type_vec[j]);
      #IntervalBetweenTests;
      assert (pc_src == PcOrReadDataPlusImmSrc);
      $display("Taken %s branch case: OK", cond_branch_type_vec[j].name());

      branch_not_taken(cond_branch_type_vec[j]);
      #IntervalBetweenTests;
      assert (pc_src == PcPlus4Src);
      $display("Not taken %s branch case: OK", cond_branch_type_vec[j].name());
    end
  endtask

  task automatic branch_taken(cond_branch_t cond_branch);
    read_data_1 = $urandom;
    unique case (cond_branch)
      Beq: begin
        read_data_2 = read_data_1;
      end
      Bne: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) == $signed(read_data_2));
      end
      Blt: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) >= $signed(read_data_2));
      end
      Bge: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) < $signed(read_data_2));
      end
      Bltu: begin
        do begin
          read_data_2 = $urandom;
        end while (read_data_1 >= read_data_2);
      end
      Bgeu: begin
        do begin
          read_data_2 = $urandom;
        end while (read_data_1 < read_data_2);
      end
      default: begin
        $display("ERROR: undefined conditional branch value");
        $error;
      end
    endcase
  endtask

  task automatic branch_not_taken(cond_branch_t cond_branch);
    read_data_1 = $urandom;
    unique case (cond_branch)
      Beq: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) == $signed(read_data_2));
      end
      Bne: begin
        read_data_2 = read_data_1;
      end
      Blt: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) < $signed(read_data_2));
      end
      Bge: begin
        do begin read_data_2 = $urandom;
            end while ($signed(read_data_1) >= $signed(read_data_2));
      end
      Bltu: begin
        do begin
          read_data_2 = $urandom;
        end while (read_data_1 < read_data_2);
      end
      Bgeu: begin
        do begin
          read_data_2 = $urandom;
        end while (read_data_1 >= read_data_2);
      end
      default: begin
        $display("ERROR: undefined conditional branch value");
        $error;
      end
    endcase
  endtask

endmodule
