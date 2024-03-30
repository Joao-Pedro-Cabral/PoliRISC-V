
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
    Sub = 5'b01000,
    ShiftRightArithmetic = 5'b01101,
    Mul = 5'b10000,
    MulHigh,
    MulHighSignedUnsigned,
    MulHighUnsigned,
    Div,
    DivUnsigned,
    Rem,
    RemUnsigned
  } alu_op_t;

endpackage
