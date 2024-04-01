
`include "extensions.vh"

package extensions_pkg;
  `ifdef RV64I
    localparam int DataSize = 64;
    localparam int ByteNum = 8;
  `else
    localparam int DataSize = 32;
    localparam int ByteNum = 4;
  `endif
endpackage
