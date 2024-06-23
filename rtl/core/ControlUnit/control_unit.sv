
import instruction_pkg::*;
import alu_pkg::*;
import forwarding_unit_pkg::*;
import hazard_unit_pkg::*;
import branch_decoder_unit_pkg::*;
import csr_pkg::*;
import control_unit_pkg::*;

module control_unit #(
    parameter integer BYTE_NUM = 8
) (
    // Vindo do Fluxo de Dados
    input opcode_t opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input privilege_mode_t privilege_mode,

    // Sinais de Controle do Fluxo de Dados
    output reg alua_src,
    output reg alub_src,
    output reg aluy_src, // only used in RV64I
    output alu_op_t alu_op,
    output reg alupc_src,
    output wr_reg_t wr_reg_src,
    output reg wr_reg_en,
    output reg mem_rd_en,
    output reg mem_wr_en,
    output reg [BYTE_NUM-1:0] mem_byte_en,
    output reg mem_signed,
    output reg csr_imm,
    output csr_op_t csr_op,
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
    wr_reg_src   = WrAluY;
    wr_reg_en    = 1'b0;
    mem_wr_en    = 1'b0;
    mem_rd_en    = 1'b0;
    mem_byte_en  = 0;
    mem_signed = 1'b0;
    csr_imm      = 1'b0;
    csr_op       = CsrNoOp;
    hazard_type = NoHazard;
    rs_used = OnlyRs1;
    forwarding_type = NoForward;
    branch_type = NoBranch;
    cond_branch_type = Beq;

    unique case (opcode)  // synthesis parallel_case
      AluRType, AluRWType: begin
        aluy_src = opcode[3];
        alu_op = alu_op_t'({funct7[5], funct7[0], funct3});
        wr_reg_en = 1'b1;
        hazard_type = HazardExecute;
        rs_used = Rs1AndRs2;
        forwarding_type = ForwardExecute;
      end

      AluIType, AluIWType: begin
        alub_src = 1'b1;
        aluy_src = opcode[3];
        alu_op = alu_op_t'({funct7[5] & (funct3 == 3'b101), 1'b0, funct3});
        wr_reg_en = 1'b1;
        hazard_type = HazardExecute;
        forwarding_type = ForwardExecute;
      end

      LoadType: begin
        alub_src = 1'b1;
        wr_reg_src = WrRdData;
        wr_reg_en = 1'b1;
        mem_rd_en = 1'b1;
        mem_byte_en = byte_en;
        mem_signed = ~funct3[2];
        hazard_type = HazardExecute;
        forwarding_type = ForwardExecute;
      end

      SType: begin
        alub_src = 1'b1;
        mem_wr_en = 1'b1;
        mem_byte_en = byte_en;
        hazard_type = HazardExecute;
        rs_used = Rs1AndRs2;
        forwarding_type = ForwardExecuteMemory;
      end

      BType: begin
        hazard_type = HazardDecode;
        rs_used = Rs1AndRs2;
        branch_type = CondBranch;
        cond_branch_type = cond_branch_t'(funct3);
        forwarding_type = ForwardDecode;
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
        wr_reg_src = WrPcPlus4;
        wr_reg_en = 1'b1;
        branch_type = Jump;
      end

      Jalr: begin
        alupc_src = 1'b1;
        wr_reg_src = WrPcPlus4;
        wr_reg_en = 1'b1;
        branch_type = Jump;
        hazard_type = HazardDecode;
        forwarding_type = ForwardDecode;
      end

      Fence: begin // Conservative Fence: Stall
      end

      SystemType: begin
        csr_op = CsrIllegalInstruction;
        if (funct3 === 0) begin
          if (funct7 === 0) begin
            csr_op = CsrEcall;
          end else if((funct7 == 7'h18 && privilege_mode == Machine) ||
                      (funct7 == 7'h08 && (privilege_mode inside {Machine, Supervisor}))) begin
            csr_op = funct7[4] ? CsrMret : CsrSret;
          end
        end else if (funct3 !== 3'b100 && privilege_mode >= funct7[6:5]) begin
          wr_reg_en = 1'b1;
          wr_reg_src = WrCsrRdData;
          csr_imm = funct3[2];
          csr_op  = csr_op_t'(funct3[1:0]);
          hazard_type = HazardExecute;
          forwarding_type = ForwardExecute;
        end
      end

      default: begin
        csr_op = CsrIllegalInstruction;
      end
    endcase
  end

endmodule
