
import instruction_pkg::*;

module immediate_extender #(
    parameter integer N = 32  // N == 32 or N == 64
) (
    input instruction_t instruction,
    output logic [N-1:0] immediate
);

  logic signed [31:0] imm;

  always_comb begin : gen_immediate
    imm = 0;
    unique case (instruction.opcode)
      AluIType, AluIWType, LoadType, Jalr: imm = $signed(instruction.fields.i_type.imm);  // I-Type
      SType: imm = $signed({instruction.fields.s_type.imm2, instruction.fields.s_type.imm1});
      BType:
      imm = $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0});
      Lui, Auipc: imm = $signed({instruction.fields.u_type.imm, 12'b0});  // U-Type
      Jal:
      imm = $signed({instruction[31], instruction[19:12], instruction[20], instruction[30:21],
                     1'b0});  // J-Type
      default: imm = 'x;  // Don't care
    endcase
  end

  assign immediate = imm;
endmodule
