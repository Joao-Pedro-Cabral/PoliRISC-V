
package uart_pkg;

  typedef enum logic [2:0] {
    Idle,
    Read,
    Write,
    EndOp,
    Final
  } uart_fsm_t;

  typedef enum logic [3:0] {
    TxData,
    RxData,
    TxFull,
    TxEmpty,
    RxFull,
    RxEmpty,
    InterruptEn,
    Pending,
    Status,
    TxControl,
    RxControl,
    ClockDiv
  } uart_addr_t;

  typedef enum logic [2:0] {
    LitexData,
    LitexTxFull,
    LitexRxEmpty,
    LitexStatus,
    LitexPending,
    LitexInterruptEn,
    LitexTxEmpty,
    LitexRxFull
  } uart_litex_addr_t;

  typedef enum logic [2:0] {
    SiFiveTxData,
    SiFiveRxData,
    SiFiveTxControl,
    SiFiveRxControl,
    SiFiveInterruptEn,
    SiFivePending,
    SiFiveClockDiv
  } uart_sifive_addr_t;

endpackage
