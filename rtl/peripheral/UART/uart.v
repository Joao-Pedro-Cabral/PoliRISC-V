//
//! @file   uart.v
//! @brief  UART, seguindo o padrão do SiFive FE310-G002
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

module uart (
    input wire clock,
    input wire reset,
    input wire rd_en,
    input wire wr_en,
    input wire [4:0] addr,  // 0x00 a 0x18
    input wire [31:0] wr_data,
    output wire [31:0] rd_data
);
endmodule
