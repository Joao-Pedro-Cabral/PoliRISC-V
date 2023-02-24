//
//! @file   single_port_ram.v
//! @brief  Implementação de uma RAM de porta única com byte enable
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-22
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
    function automatic [ADDR_SIZE-1:0] offset_and_truncate_address(input [DATA_SIZE-1:0] addr, input integer offset);
      offset_and_truncate_address = addr + offset;
    endfunction

    reg [BYTE_SIZE-1:0] ram [2**ADDR_SIZE-1:0];

    integer i;
    always @(posedge clk) begin
        for(i = 0; i < DATA_SIZE/BYTE_SIZE; i = i + 1) begin
            if(byte_write_enable[i]) begin
                ram[offset_and_truncate_address(address, i)] <= write_data[(i+1)*BYTE_SIZE-1 -: BYTE_SIZE];
            end
        end
    end

    genvar j;
    generate
        for(j = 0; j < DATA_SIZE/BYTE_SIZE; j = j + 1) begin : out_data
            assign read_data[(j+1)*BYTE_SIZE-1:j*BYTE_SIZE] = ram[offset_and_truncate_address(address, j)];
        end
    endgenerate

endmodule
