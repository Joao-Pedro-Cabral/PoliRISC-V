
package dataflow_pkg;

  typedef enum logic [2:0] {
    Fetch,
    Decode,
    Execute,
    Memory,
    WriteBack
  } stages_t;

endpackage
