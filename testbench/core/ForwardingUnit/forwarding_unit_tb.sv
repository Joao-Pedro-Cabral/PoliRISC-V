
module forwarding_unit_tb ();
  import macros_pkg::*;
  import dataflow_pkg::*;
  import forwarding_unit_pkg::*;

  int number_of_tests = 10000;

  // DUT Signals
  forwarding_type_t forwarding_type_id, forwarding_type_ex, forwarding_type_mem;
  logic reg_we_mem, reg_we_wb, zicsr_ex;
  logic [4:0] rd_ex, rd_mem, rd_wb, rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem;
  forwarding_t forward_rs1_id, forward_rs2_id, forward_rs1_ex, forward_rs2_ex, forward_rs2_mem;

  function automatic bit match_registers(input logic [4:0] rs, input logic [4:0] rd,
                                         input logic we);
    return ((rs === rd) && (rd !== 0) && we);
  endfunction

  function automatic bit check_type(input forwarding_type_t forward_type,
                                    input stages_t current_stage, input stages_t forwading_stage,
                                    input logic rs_num, input logic zicsr_ex = 0);
    unique case (forward_type)
      Type1:
      return (current_stage === Decode && forwading_stage === WriteBack) ||
                    (current_stage === Execute && (forwading_stage inside {Memory, WriteBack}));
      Type2:
      return (current_stage === Decode && ((forwading_stage === Execute && rs_num === 1'b0
                    && zicsr_ex) || (forwading_stage inside {Memory, WriteBack})));
      Type1_3:
      return (current_stage === Decode && forwading_stage === WriteBack) ||
                      (current_stage === Execute && (forwading_stage inside {Memory, WriteBack})) ||
                      (current_stage === Memory && forwading_stage === WriteBack && rs_num);
      default: return 1'b0; // NoType
    endcase
  endfunction

  function automatic forwarding_t get_forward_t(
      input logic [4:0] rs, input logic rs_num, input logic [4:0] rd_ex, input logic [4:0] rd_mem,
      input logic [4:0] rd_wb, input forwarding_type_t forward_type, input stages_t stage,
      input logic reg_we_mem, input logic reg_we_wb, input logic zicsr_ex = 1'b0);
    if (match_registers(
            rs, rd_ex, zicsr_ex
        ) && check_type(
            forward_type, stage, Execute, rs_num, zicsr_ex
        ))
      return ForwardFromEx;
    else if (match_registers(
            rs, rd_mem, reg_we_mem
        ) && check_type(
            forward_type, stage, Memory, rs_num
        ))
      return ForwardFromMem;
    else if (match_registers(
            rs, rd_wb, reg_we_wb
        ) && check_type(
            forward_type, stage, WriteBack, rs_num
        ))
      return ForwardFromWb;
    else return NoForwarding;
  endfunction

  forwarding_unit DUT (.*);

  initial begin : verify_dut
    logic forwarding_temp_ex, forwarding_temp_mem;
    repeat (number_of_tests) begin
      forwarding_type_id = forwarding_type_t'($urandom() % forwarding_type_id.num());
      {forwarding_type_ex, forwarding_type_mem} = $urandom();
      {reg_we_mem, reg_we_wb, zicsr_ex} = $urandom();
      {rd_ex, rd_mem, rd_wb, rs1_id, rs2_id, rs1_ex, rs2_ex, rs2_mem} = {$urandom(), $urandom()};
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
          reg_we_mem,
          reg_we_wb,
          zicsr_ex
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
          reg_we_mem,
          reg_we_wb,
          zicsr_ex
      ));
      CHECK_RS1_EX :
      assert (forward_rs1_ex === get_forward_t(
          rs1_ex, 1'b0, rd_ex, rd_mem, rd_wb, forwarding_type_ex, Execute, reg_we_mem, reg_we_wb
      ));
      CHECK_RS2_EX :
      assert (forward_rs2_ex === get_forward_t(
          rs2_ex, 1'b1, rd_ex, rd_mem, rd_wb, forwarding_type_ex, Execute, reg_we_mem, reg_we_wb
      ));
      CHECK_RS2_MEM :
      assert (forward_rs2_mem === get_forward_t(
          rs2_mem, 1'b1, rd_ex, rd_mem, rd_wb, forwarding_type_mem, Memory, 1'b0, reg_we_wb
      ));
      #5;
    end
    $stop();
  end : verify_dut

endmodule
