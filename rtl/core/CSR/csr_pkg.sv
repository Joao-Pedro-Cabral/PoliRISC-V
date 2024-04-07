
package csr_pkg;

  typedef enum logic [1:0] {
    User,
    Supervisor,
    Machine = 2'b11
  } privilege_mode_t;

  typedef enum logic [2:0] {
    CsrNoOp,
    CsrRW,
    CsrRS,
    CsrRC,
    CsrMret,
    CsrSret
  } csr_op_t;

  typedef enum logic [3:0] {
    SIE = 4'h1,
    MIE = 4'h3,
    SPIE = 4'h5,
    MPIE = 4'h7,
    SPP = 4'h8,
    MPP = 4'hB
  } status_t;

  typedef enum logic [3:0] {
    SSI = 4'h1,
    MSI = 4'h3,
    STI = 4'h5,
    MTI = 4'h7,
    SEI = 4'h9,
    MEI = 4'hB
  } interrupt_t;

  typedef enum logic [3:0] {
    II = 4'h2,
    ECU = 4'h8,
    ECS = 4'h9,
    ECM = 4'hB
  } exception_t;

  typedef enum logic [11:0] {
    Sstatus = 12'h100,
    Sie = 12'h104,
    Stvec = 12'h105,
    Sscratch = 12'h140,
    Sepc = 12'h141,
    Scause = 12'h142,
    Stval = 12'h143,
    Sip = 12'h144,
    Mstatus = 12'h300,
    Misa = 12'h301,
    Medeleg = 12'h302,
    Mideleg = 12'h303,
    Mie = 12'h304,
    Mtvec = 12'h305,
    Mscratch = 12'h340,
    Mepc = 12'h341,
    Mcause = 12'h342,
    Mtval = 12'h343,
    Mip = 12'h344,
    Mvendorid = 12'hF11,
    Marchid = 12'hF12,
    Mimpid = 12'hF13,
    Mhartid = 12'hF14
  } csr_addr_t;

  function automatic privilege_mode_t gen_random_privilege_mode();
    unique case($urandom()%3)
      0: return User;
      1: return Supervisor;
      default: return Machine;
    endcase
  endfunction

endpackage
