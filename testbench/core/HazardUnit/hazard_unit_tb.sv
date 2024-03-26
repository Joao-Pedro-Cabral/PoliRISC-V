
module hazard_unit_tb();
  import macros_pkg::*;
  import hazard_unit_pkg::*;

  int number_of_tests = 10000;

  // DUT Signals
  hazard_t hazard_type;
  logic rs_used;
  logic [4:0] rs1_id, rs2_id, rd_ex, rd_mem;
  logic reg_we_ex, reg_we_mem;
  logic mem_rd_en_ex, mem_rd_en_mem;
  logic zicsr_ex;
  logic stall_if, stall_id;
  logic flush_id, flush_ex;

  function automatic bit detect_hazard(input logic [4:0] rs, input logic [4:0] rd,
                                       input logic enable_detect);
    return (rs === rd) && (rd !== 0) && enable_detect;
  endfunction

  function automatic void check_hazard(input logic [4:0] rs, input logic [4:0] rd_ex,
                                     input logic [4:0] rd_mem, input logic reg_we_ex,
                                     input logic reg_we_mem, input logic mem_rd_en_ex,
                                     input logic mem_rd_en_mem, input logic zicsr_ex,
                                     input hazard_t hazard_type, output logic stall_id,
                                     output logic stall_if, output logic flush_id,
                                     output logic flush_ex);
    stall_id = 1'b0;
    stall_if = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;
    unique case (hazard_type)
      NoHazard:
      HazardDecode: begin
        
      end
      default: begin
      end
    endcase
  endfunction

  hazard_unit DUT (.*);

endmodule
