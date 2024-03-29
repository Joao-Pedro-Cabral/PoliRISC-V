
module immediate_extender_tb ();
  import macros_pkg::*;
  import instruction_pkg::*;

  int number_of_tests = 10000;

  // portas do DUT
  instruction_t instruction;
  logic [63:0] immediate;

  // FIXME: tirar isso quando tivermos acesso ao randomize()
  function automatic opcode_t get_random_opcode();
    unique case($urandom()%13)
      0:  return UlaRType;
      1:  return UlaRWType;
      2:  return UlaIType;
      3:  return UlaIWType;
      4:  return LoadType;
      5:  return SType;
      6:  return BType;
      7:  return Lui;
      8:  return Auipc;
      9:  return Jal;
      10: return Jalr;
      11: return Fence;
      default: return SystemType;
    endcase
  endfunction

  function automatic logic [63:0] get_immediate(input instruction_t instruction);
    unique case(instruction.opcode)
      UlaIType, UlaIWType, LoadType, Jalr: return {{53{instruction[31]}}, instruction[30:20]};
      SType: return {{53{instruction[31]}}, instruction[30:25], instruction[11:7]};
      BType: return {{52{instruction[31]}}, instruction[7], instruction[30:25],
                    instruction[11:8], 1'b0};
      Lui, Auipc: return {{33{instruction[31]}}, instruction[30:12], 12'b0};
      Jal: return {{44{instruction[31]}}, instruction[19:12], instruction[20],
                    instruction[30:25], instruction[24:21], 1'b0};
      default: return 'x;
    endcase
  endfunction

  // instanciando o DUT
  immediate_extender #(
    .N(64)
  ) DUT (
      .instruction(instruction),
      .immediate  (immediate)
  );

  // initial para testar o DUT
  initial begin : verify_dut
    $display("SOT!");
    repeat(number_of_tests) begin
      instruction.opcode = get_random_opcode();
      instruction[31:7] = $urandom();
      #5;
      CHECK_IMMEDIATE: assert (immediate ==? get_immediate(instruction));
      #5;
    end
    $display("EOT!");
  end : verify_dut

endmodule
