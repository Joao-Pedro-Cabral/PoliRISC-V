
module hazard_unit_tb ();
  import macros_pkg::*;
  import hazard_unit_pkg::*;
  import branch_decoder_unit_pkg::*;

  int number_of_tests = 10000;

  // DUT Signals
  hazard_t hazard_type;
  rs_used_t rs_used;
  pc_src_t pc_src;
  logic interrupt;
  logic [4:0] rs1_id, rs2_id, rd_ex, rd_mem;
  logic reg_we_ex, reg_we_mem;
  logic mem_rd_en_ex, mem_rd_en_mem;
  logic store_id, rd_complete_ex;
  logic stall_if, stall_id, stall_ex, stall_mem, stall_wb;
  logic flush_id, flush_ex, flush_mem, flush_wb;
  logic flush_all;

  function automatic bit detect_data_hazard(input logic [4:0] rs, input logic [4:0] rd,
                                        input logic we, input logic en);
    return (rs === rd) && (rd !== 0) && we && en;
  endfunction

  function automatic void check_data_hazard(
      input logic [4:0] rs, input logic [4:0] rd_ex, input logic [4:0] rd_mem,
      input logic reg_we_ex, input logic reg_we_mem, input logic mem_rd_en_ex,
      input logic mem_rd_en_mem, input logic rd_complete_ex, input logic store_id,
      input hazard_t hazard_type, output logic stall_if, output logic stall_id,
      output logic flush_ex);
    stall_if = 1'b0;
    stall_id = 1'b0;
    flush_ex = 1'b0;
    unique case (hazard_type)
      HazardDecode: begin
        if (detect_data_hazard(rs, rd_ex, reg_we_ex, !rd_complete_ex) ||
            detect_data_hazard(rs, rd_mem, reg_we_mem, mem_rd_en_mem)) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex = 1'b1;
        end
      end
      HazardExecute: begin
        if (detect_data_hazard(rs, rd_ex, reg_we_ex, mem_rd_en_ex && !store_id)) begin
          stall_if = 1'b1;
          stall_id = 1'b1;
          flush_ex = 1'b1;
        end
      end
      default: begin  // NoHazard
      end
    endcase
  endfunction

  function automatic void check_control_hazard(input pc_src_t pc_src, input logic flush_all,
      input logic interrupt, output logic stall_if, output logic stall_id, output logic stall_ex,
      output logic stall_mem, output logic stall_wb, output logic flush_id, output logic flush_ex,
      output logic flush_mem, output logic flush_wb);
    stall_if = 1'b0;
    stall_id = 1'b0;
    stall_ex = 1'b0;
    stall_mem = 1'b0;
    stall_wb = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;
    flush_mem = 1'b0;
    flush_wb = 1'b0;
    if(flush_all) begin
      flush_id = 1'b1;
      flush_ex = 1'b1;
      flush_mem = 1'b1;
      flush_wb = 1'b1;
    end
    if (interrupt) begin
      flush_id = 1'b1;
      stall_ex = 1'b1;
      stall_mem = 1'b1;
      stall_wb = 1'b1;
    end
    if(pc_src !== PcPlus4) begin
      flush_id = 1'b1;
    end
  endfunction

  hazard_unit DUT (.*);

  initial begin : verify_dut
    logic stall1_if, stall2_if;
    logic stall1_id, stall2_id;
    logic flush1_ex, flush2_ex;
    logic stall3_if, stall3_id, stall3_ex, stall3_mem, stall3_wb;
    logic flush3_id, flush3_ex, flush3_mem, flush3_wb;
    repeat (number_of_tests) begin
      hazard_type = hazard_t'($urandom() % hazard_type.num());
      rs_used = rs_used_t'($urandom());
      pc_src = pc_src_t'($urandom());
      {rs1_id, rs2_id, rd_ex, rd_mem} = $urandom();
      {reg_we_ex, reg_we_mem} = $urandom();
      {mem_rd_en_ex, mem_rd_en_mem} = $urandom();
      {store_id, rd_complete_ex} = $urandom();
      flush_all = $urandom();
      interrupt = $urandom();
      #5;
      check_data_hazard(rs1_id, rd_ex, rd_mem, reg_we_ex, reg_we_mem, mem_rd_en_ex, mem_rd_en_mem,
                   rd_complete_ex, 1'b0, hazard_type, stall1_if, stall1_id, flush1_ex);
      check_data_hazard(rs2_id & {5{rs_used}}, rd_ex, rd_mem, reg_we_ex, reg_we_mem, mem_rd_en_ex,
                   mem_rd_en_mem, rd_complete_ex, store_id, hazard_type, stall2_if, stall2_id,
                   flush2_ex);
      check_control_hazard(pc_src, flush_all, interrupt, stall3_if, stall3_id, stall3_ex,
                   stall3_mem, stall3_wb, flush3_id, flush3_ex, flush3_mem, flush3_wb);
      CHECK_STALL_IF : assert (stall_if  === (stall1_if  || stall2_if  || stall3_if));
      CHECK_STALL_ID : assert (stall_id  === (stall1_id  || stall2_id  || stall3_id));
      CHECK_FLUSH_EX : assert (flush_ex  === (flush1_ex  || flush2_ex  || flush3_ex));
      CHECK_STALL_EX : assert (stall_ex  === stall3_ex);
      CHECK_STALL_MEM: assert (stall_mem === stall3_mem);
      CHECK_STALL_WB: assert (stall_wb === stall3_wb);
      CHECK_FLUSH_ID : assert (flush_id  === flush3_id);
      CHECK_FLUSH_MEM: assert (flush_mem === flush3_mem);
      CHECK_FLUSH_WB: assert (flush_wb === flush3_wb);
      #5;
    end
    $stop();
  end : verify_dut

endmodule
