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

  function automatic bit forward(input logic reg_we, input logic [N-1:0] rd,
                                 input forwarding_t target_forwarding, input logic [N-1:0] rs,
                                 output forwarding_t forward_rs);
    if (valid_forwarding(reg_we, rs, rd)) begin
      forward_rs = target_forwarding;
      return 1'b1;
    end
    forward_rs = NoForwarding;
    return 1'b0;
  endfunction

  always_comb begin : forward_rsx_id_proc
    unique case (forwarding_type_id)

      NoForward: begin
        forward_rs1_id = NoForwarding;
        forward_rs2_id = NoForwarding;
      end

      ForwardExecute, ForwardExecuteMemory: begin
        void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_id, forward_rs1_id));
        void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_id, forward_rs2_id));
      end

      ForwardDecode: begin
        if (!forward(reg_we_ex, rd_ex, ForwardFromEx, rs1_id, forward_rs1_id)) begin
          if (!forward(reg_we_mem, rd_mem, ForwardFromMem, rs1_id, forward_rs1_id)) begin
            void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_id, forward_rs1_id));
          end
        end

        if (!forward(reg_we_ex, rd_ex, ForwardFromEx, rs2_id, forward_rs2_id)) begin
          if (!forward(reg_we_mem, rd_mem, ForwardFromMem, rs2_id, forward_rs2_id)) begin
            void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_id, forward_rs2_id));
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
    unique case (forwarding_type_ex)

      NoForward, ForwardDecode: begin
        forward_rs1_ex = NoForwarding;
        forward_rs2_ex = NoForwarding;
      end

      ForwardExecute, ForwardExecuteMemory: begin
        if (!forward(reg_we_mem, rd_mem, ForwardFromMem, rs1_ex, forward_rs1_ex)) begin
          void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs1_ex, forward_rs1_ex));
        end
        if (!forward(reg_we_mem, rd_mem, ForwardFromMem, rs2_ex, forward_rs2_ex)) begin
          void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_ex, forward_rs2_ex));
        end
      end

      default: begin
        forward_rs1_ex = NoForwarding;
        forward_rs2_ex = NoForwarding;
      end

    endcase
  end : forward_rsx_ex_proc

  always_comb begin : forward_rs2_mem_proc
    forwarding_src_bundle_t wb_bundle;
    unique case (forwarding_type_mem)

      NoForward, ForwardExecute, ForwardDecode: begin
        forward_rs2_mem = NoForwarding;
      end

      ForwardExecuteMemory: begin
        void'(forward(reg_we_wb, rd_wb, ForwardFromWb, rs2_mem, forward_rs2_ex));
      end

      default: begin
        forward_rs2_mem = NoForwarding;
      end

    endcase
  end : forward_rs2_mem_proc

endmodule
