
package instruction_pkg;

  typedef enum logic [6:0] {
    AluRType = 7'b0110011,
    AluRWType = 7'b0111011,
    AluIType = 7'b0010011,
    AluIWType = 7'b0011011,
    LoadType = 7'b0000011,
    SType = 7'b0100011,
    BType = 7'b1100011,
    Lui = 7'b0110111,
    Auipc = 7'b0010111,
    Jal = 7'b1101111,
    Jalr = 7'b1100111,
    Fence = 7'b0001111,
    SystemType = 7'b1110011
  } opcode_t;

  typedef struct packed {
    logic [6:0] funct7;
    logic [4:0] rs2;
    logic [4:0] rs1;
    logic [2:0] funct3;
    logic [4:0] rd;
  } r_type_t;

  typedef struct packed {
    logic [11:0] imm;
    logic [4:0]  rs1;
    logic [2:0]  funct3;
    logic [4:0]  rd;
  } i_type_t;

  typedef struct packed {
    logic [6:0] imm2;
    logic [4:0] rs2;
    logic [4:0] rs1;
    logic [2:0] funct3;
    logic [4:0] imm1;
  } s_type_t;

  typedef struct packed {
    logic [6:0] imm2;
    logic [4:0] rs2;
    logic [4:0] rs1;
    logic [2:0] funct3;
    logic [4:0] imm1;
  } b_type_t;

  typedef struct packed {
    logic [19:0] imm;
    logic [4:0]  rd;
  } u_type_t;

  typedef struct packed {
    logic [19:0] imm;
    logic [4:0]  rd;
  } j_type_t;

  typedef union packed {
    r_type_t r_type;
    i_type_t i_type;
    s_type_t s_type;
    b_type_t b_type;
    u_type_t u_type;
    j_type_t j_type;
  } fields_t;

  typedef struct packed {
    fields_t fields;
    opcode_t opcode;
  } instruction_t;

  // FIXME: tirar isso quando tivermos acesso ao randomize()
  function automatic opcode_t gen_random_opcode(input logic rv64i);
    unique case(rv64i ? $urandom()%13 : $urandom()%11)
      0:  return AluRType;
      1:  return AluIType;
      2:  return LoadType;
      3:  return SType;
      4:  return BType;
      5:  return Lui;
      6:  return Auipc;
      7:  return Jal;
      8:  return Jalr;
      9:  return Fence;
      10: return SystemType;
      11: return AluRWType; //only RV64I
      default:  return AluIWType; // only RV64I
    endcase
  endfunction

  // FIXME: tirar isso quando tivermos acesso ao randomize()
  function automatic logic [2:0] gen_random_funct3(input opcode_t opcode, input logic rv64i);
    unique case(opcode)
      AluRType, AluIType, Lui, Auipc, Jal: return $urandom();
      LoadType: begin
        if(rv64i) begin
          return ($urandom()%2) ? (4 + $urandom()%3) : ($urandom()%4);
        end else begin
          return ($urandom()%2) ? (4 + $urandom()%2) : ($urandom()%3);
        end
      end
      SType: begin
        return rv64i ? ($urandom()%4) : ($urandom()%3);
      end
      BType: begin
        unique case ($urandom()%6)
          0: return 3'b000;
          1: return 3'b001;
          2: return 3'b100;
          3: return 3'b101;
          4: return 3'b110;
          default: return 3'b111;
        endcase
      end
      Jalr, Fence: return 0;
      AluIWType: begin // It's assumed that rv64i == 1
        unique case($urandom()%3)
          0: return 3'b000;
          1: return 3'b001;
          default: return 3'b101;
        endcase
      end
      AluRWType: begin // It's assumed that rv64i == 1
        unique case($urandom()%6)
          0: return 3'b000;
          1: return 3'b001;
          2: return 3'b100;
          3: return 3'b101;
          4: return 3'b110;
          default: return 3'b111;
        endcase
      end
      default: begin // SystemType
        unique case ($urandom()%24) // Equal prob between Ecall, Sret, Mret and Zicsr
          0: return 3'b001;
          1: return 3'b010;
          2: return 3'b011;
          3: return 3'b101;
          4: return 3'b110;
          5: return 3'b111;
          default: return 3'b000;
        endcase
      end
    endcase
  endfunction

  // FIXME: tirar isso quando tivermos acesso ao randomize()
  function automatic logic [6:0] gen_random_funct7(input opcode_t opcode, input logic [2:0] funct3,
                                                   input logic rv64i);
    unique case(opcode)
      LoadType, SType, BType, Lui, Auipc, Jal, Jalr, Fence: return $urandom();
      AluRType: begin
        return (($urandom()%2) ? 7'h01 : ((funct3 === 3'b000 || funct3 === 3'b101)
               ? (($urandom()%2) ? 7'h20 : 7'h00) : 7'h00));
      end
      AluRWType: begin
        unique case(funct3)
          3'b100, 3'b110, 3'b111: return 7'h01;
          3'b101, 3'b000: return ($urandom()%2) ? 7'h01 : (($urandom()%2) ? 7'h20 : 7'h00);
          default return 7'h00; // 3'b001
        endcase
      end
      AluIType, AluIWType: begin
        return ($urandom()%2) ? 7'h20 : 7'h00;
      end
      default: begin // System
        if(funct3 === 3'b000) begin
          unique case($urandom()%4)
            0, 1: return 7'h00;
            2: return 7'h08;
            default: return 7'h18;
          endcase
        end else begin // FIXME: Implement funct7 for Zicsr
          return $urandom();
        end
      end
    endcase
  endfunction

endpackage
