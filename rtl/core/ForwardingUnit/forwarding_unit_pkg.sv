
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

  typedef struct {
    logic reg_we;
    logic [4:0] rd;
    forwarding_t target_forwarding;
  } forwarding_src_bundle_t;

  typedef struct {
    logic [4:0] rs;
    forwarding_t forward_rs;
  } forwarding_dst_bundle_t;

  function automatic bit valid_forwarding(input logic reg_we, input logic [4:0] rs,
                                          input logic [4:0] rd);
    return reg_we && rs && rd == rs;
  endfunction

  function automatic bit forward(input forwarding_src_bundle_t src_bundle,
                                 ref forwarding_dst_bundle_t dst_bundle);
    if (valid_forwarding(src_bundle.reg_we, dst_bundle.rs, src_bundle.rd)) begin
      dst_bundle.forward_rs = src_bundle.target_forwarding;
      return 1'b1;
    end
    dst_bundle.forward_rs = NoForwarding;
    return 1'b0;
  endfunction

endpackage
