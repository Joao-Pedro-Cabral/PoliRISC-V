
package branch_decoder_unit_pkg;

  typedef enum logic [2:0] {
    NoBranch,
    Mret,
    Sret,
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

  typedef enum logic [1:0] {
    PcPlus4,
    Sepc,
    Mepc,
    PcOrReadDataPlusImm
  } pc_src_t;


endpackage
