
package instruction_pkg;

  typedef enum logic [6:0] {
    UlaRType = 7'b0110011,
    UlaRWType = 7'b0111011,
    UlaIType = 7'b0010011,
    UlaIWType = 7'b0011011,
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

endpackage
