
package forwarding_unit_pkg;

  typedef enum logic [1:0] {
    NoType,
    Type1,
    Type2,
    Type1_3
  } forwarding_type_t;

  typedef enum logic [1:0] {
    NoForwarding,
    FromEx,
    FromMem,
    FromWb
  } forwarding_t;

endpackage
