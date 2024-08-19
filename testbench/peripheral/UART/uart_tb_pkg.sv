
package uart_tb_pkg;

  typedef enum logic [2:0] {
    Idle,
    Start,
    Data,
    Parity,
    Stop1,
    Stop2
  } uart_phy_fsm_t;

  typedef enum logic [2:0] {
    ProcessorIdle,
    ProcessorReadOp,
    ProcessorWriteOp,
    ProcessorInterruptCheck,
    ProcessorStatusCheck,
    ProcessorTxEmptyCheck,
    ProcessorRxFullCheck
  } processor_task_t;

  typedef enum logic [2:0] {
    TxTaskInit,
    TxTaskStart,
    TxTaskData,
    TxTaskStop1,
    TxTaskStop2
  } tx_task_t;

  typedef enum logic [2:0] {
    RxTaskInit,
    RxTaskStart,
    RxTaskData,
    RxTaskStop1,
    RxTaskStop2,
    RxTaskEnd,
    RxTaskSyncTx
  } rx_task_t;

endpackage
