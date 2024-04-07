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
    logic [4:0]  rs;
    forwarding_t forward_rs;
  } forwarding_dst_bundle_t;

endpackage
