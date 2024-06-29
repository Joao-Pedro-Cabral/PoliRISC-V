package forwarding_unit_pkg;

  typedef enum logic [1:0] {
    NoForward,
    ForwardExecute,
    ForwardDecode,
    ForwardExecuteMemory
  } forwarding_type_t;

  typedef enum logic [1:0] {
    NoForwarding,
    ForwardFromEx,
    ForwardFromMem,
    ForwardFromWb
  } forwarding_t;

endpackage
