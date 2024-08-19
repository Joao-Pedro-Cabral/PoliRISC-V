
package sd_receiver_pkg;

  typedef enum logic [1:0] {
    Idle,
    WaitingSD,
    Receiving,
    WaitBusy
  } sd_receiver_fsm_t;

  typedef enum logic [2:0] {
    R1,
    R3OrR7,
    DataToken,
    DataBlock,
    R2
  } sd_receiver_response_t;

  typedef enum logic [12:0] {
    R1OrDataTokenSize = 7,
    R2Size = 15,
    R3OrR7Size = 39,
    DataBlockSize = 4112
  } sd_receiver_response_size_t;

endpackage
