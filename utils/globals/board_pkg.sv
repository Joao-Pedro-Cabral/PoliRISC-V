
`include "board.vh"

package board_pkg;
  `ifdef LITEX_
    localparam integer LitexArch = 1;
  `else
    localparam integer LitexArch = 0;
  `endif
endpackage
