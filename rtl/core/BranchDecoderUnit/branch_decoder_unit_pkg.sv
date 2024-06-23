
package branch_decoder_unit_pkg;

  typedef enum logic [1:0] {
    NoBranch,
    Jump,
    CondBranch
  } branch_t;

  typedef enum logic [2:0] {
    Beq,
    Bne,
    Blt,
    Bge,
    Bltu,
    Bgeu
  } cond_branch_t;

  typedef enum logic {
    PcPlus4,
    PcOrReadDataPlusImm
  } pc_src_t;

endpackage
