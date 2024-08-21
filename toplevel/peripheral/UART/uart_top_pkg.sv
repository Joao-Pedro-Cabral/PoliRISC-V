
package uart_top_pkg;

  typedef enum logic [3:0] {
    Idle = 4'h0,
    ConfReceiveControl = 4'h1,
    ConfTransmitControl = 4'h2,
    ConfInterruptEn = 4'h3,
    WaitInterrupt = 4'h4,
    ReadingData = 4'h5,
    InitWritingData = 4'h6,
    WritingData = 4'h7,
    ClearInterrupt = 4'h8
  } uart_top_fsm_t;

endpackage
