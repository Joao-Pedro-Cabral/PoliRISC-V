
package hazard_unit_pkg;

  typedef enum logic [1:0] {
    NoHazard,
    HazardDecode,
    HazardExecute
  } hazard_t;

  typedef enum logic {
    OnlyRs1,
    Rs1AndRs2
  } rs_used_t;

endpackage
