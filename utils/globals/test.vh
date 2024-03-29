  `ifdef RV64I
    `define BYTE_NUM 8;
    `define DATA_SIZE 64;
  `else
    `define BYTE_NUM 4;
    `define DATA_SIZE 32;
  `endif