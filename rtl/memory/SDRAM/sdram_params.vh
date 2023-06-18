// `define CLOCK_TIME 100 // MHz
// `define CLOCK_PERIOD 1000/`CLOCK_TIME
// // time in nano seconds
// // constants in cycles of clock
// `define T_DELAY 100000/`CLOCK_PERIOD -1
// `define T_MRD 1 // ever 2 cycles
// `define T_RC 60/`CLOCK_PERIOD -1
// `define T_RCD 15/`CLOCK_PERIOD -1
// `define T_RCD_RC max{(`T_RC + 1) - (`T_RCD + 1) - 3 - 1, `T_RCD}
// `define T_RP 15/`CLOCK_PERIOD -1
// `define T_WR 1 // ever 2 cycles
// `define T_REF 64*(10**6)/(8192*`CLOCK_PERIOD)
// `define T_REF_INI 8*(1+`T_RC) - 1
// `define CAS_LATENCY 1 - 1
`define T_DELAY 100
`define T_MRD 1
`define T_RC 5
`define T_RCD 1
`define T_RCD_RC 1
`define T_RP 1
`define T_WR 1
`define T_REF 78 //781
`define T_REF_INI 47
`define CAS_LATENCY 0
