//
//! @file   sklansky_adder.v
//! @brief  Implementação do somador condicional de Sklansky
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-21
//

module single_port_ram
#(
    parameter ADDR_SIZE=4,
    parameter BYTE_SIZE=8,
    parameter DATA_SIZE=8
)
(
    input clk,
    input [DATA_SIZE-1:0] address,
    input [DATA_SIZE-1:0] write_data,
    input [DATA_SIZE/BYTE_SIZE-1:0] byte_write_enable,
    output wire [DATA_SIZE-1:0] read_data
);

    reg [BYTE_SIZE-1:0] ram [2**ADDR_SIZE-1:0];

    integer i;
    always @(posedge clk) begin
        for(i = 0; i < DATA_SIZE/BYTE_SIZE; i = i + 1) begin
            if(byte_write_enable[i]) begin
                ram[address+i] <= write_data[(i+1)*BYTE_SIZE-1 -: BYTE_SIZE];
            end
        end
    end

    genvar j;
    generate
        for(j = 0; j < DATA_SIZE/BYTE_SIZE; j = j + 1) begin : out_data
            assign read_data[(j+1)*BYTE_SIZE-1:j*BYTE_SIZE] = ram[address+j];
        end
    endgenerate

endmodule
