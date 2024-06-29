
module forwarding_unit_tb ();
  import macros_pkg::*;
  import dataflow_pkg::*;
  import forwarding_unit_pkg::*;

  // Parameters
  localparam int N = 12;
  int number_of_tests = 100_000;

  // DUT Signals
  forwarding_type_t forwarding_type_id, forwarding_type_ex, forwarding_type_mem;
  logic reg_we_ex, reg_we_mem, reg_we_wb;
  logic [N-1:0] rd_ex, rd_mem, rd_wb, rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem;
  forwarding_t forward_rs1_id, forward_rs2_id, forward_rs1_ex, forward_rs2_ex, forward_rs2_mem;

  function automatic bit match_registers(input logic [N-1:0] rs, input logic [N-1:0] rd,
                                         input logic we);
    return ((rs === rd) && (rd !== 0) && we);
  endfunction

  function automatic bit check_type(input forwarding_type_t forward_type,
                                    input stages_t current_stage, input stages_t forwading_stage,
                                    input logic rs_num);
    unique case (forward_type)
      ForwardExecute:
        return (current_stage === Decode && forwading_stage === WriteBack) ||
                      (current_stage === Execute && (forwading_stage inside {Memory, WriteBack}));
      ForwardDecode:
        return (current_stage === Decode && (forwading_stage inside {Execute, Memory, WriteBack}));
      ForwardExecuteMemory:
        return (current_stage === Decode && forwading_stage === WriteBack) ||
                      (current_stage === Execute && (forwading_stage inside {Memory, WriteBack})) ||
                      (current_stage === Memory && forwading_stage === WriteBack && rs_num);
      default: return 1'b0; // NoForward
    endcase
  endfunction

  function automatic forwarding_t get_forward_t(
      input logic [N-1:0] rs, input logic rs_num, input logic [N-1:0] rd_ex,
      input logic [N-1:0] rd_mem, input logic [N-1:0] rd_wb, input forwarding_type_t forward_type,
      input stages_t stage, input logic reg_we_ex, input logic reg_we_mem, input logic reg_we_wb);
    if (match_registers(rs, rd_ex, reg_we_ex) &&
        check_type(forward_type, stage, Execute, rs_num))
      return ForwardFromEx;
    else if (match_registers(rs, rd_mem, reg_we_mem) &&
        check_type(forward_type, stage, Memory, rs_num))
      return ForwardFromMem;
    else if (match_registers(rs, rd_wb, reg_we_wb) &&
        check_type(forward_type, stage, WriteBack, rs_num))
      return ForwardFromWb;
    else return NoForwarding;
  endfunction

  function automatic logic [N-1:0] gen_rd(input logic [4:0] [N-1:0] rs_list);
    int i;
    begin
      i = $urandom()%6;
      return i == 5 ? 0 : rs_list[i];
    end
  endfunction

  forwarding_unit #(.N(N)) DUT (.*);

  initial begin : verify_dut
    $display("SOT!");
    repeat (number_of_tests) begin
      forwarding_type_id = forwarding_type_t'($urandom() % forwarding_type_id.num());
      {forwarding_type_ex, forwarding_type_mem} = $urandom();
      {reg_we_ex, reg_we_mem, reg_we_wb} = $urandom();
      {rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem} = $urandom();
      rd_ex = gen_rd({rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem});
      rd_mem = gen_rd({rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem});
      rd_wb = gen_rd({rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem});
      #5;
      CHECK_RS1_ID :
      assert (forward_rs1_id === get_forward_t(
          rs1_id,
          1'b0,
          rd_ex,
          rd_mem,
          rd_wb,
          forwarding_type_id,
          Decode,
          reg_we_ex,
          reg_we_mem,
          reg_we_wb
      ));
      CHECK_RS2_ID :
      assert (forward_rs2_id === get_forward_t(
          rs2_id,
          1'b1,
          rd_ex,
          rd_mem,
          rd_wb,
          forwarding_type_id,
          Decode,
          reg_we_ex,
          reg_we_mem,
          reg_we_wb
      ));
      CHECK_RS1_EX :
      assert (forward_rs1_ex === get_forward_t(
          rs1_ex, 1'b0, rd_ex, rd_mem, rd_wb, forwarding_type_ex, Execute, 1'b0, reg_we_mem,
          reg_we_wb));
      CHECK_RS2_EX :
      assert (forward_rs2_ex === get_forward_t(
          rs2_ex, 1'b1, rd_ex, rd_mem, rd_wb, forwarding_type_ex, Execute, 1'b0, reg_we_mem,
          reg_we_wb));
      CHECK_RS2_MEM :
      assert (forward_rs2_mem === get_forward_t(
          rs2_mem, 1'b1, rd_ex, rd_mem, rd_wb, forwarding_type_mem, Memory, 1'b0, 1'b0, reg_we_wb
      ));
      #5;
    end
    $display("EOT!");
    $stop();
  end : verify_dut

endmodule
