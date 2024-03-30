
package alu_pkg;

  typedef enum logic [4:0] {
    Add,
    ShiftLeftLogic,
    SetLessThan,
    SetLessThanUnsigned,
    Xor,
    ShiftRightLogic,
    Or,
    And,
    Mul,
    MulHigh,
    MulHighSignedUnsigned,
    MulHighUnsigned,
    Div,
    DivUnsigned,
    Rem,
    RemUnsigned,
    Sub,
    ShiftRightArithmetic = 5'b10101
  } alu_op_t;

endpackage
