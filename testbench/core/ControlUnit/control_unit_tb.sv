
module control_unit_tb ();
  import instruction_pkg::*;
  import alu_pkg::*;
  import forwarding_unit_pkg::*;
  import hazard_unit_pkg::*;
  import branch_decoder_unit_pkg::*;
  import macros_pkg::*;
  import extensions_pkg::*;
  import csr_pkg::*;

  // Parameters
  localparam integer Line = (DataSize == 64) ? 72 : 55;
  localparam integer Column = (DataSize == 64) ? 57 : 53;
  localparam integer NumberOfTests = 100000;

  // Data Types
  typedef struct packed {
    logic alua_src;
    logic alub_src;
    logic aluy_src; // only used in RV64I
    logic [4:0] alu_op;
    logic alupc_src;
    logic [1:0] wr_reg_src;
    logic wr_reg_en;
    logic mem_wr_en;
    logic mem_rd_en;
    logic [ByteNum-1:0] mem_byte_en;
    logic mem_signed;
    logic csr_imm;
    logic [2:0] csr_op;
    logic ecall;
    logic [1:0] hazard_type;
    logic rs_used;
    logic [1:0] forwarding_type;
    logic [2:0] branch_type;
    logic [2:0] cond_branch_type;
    logic illegal_instruction;
  } control_unit_output_t;

  typedef struct packed {
    opcode_t opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    control_unit_output_t control_unit_output;
  } lut_line_t;

  // Functions
  function automatic lut_line_t find_instruction(
    input logic [6:0] opcode, input logic [2:0] funct3,
    input logic [6:0] funct7, const ref lut_line_t [Line-1:0] lut);
    foreach (lut[i]) begin
      if(lut[i].opcode === opcode) begin
        unique case (opcode)
          AluRType, AluRWType: begin
            if(funct3 === lut[i].funct3 && funct7 ==? lut[i].funct7)
              return lut[i];
          end
          AluIType, AluIWType, LoadType, SType, BType, Jalr, Fence, SystemType: begin
            if(funct3 === lut[i].funct3) begin
              // SRLI e SRAI: funct7
              if(opcode inside {AluIType, AluIWType} && funct3 === 3'b101) begin
                if(funct7 ==? lut[i].funct7) return lut[i];
              end else if(opcode === SystemType) begin
                if(funct3 === 3'b000 && funct7 === lut[i].funct7) begin // ECALL, MRET, SRET
                    return lut[i];
                end else if(funct3 !=? 3'b?00) // ZICSR
                  return lut[i];
              end else begin
                return lut[i];
              end
            end
          end
          Lui, Auipc, Jal: return lut[i];
          default: return 0; // illegal instruction
        endcase
      end
    end
    return 0;
  endfunction

  function automatic control_unit_output_t check_exception(
    input opcode_t opcode, input logic [2:0] funct3,
    input logic [6:0] funct7, input privilege_mode_t privilege_mode,
    input logic csr_addr_invalid, input control_unit_output_t expected_output);
    control_unit_output_t new_expected_output;
    begin
      new_expected_output = expected_output;
      if(opcode === SystemType) begin
        // MRET, SRET
        if(funct3 === 3'b000 && funct7 ==? 7'b00?1000 && (funct7[4:3] > privilege_mode)) begin
          new_expected_output = 0;
          new_expected_output.illegal_instruction = 1'b1;
          new_expected_output.hazard_type = HazardException;
        end else if(funct3 !=? 3'b?00 && funct7[6:5] > privilege_mode) begin
          new_expected_output = 0;
          new_expected_output.illegal_instruction = 1'b1;
          new_expected_output.hazard_type = HazardException;
        end else if(funct3 !=? 3'b?00 && csr_addr_invalid) begin
          new_expected_output = expected_output;
          new_expected_output.illegal_instruction = 1'b1;
          new_expected_output.hazard_type = HazardException;
        end
      end else if(opcode === 0) begin
        new_expected_output = 0;
        new_expected_output.illegal_instruction = 1'b1;
        new_expected_output.hazard_type = HazardException;
      end
      return new_expected_output;
    end
  endfunction

  // Variables and Nets
  // DUT Signals
  opcode_t opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  privilege_mode_t privilege_mode;
  logic csr_addr_invalid;
  lut_line_t expected_output;
  control_unit_output_t dut_output;
  // Auxiliaries
  logic [Column-1:0] lut_unpacked [Line-1:0];
  lut_line_t [Line-1:0] lut;

  // DUT
  control_unit #(
    .BYTE_NUM(ByteNum)
  ) DUT (
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .privilege_mode(privilege_mode),
    .csr_addr_invalid(csr_addr_invalid),
    .alua_src(dut_output.alua_src),
    .alub_src(dut_output.alub_src),
    .aluy_src(dut_output.aluy_src),
    .alu_op(dut_output.alu_op),
    .alupc_src(dut_output.alupc_src),
    .wr_reg_src(dut_output.wr_reg_src),
    .wr_reg_en(dut_output.wr_reg_en),
    .mem_rd_en(dut_output.mem_rd_en),
    .mem_wr_en(dut_output.mem_wr_en),
    .mem_byte_en(dut_output.mem_byte_en),
    .mem_signed(dut_output.mem_signed),
    .csr_imm(dut_output.csr_imm),
    .csr_op(dut_output.csr_op),
    .illegal_instruction(dut_output.illegal_instruction),
    .ecall(dut_output.ecall),
    .hazard_type(dut_output.hazard_type),
    .rs_used(dut_output.rs_used),
    .forwarding_type(dut_output.forwarding_type),
    .branch_type(dut_output.branch_type),
    .cond_branch_type(dut_output.cond_branch_type)
  );

  initial begin : init_verify_dut

    if(DataSize == 64)
      $readmemb("./MIFs/core/core/RV64I.mif", lut_unpacked);
    else
      $readmemb("./MIFs/core/core/RV32I.mif", lut_unpacked);
    $display("SOT!");

    foreach (lut_unpacked[i]) begin: init_lut
      lut[i].opcode = opcode_t'(lut_unpacked[i][Column-1:Column-7]);
      lut[i].funct3 = lut_unpacked[i][Column-8:Column-10];
      lut[i].funct7 = lut_unpacked[i][Column-11:Column-17];
      lut[i].control_unit_output = lut_unpacked[i][Column-18:0];
    end : init_lut

    repeat(NumberOfTests) begin
      opcode = gen_random_opcode(DataSize == 64);
      funct3 = gen_random_funct3(opcode, DataSize == 64);
      funct7 = gen_random_funct7(opcode, funct3, DataSize == 64);
      privilege_mode = gen_random_privilege_mode();
      csr_addr_invalid = $urandom();
      expected_output = find_instruction(opcode, funct3, funct7, lut);
      #3;
      expected_output.control_unit_output = check_exception(opcode, funct3, funct7, privilege_mode,
                                            csr_addr_invalid, expected_output.control_unit_output);
      #2;
      CHECK_OUTPUT: assert (dut_output == expected_output.control_unit_output);
      #5;
    end
    $display("EOT!");
  end : init_verify_dut

endmodule
