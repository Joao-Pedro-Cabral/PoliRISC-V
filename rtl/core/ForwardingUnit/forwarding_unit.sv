import forwarding_unit_pkg::*;

module forwarding_unit (
    input forwarding_type_t forwarding_type_id,
    input forwarding_type_t forwarding_type_ex,
    input forwarding_type_t forwarding_type_mem,
    input logic reg_we_mem,
    input logic reg_we_wb,
    input logic zicsr_ex,
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
    output forwarding_t forward_rs2_mem
);

  forwarding_dst_bundle_t rs1_id_bundle;
  forwarding_dst_bundle_t rs2_id_bundle;
  always_comb begin : forward_rsx_id_proc
    forwarding_src_bundle_t ex_bundle;
    forwarding_src_bundle_t mem_bundle;
    forwarding_src_bundle_t wb_bundle;

    ex_bundle     = '{reg_we: zicsr_ex, rd: rd_ex, target_forwarding: ForwardFromEx};
    mem_bundle    = '{reg_we: reg_we_mem, rd: rd_mem, target_forwarding: ForwardFromMem};
    wb_bundle     = '{reg_we: reg_we_wb, rd: rd_wb, target_forwarding: ForwardFromWb};
    rs1_id_bundle = '{rs: rs1_id, forward_rs: NoForwarding};
    rs2_id_bundle = '{rs: rs2_id, forward_rs: NoForwarding};

    unique case (forwarding_type_id)

      NoType: begin
        rs1_id_bundle.forward_rs = NoForwarding;
        rs2_id_bundle.forward_rs = NoForwarding;
      end

      Type1, Type1_3: begin
        void'(forward(wb_bundle, rs1_id_bundle));
        void'(forward(wb_bundle, rs2_id_bundle));
      end

      Type2: begin
        if (!forward(ex_bundle, rs1_id_bundle)) begin
          if (!forward(mem_bundle, rs1_id_bundle)) begin
            void'(forward(wb_bundle, rs1_id_bundle));
          end
        end

        if (!forward(mem_bundle, rs2_id_bundle)) begin
          void'(forward(wb_bundle, rs2_id_bundle));
        end
      end

      default: begin
        rs1_id_bundle.forward_rs = NoForwarding;
        rs2_id_bundle.forward_rs = NoForwarding;
      end

    endcase
  end : forward_rsx_id_proc


  forwarding_dst_bundle_t rs1_ex_bundle;
  forwarding_dst_bundle_t rs2_ex_bundle;
  always_comb begin : forward_rsx_ex_proc
    forwarding_src_bundle_t mem_bundle;
    forwarding_src_bundle_t wb_bundle;

    mem_bundle    = '{reg_we: reg_we_mem, rd: rd_mem, target_forwarding: ForwardFromMem};
    wb_bundle     = '{reg_we: reg_we_wb, rd: rd_wb, target_forwarding: ForwardFromWb};
    rs1_ex_bundle = '{rs: rs1_ex, forward_rs: NoForwarding};
    rs2_ex_bundle = '{rs: rs2_ex, forward_rs: NoForwarding};

    unique case (forwarding_type_ex)

      NoType, Type2: begin
        rs1_ex_bundle.forward_rs = NoForwarding;
        rs2_ex_bundle.forward_rs = NoForwarding;
      end

      Type1, Type1_3: begin
        if (!forward(mem_bundle, rs1_ex_bundle)) begin
          void'(forward(wb_bundle, rs1_ex_bundle));
        end
        if (!forward(mem_bundle, rs2_ex_bundle)) begin
          void'(forward(wb_bundle, rs2_ex_bundle));
        end
      end

      default: begin
        rs1_ex_bundle.forward_rs = NoForwarding;
        rs2_ex_bundle.forward_rs = NoForwarding;
      end

    endcase
  end : forward_rsx_ex_proc

  forwarding_dst_bundle_t rs2_mem_bundle;
  always_comb begin : forward_rs2_mem_proc
    forwarding_src_bundle_t wb_bundle;

    wb_bundle      = '{reg_we: reg_we_wb, rd: rd_wb, target_forwarding: ForwardFromWb};
    rs2_mem_bundle = '{rs: rs2_mem, forward_rs: NoForwarding};

    unique case (forwarding_type_mem)

      NoType, Type1, Type2: begin
        rs2_mem_bundle.forward_rs = NoForwarding;
      end

      Type1_3: begin
        void'(forward(wb_bundle, rs2_mem_bundle));
      end

      default: begin
        rs2_mem_bundle.forward_rs = NoForwarding;
      end

    endcase
  end : forward_rs2_mem_proc

  assign forward_rs1_id  = rs1_id_bundle.forward_rs;
  assign forward_rs2_id  = rs2_id_bundle.forward_rs;
  assign forward_rs1_ex  = rs1_ex_bundle.forward_rs;
  assign forward_rs2_ex  = rs2_ex_bundle.forward_rs;
  assign forward_rs2_mem = rs2_mem_bundle.forward_rs;

endmodule
