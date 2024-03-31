package memory_unit_pkg;

  typedef enum logic [1:0] {
    Idle,
    WaitAnyMem,
    WaitInstMem,
    WaitDataMem
  } memory_unit_fsm_t;

endpackage
