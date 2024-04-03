
package csr_pkg;

  typedef enum logic [1:0] {
    User,
    Supervisor,
    Machine = 2'b11
  } privilege_mode_t;

  function automatic privilege_mode_t gen_random_privilege_mode();
    unique case($urandom()%3)
      0: return User;
      1: return Supervisor;
      default: return Machine;
    endcase
  endfunction

endpackage
