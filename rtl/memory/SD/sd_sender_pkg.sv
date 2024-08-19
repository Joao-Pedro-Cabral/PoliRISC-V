
package sd_sender_pkg;

  typedef enum logic {
    Idle,
    Sending
  } sd_sender_fsm_t;

  typedef enum logic {
    Cmd,
    Data
  } sd_sender_chunk_t;

endpackage
