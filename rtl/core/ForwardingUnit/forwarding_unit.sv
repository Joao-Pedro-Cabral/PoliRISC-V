import forwarding_unit_pkg::*;

module forwarding_unit (
    input forwarding_type_t forwarding_type_id,
    input forwarding_type_t forwarding_type_ex,
    input forwarding_type_t forwarding_type_mem,
    input logic reg_we_mem,
    input logic reg_we_wb,
    input logic zicsr_ex,
    input logic zicsr_mem,
    input logic [4:0] rd_ex,
    input logic [4:0] rd_mem,
    input logic [4:0] rd_wb,
    input logic [4:0] rs1_id,
    input logic [4:0] rs2_id,
    input logic [4:0] rs1_ex,
    input logic [4:0] rs2_ex,
    input logic [4:0] rs2_mem,
    output forwarding_t forward_rs1_id,
    output forwarding_t forward_rs2_id,
    output forwarding_t forward_rs1_ex,
    output forwarding_t forward_rs2_ex,
    output forwarding_t forward_rs1_mem,
    output forwarding_t forward_rs2_mem
);

  always_comb begin : forward_rsx_id_proc
    forward_rs1_id = NoForwarding;
    forward_rs2_id = NoForwarding;
    unique case (forwarding_type_id)
      NoType: begin
        forward_rs1_id = NoForwarding;
        forward_rs1_id = NoForwarding;
      end

      Type1: begin
        forward(reg_we_wb, rs1_id, rd_wb, ForwardFromWb, forward_rs1_id);
        forward(reg_we_wb, rs2_id, rd_wb, ForwardFromWb, forward_rs2_id);
      end

      Type2: begin
        forward(zicsr_ex, rs1_ex, rd_ex, ForwardFromEx, forward_rs1_id);
        forward(zicsr_ex, rs2_ex, rd_ex, ForwardFromEx, forward_rs2_id);
      end

      Type1_3: begin
      end

      default: begin
        forward_rs1_id = NoForwarding;
      end
    endcase
  end : forward_rsx_id_proc

endmodule
