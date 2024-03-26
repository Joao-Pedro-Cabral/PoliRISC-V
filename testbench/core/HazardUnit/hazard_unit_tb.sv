
module hazard_unit_tb ();
  import macros_pkg::*;
  import hazard_unit_pkg::*;

  int number_of_tests = 10000;

  // DUT Signals
  hazard_t hazard_type;
  logic rs_used;
  logic [4:0] rs1_id, rs2_id, rd_ex, rd_mem;
  logic reg_we_ex, reg_we_mem;
  logic mem_rd_en_ex, mem_rd_en_mem;
  logic store_id, zicsr_ex;
  logic stall_if, stall_id;
  logic flush_id, flush_ex;

  function automatic bit detect_hazard(input logic [4:0] rs, input logic [4:0] rd, input logic we,
                                       input logic enable_detect);
    return (rs === rd) && (rd !== 0) && we && enable_detect;
  endfunction

  function automatic void check_hazard(
      input logic [4:0] rs, input logic [4:0] rd_ex, input logic [4:0] rd_mem,
      input logic reg_we_ex, input logic reg_we_mem, input logic mem_rd_en_ex,
      input logic mem_rd_en_mem, input logic zicsr_ex, input logic store_id,
      input hazard_t hazard_type, output logic stall_id, output logic stall_if,
      output logic flush_id, output logic flush_ex);
    stall_id = 1'b0;
    stall_if = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;
    unique case (hazard_type)
      HazardDecode: begin
        if (detect_hazard(
                rs, rd_ex, reg_we_ex, !zicsr_ex
            ) || detect_hazard(
                rs, rd_mem, reg_we_mem, mem_rd_en_mem
            )) begin
          stall_id = 1'b1;
          stall_if = 1'b1;
          flush_ex = 1'b1;
        end
      end
      HazardExecute: begin
        if (detect_hazard(rs, rd_ex, reg_we_ex, mem_rd_en_ex && !store_id)) begin
          stall_id = 1'b1;
          stall_if = 1'b1;
          flush_ex = 1'b1;
        end
      end
      HazardException: begin
        flush_id = 1'b1;
        flush_ex = 1'b1;
      end
      default: begin  // NoHazard
      end
    endcase
  endfunction

  hazard_unit DUT (.*);

  initial begin : verify_dut
    logic stall1_if, stall2_if;
    logic stall1_id, stall2_id;
    logic flush1_id, flush2_id;
    logic flush1_ex, flush2_ex;
    repeat (number_of_tests) begin
      hazard_type = hazard_t'($urandom() % hazard_type.num());
      rs_used = $urandom();
      {rs1_id, rs2_id, rd_ex, rd_mem} = $urandom();
      {reg_we_ex, reg_we_mem} = $urandom();
      {mem_rd_en_ex, mem_rd_en_mem} = $urandom();
      {store_id, zicsr_ex} = $urandom();
      {stall_id, stall_if} = $urandom();
      {flush_id, flush_ex} = $urandom();
      #5;
      check_hazard(rs1_id, rd_ex, rd_mem, reg_we_ex, reg_we_mem, mem_rd_en_ex, mem_rd_en_mem,
                   zicsr_ex, 1'b0, hazard_type, stall1_id, stall1_if, flush1_id, flush1_ex);
      check_hazard(rs2_id, rd_ex, rd_mem, reg_we_ex, reg_we_mem, mem_rd_en_ex, mem_rd_en_mem, 1'b0,
                   zicsr_ex, hazard_type, stall2_id, stall2_if, flush2_id, flush2_ex);
      CHECK_STALL_IF : assert (stall_if === (stall1_if || stall2_if));
      CHECK_STALL_ID : assert (stall_id === (stall1_id || stall2_id));
      CHECK_FLUSH_ID : assert (flush_id === (flush1_id || flush2_id));
      CHECK_FLUSH_EX : assert (flush_ex === (flush1_ex || flush2_ex));
    end
    $stop();
  end : verify_dut

endmodule
