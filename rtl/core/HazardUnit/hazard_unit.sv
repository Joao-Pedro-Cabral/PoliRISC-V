import hazard_unit_pkg::*;
import branch_decoder_unit_pkg::*;

module hazard_unit (
    input hazard_t hazard_type,
    input rs_used_t rs_used,
    input pc_src_t pc_src,
    input logic trap,
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
    output logic flush_id,
    output logic flush_ex
);

  logic flush_id_type, flush_id_pc, flush_id_trap;
  logic flush_ex_type, flush_ex_trap;

  assign flush_id_pc = (pc_src != PcPlus4);

  assign flush_id_trap = trap;
  assign flush_ex_trap = trap;

  always_comb begin : flushes_and_stalls_proc
    stall_if = 1'b0;
    stall_id = 1'b0;
    flush_id_type = 1'b0;
    flush_ex_type = 1'b0;

    unique case (hazard_type)
      NoHazard: begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id_type = 1'b0;
        flush_ex_type = 1'b0;
      end

      HazardDecode: begin
        if (rd_ex && ((rs_used && rs2_id == rd_ex) || rs1_id == rd_ex)
            && reg_we_ex && !rd_complete_ex) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex_type = 1'b1;
        end else if (rd_mem && ((rs_used && rs2_id == rd_mem) || rs1_id == rd_mem) && reg_we_mem
            && mem_rd_en_mem) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex_type = 1'b1;
        end
      end

      HazardExecute: begin
        if (rd_ex && ((!store_id && rs_used && rs2_id == rd_ex) || rs1_id == rd_ex) && reg_we_ex
            && mem_rd_en_ex) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex_type = 1'b1;
        end
      end

      default: begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id_type = 1'b0;
        flush_ex_type = 1'b0;
      end
    endcase

  end : flushes_and_stalls_proc

  assign flush_id = flush_id_type | flush_id_pc | flush_id_trap;
  assign flush_ex = flush_ex_type | flush_ex_trap;

endmodule
