
import instruction_pkg::*;
import alu_pkg::*;
import forwarding_unit_pkg::*;
import hazard_unit_pkg::*;
import branch_decoder_unit_pkg::*;
import csr_pkg::*;

module control_unit #(
    parameter integer BYTE_NUM = 8
) (
    // Vindo do Fluxo de Dados
    input opcode_t opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input privilege_mode_t privilege_mode,
    input wire csr_addr_invalid,

    // Sinais de Controle do Fluxo de Dados
    output reg alua_src,
    output reg alub_src,
    output reg aluy_src, // only used in RV64I
    output alu_op_t alu_op,
    output reg alupc_src,
    output reg [1:0] wr_reg_src,
    output reg wr_reg_en,
    output reg mem_rd_en,
    output reg mem_wr_en,
    output reg [BYTE_NUM-1:0] mem_byte_en,
    output reg mem_unsigned,
    output reg csr_imm,
    output reg [1:0] csr_op,
    output reg csr_wr_en,
    output reg mret,
    output reg sret,
    output reg illegal_instruction,
    output reg ecall,
    output hazard_t hazard_type,
    output rs_used_t rs_used,
    output forwarding_type_t forwarding_type,
    output branch_t branch_type,
    output cond_branch_t cond_branch_type
);

  // uso sempre 8 bits aqui -> truncamento automático na atribuição do always
  wire [BYTE_NUM-1:0] byte_en = funct3[1]==0 ?
        (funct3[0]==0 ? 'h1 : 'h3) : (funct3[0]==0 ? 'hF : 'hFF);

  // máquina de estados principal
  always_comb begin
    alua_src     = 1'b0;
    alub_src     = 1'b0;
    aluy_src     = 1'b0;
    alu_op       = Add;
    alupc_src    = 1'b0;
    wr_reg_src   = 2'b00;
    wr_reg_en    = 1'b0;
    mem_wr_en    = 1'b0;
    mem_rd_en    = 1'b0;
    mem_byte_en  = 0;
    mem_unsigned = 1'b0;
    csr_wr_en    = 1'b0;
    csr_imm      = 1'b0;
    csr_op       = 2'b00;
    mret         = 1'b0;
    sret         = 1'b0;
    illegal_instruction = 1'b0;
    ecall        = 1'b0;
    hazard_type = NoHazard;
    rs_used = OnlyRs1;
    forwarding_type = NoType;
    branch_type = NoBranch;
    cond_branch_type = Beq;

    unique case (opcode)  // synthesis parallel_case
      AluRType, AluRWType: begin
        aluy_src = opcode[3];
        alu_op = alu_op_t'({funct7[5], funct7[0], funct3});
        wr_reg_en = 1'b1;
        hazard_type = HazardExecute;
        rs_used = Rs1AndRs2;
        forwarding_type = Type1;
      end

      AluIType, AluIWType: begin
        alub_src = 1'b1;
        aluy_src = opcode[3];
        alu_op = alu_op_t'({funct7[5] & (funct3 == 3'b101), 1'b0, funct3});
        wr_reg_en = 1'b1;
        hazard_type = HazardExecute;
        forwarding_type = Type1;
      end

      LoadType: begin
        alub_src = 1'b1;
        wr_reg_src = 2'b10;
        wr_reg_en = 1'b1;
        mem_rd_en = 1'b1;
        mem_byte_en = byte_en;
        mem_unsigned = funct3[2];
        hazard_type = HazardExecute;
        forwarding_type = Type1;
      end

      SType: begin
        alub_src = 1'b1;
        mem_wr_en = 1'b1;
        mem_byte_en = byte_en;
        hazard_type = HazardExecute;
        rs_used = Rs1AndRs2;
        forwarding_type = Type1_3;
      end

      BType: begin
        hazard_type = HazardDecode;
        rs_used = Rs1AndRs2;
        branch_type = CondBranch;
        cond_branch_type = cond_branch_t'(funct3);
        forwarding_type = Type2;
      end

      Lui: begin
        alub_src = 1'b1;
        aluy_src = 1'b1;
        wr_reg_en = 1'b1;
      end

      Auipc: begin
        alua_src = 1'b1;
        alub_src = 1'b1;
        wr_reg_en = 1'b1;
      end

      Jal: begin
        wr_reg_src = 2'b11;
        wr_reg_en = 1'b1;
        branch_type = Jump;
      end

      Jalr: begin
        alupc_src = 1'b1;
        wr_reg_src = 2'b11;
        wr_reg_en = 1'b1;
        branch_type = Jump;
        hazard_type = HazardDecode;
        forwarding_type = Type2;
      end

      Fence: begin // Conservative Fence: Stall
      end

      SystemType: begin
        illegal_instruction = 1'b1;
        hazard_type = HazardException;
        if (funct3 === 0) begin
          if (funct7 === 0) begin
            ecall = 1'b1;
            illegal_instruction = 1'b0;
          end else if((funct7 == 7'h18 && privilege_mode == Machine) ||
                      (funct7 == 7'h08 && (privilege_mode inside {Machine, Supervisor}))) begin
            mret = funct7[4];
            sret = ~funct7[4];
            branch_type = funct7[4] ? Mret : Sret;
            illegal_instruction = 1'b0;
            hazard_type = NoHazard;
          end
        end else if (funct3 !== 3'b100 && privilege_mode >= funct7[6:5]) begin
          wr_reg_en = 1'b1;
          wr_reg_src = 2'b01;
          // não significa que algum CSR será escrito
          csr_wr_en = 1'b1;
          csr_imm = funct3[2];
          csr_op  = funct3[1:0];
          illegal_instruction = csr_addr_invalid;
          hazard_type = csr_addr_invalid ? HazardException :
                        (funct3[2] ? NoHazard : HazardDecode);
          forwarding_type = funct3[2] ? NoType : Type2;
        end
      end

      default: begin
        illegal_instruction = 1'b1;
        hazard_type = HazardException;
      end
    endcase
  end

endmodule
