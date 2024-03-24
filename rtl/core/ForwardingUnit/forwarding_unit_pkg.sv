
package forwarding_unit_pkg;

  typedef enum logic [1:0] {
    NoType,
    Type1,
    Type2,
    Type1_3
  } forwarding_type_t;

  typedef enum logic [1:0] {
    NoForwarding,
    ForwardFromEx,
    ForwardFromMem,
    ForwardFromWb
  } forwarding_t;

  function automatic bit valid_forwarding(input logic reg_we, input logic [4:0] rs,
                                          input logic [4:0] rd);
    return reg_we && !rs && rd == rs;
  endfunction

  task automatic forward(input logic reg_we, input logic [4:0] rs, input logic [4:0] rd,
                         input forwarding_t target_forwarding, output forwarding_t forward_rs);
    if (valid_forwarding(reg_we, rs, rd)) begin
      forward_rs = target_forwarding;
    end
  endtask

endpackage
