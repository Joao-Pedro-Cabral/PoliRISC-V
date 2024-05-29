
package control_unit_pkg;

  typedef enum logic [1:0] {
    WrAluY,
    WrCsrRdData,
    WrRdData,
    WrPcPlus4
  } wr_reg_t;

endpackage
