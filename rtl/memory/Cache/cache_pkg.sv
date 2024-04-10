
package cache_pkg;

  typedef enum logic [1:0] {
    Idle,
    CompareTag,
    Allocate,
    WriteBack
  } cache_state_t;

endpackage
