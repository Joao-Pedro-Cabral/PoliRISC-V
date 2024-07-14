import hazard_unit_pkg::*;
import branch_decoder_unit_pkg::*;

module hazard_unit (
    input hazard_t hazard_type,
    input rs_used_t rs_used,
    input pc_src_t pc_src,
    input logic interrupt,
    input logic flush_all,
    input logic [4:0] rs1_id,
    input logic [4:0] rs2_id,
    input logic [4:0] rd_ex,
    input logic [4:0] rd_mem,
    input logic reg_we_ex,
    input logic reg_we_mem,
    input logic mem_rd_en_ex,
    input logic mem_rd_en_mem,
    input logic rd_complete_ex,
    input logic store_id,
    output logic stall_if,
    output logic stall_id,
    output logic stall_ex,
    output logic stall_mem,
    output logic stall_wb,
    output logic flush_id,
    output logic flush_ex,
    output logic flush_mem,
    output logic flush_wb
);

  logic stall_if_type, stall_id_type;

  logic flush_id_pc;
  logic flush_ex_type;

  assign flush_id_pc = (pc_src != PcPlus4);

  always_comb begin : flushes_and_stalls_proc
    stall_if_type = 1'b0;
    stall_id_type = 1'b0;
    flush_ex_type = 1'b0;

    unique case (hazard_type)
      HazardDecode: begin
        if (rd_ex && ((rs_used && rs2_id == rd_ex) || rs1_id == rd_ex)
            && reg_we_ex && !rd_complete_ex) begin
          stall_if_type = 1'b1;
          stall_id_type = 1'b1;
          flush_ex_type = 1'b1;
        end else if (rd_mem && ((rs_used && rs2_id == rd_mem) || rs1_id == rd_mem) && reg_we_mem
            && mem_rd_en_mem) begin
          stall_if_type = 1'b1;
          stall_id_type = 1'b1;
          flush_ex_type = 1'b1;
        end
      end

      HazardExecute: begin
        if (rd_ex && ((!store_id && rs_used && rs2_id == rd_ex) || rs1_id == rd_ex) && reg_we_ex
            && mem_rd_en_ex) begin
          stall_if_type = 1'b1;
          stall_id_type = 1'b1;
          flush_ex_type = 1'b1;
        end
      end

      default: begin // No Hazard
      end
    endcase

  end : flushes_and_stalls_proc

  assign flush_id = flush_id_pc | flush_all | interrupt;
  assign flush_ex = flush_ex_type | flush_all;
  assign flush_mem = flush_all;
  assign flush_wb = flush_all;

  assign stall_if = stall_if_type;
  assign stall_id = stall_id_type;
  assign stall_ex = interrupt;
  assign stall_mem = interrupt;
  assign stall_wb = interrupt;

endmodule
