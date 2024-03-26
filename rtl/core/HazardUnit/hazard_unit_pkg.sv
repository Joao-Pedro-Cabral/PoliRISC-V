
package hazard_unit_pkg;

  typedef enum logic [1:0] {
    NoHazard,
    HazardDecode,
    HazardExecute,
    HazardException
  } hazard_t;

endpackage
