
`include "board.vh"

package board_pkg;
  `ifdef LITEX
    localparam integer LitexArch = 1;
  `else
    localparam integer LitexArch = 0;
  `endif
  `ifdef NEXYS4
    localparam integer Nexys4 = 1;
    localparam integer LedSize = 16;
  `else
    localparam integer Nexys4 = 0;
    localparam integer LedSize = 10;
  `endif
endpackage
