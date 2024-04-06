
package csr_mem_pkg;

  typedef enum logic [1:0] {
    Msip = 2'b00,
    Mtime = 2'b01,
    Mtimecmp = 2'b11
  } csr_mem_addr_t;

endpackage
