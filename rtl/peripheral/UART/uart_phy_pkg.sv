
package uart_phy_pkg;

  typedef enum logic [2:0] {
    Idle,
    Start,
    Data,
    Parity,
    Stop1,
    Stop2
  } uart_phy_fsm_t;

endpackage
