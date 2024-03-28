import hazard_unit_pkg::*;

module hazard_unit (
    input hazard_t hazard_type,
    input logic rs_used,
    input logic [4:0] rs1_id,
    input logic [4:0] rs2_id,
    input logic [4:0] rd_ex,
    input logic [4:0] rd_mem,
    input logic reg_we_ex,
    input logic reg_we_mem,
    input logic mem_rd_en_ex,
    input logic mem_rd_en_mem,
    input logic zicsr_ex,
    input logic store_id,
    output logic stall_if,
    output logic stall_id,
    output logic flush_id,
    output logic flush_ex
);

  always_comb begin : flushes_and_stalls_proc
    stall_if = 1'b0;
    stall_id = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;

    unique case (hazard_type)
      NoHazard: begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id = 1'b0;
        flush_ex = 1'b0;
      end

      HazardDecode: begin
        if (rd_ex && ((rs_used && rs2_id == rd_ex) || rs1_id == rd_ex)
            && reg_we_ex && !zicsr_ex) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex = 1'b1;
        end else if (rd_mem && ((rs_used && rs2_id == rd_mem) || rs1_id == rd_mem) && reg_we_mem
        && mem_rd_en_mem) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex = 1'b1;
        end
      end

      HazardExecute: begin
        if (rd_ex && ((!store_id && rs_used && rs2_id == rd_ex) || rs1_id == rd_ex) && reg_we_ex
        && mem_rd_en_ex) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex = 1'b1;
        end
      end

      HazardException: begin
        flush_id = 1'b1;
        flush_ex = 1'b1;
      end

      default: begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id = 1'b0;
        flush_ex = 1'b0;
      end
    endcase

  end : flushes_and_stalls_proc


endmodule
