import forwarding_unit_pkg::*;

module forwarding_unit #(
    parameter integer N = 5
) (
    input forwarding_type_t forwarding_type_id,
    input forwarding_type_t forwarding_type_ex,
    input forwarding_type_t forwarding_type_mem,
    input logic reg_we_ex,
    input logic reg_we_mem,
    input logic reg_we_wb,
    input logic [N-1:0] rd_ex,
    input logic [N-1:0] rd_mem,
    input logic [N-1:0] rd_wb,
    input logic [N-1:0] rs1_id,
    input logic [N-1:0] rs2_id,
    input logic [N-1:0] rs1_ex,
    input logic [N-1:0] rs2_ex,
    input logic [N-1:0] rs2_mem,
    output forwarding_t forward_rs1_id,
    output forwarding_t forward_rs2_id,
    output forwarding_t forward_rs1_ex,
    output forwarding_t forward_rs2_ex,
    output forwarding_t forward_rs2_mem
);

  function automatic bit valid_forwarding(input logic reg_we, input logic [N-1:0] rs,
                                          input logic [N-1:0] rd);
    return reg_we && rs && rd == rs;
  endfunction

  function automatic forwarding_t forward(input logic reg_we, input logic [N-1:0] rd,
                                          input forwarding_t target_forwarding,
                                          input logic [N-1:0] rs);
    if (valid_forwarding(reg_we, rs, rd)) begin
      return target_forwarding;
    end
    return NoForwarding;
  endfunction

  always_comb begin : forward_rsx_id_proc
    forward_rs1_id = NoForwarding;
    forward_rs2_id = NoForwarding;
    unique case (forwarding_type_id)

      NoForward: begin
        forward_rs1_id = NoForwarding;
        forward_rs2_id = NoForwarding;
      end

      ForwardExecute, ForwardExecuteMemory: begin
        forward_rs1_id = forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_id);
        forward_rs2_id = forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_id);
      end

      ForwardDecode: begin
        forward_rs1_id = forward(reg_we_ex, rd_ex, ForwardFromEx, rs1_id);
        if (forward_rs1_id == NoForwarding) begin
          forward_rs1_id = forward(reg_we_mem, rd_mem, ForwardFromMem, rs1_id);
          if (forward_rs1_id == NoForwarding) begin
            forward_rs1_id = forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_id);
          end
        end

        forward_rs2_id = forward(reg_we_ex, rd_ex, ForwardFromEx, rs2_id);
        if (forward_rs2_id == NoForwarding) begin
          forward_rs2_id = forward(reg_we_mem, rd_mem, ForwardFromMem, rs2_id);
          if (forward_rs2_id == NoForwarding) begin
            forward_rs2_id = forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_id);
          end
        end
      end

      default: begin
        forward_rs1_id = NoForwarding;
        forward_rs2_id = NoForwarding;
      end

    endcase
  end : forward_rsx_id_proc

  always_comb begin : forward_rsx_ex_proc
    forward_rs1_ex = NoForwarding;
    forward_rs2_ex = NoForwarding;
    unique case (forwarding_type_ex)

      NoForward, ForwardDecode: begin
        forward_rs1_ex = NoForwarding;
        forward_rs2_ex = NoForwarding;
      end

      ForwardExecute, ForwardExecuteMemory: begin
        forward_rs1_ex = forward(reg_we_mem, rd_mem, ForwardFromMem, rs1_ex);
        if (forward_rs1_ex == NoForwarding) begin
          forward_rs1_ex = forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_ex);
        end
        forward_rs2_ex = forward(reg_we_mem, rd_mem, ForwardFromMem, rs2_ex);
        if (forward_rs2_ex == NoForwarding) begin
          forward_rs2_ex = forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_ex);
        end
      end

      default: begin
        forward_rs1_ex = NoForwarding;
        forward_rs2_ex = NoForwarding;
      end

    endcase
  end : forward_rsx_ex_proc

  always_comb begin : forward_rs2_mem_proc
    forward_rs2_mem = NoForwarding;
    unique case (forwarding_type_mem)

      NoForward, ForwardExecute, ForwardDecode: begin
        forward_rs2_mem = NoForwarding;
      end

      ForwardExecuteMemory: begin
        forward_rs2_mem = forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_mem);
      end

      default: begin
        forward_rs2_mem = NoForwarding;
      end

    endcase
  end : forward_rs2_mem_proc

endmodule
