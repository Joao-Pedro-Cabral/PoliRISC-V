//
//! @file   single_port_ram.v
//! @brief  Implementação de uma RAM de porta única com byte enable, escrita síncrona e leitura assíncrona
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-02-22
//

module single_port_ram #(
    parameter RAM_INIT_FILE = "ram_init_file.mif",
    parameter ADDR_SIZE = 2,
    parameter BYTE_SIZE = 4,
    parameter DATA_SIZE = 4,
    parameter BUSY_CYCLES = 3
) (
    input clk,
    input [DATA_SIZE-1:0] address,
    input [DATA_SIZE-1:0] write_data,
    input output_enable,
    input write_enable,
    input chip_select,
    input [DATA_SIZE/BYTE_SIZE-1:0] byte_enable,
    output reg [DATA_SIZE-1:0] read_data,
    output reg busy

);
  reg busy_flag;

  function automatic [ADDR_SIZE-1:0] offset_and_truncate_address(input [DATA_SIZE-1:0] addr,
                                                                 input integer offset);
    offset_and_truncate_address = addr + offset;
  endfunction

  reg [BYTE_SIZE-1:0] ram[2**ADDR_SIZE-1:0];

  initial begin
    $readmemb(RAM_INIT_FILE, ram);
    busy = 1'b0;
  end

  integer i;
  always @(posedge clk) begin
    for (i = 0; i < DATA_SIZE / BYTE_SIZE; i = i + 1) begin
      if (chip_select && byte_enable[i] && write_enable) begin
        ram[offset_and_truncate_address(address, i)] <= write_data[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
      end
    end
  end

  integer j;
  always @(posedge clk) begin
    for (j = 0; j < DATA_SIZE / BYTE_SIZE; j = j + 1) begin
      if (chip_select && output_enable && byte_enable[j]) begin
        read_data[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= ram[offset_and_truncate_address(address, j)];
      end else begin
        if (chip_select && byte_enable[j] && write_enable) begin
          read_data[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= write_data[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
        end else begin
          read_data[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= 0;
        end
      end
    end
  end

  always @* begin
    if (chip_select === 1'b1) if (output_enable === 1'b1 || write_enable !== 0) busy_flag <= 1'b1;
  end

  integer k;
  always @(posedge clk) begin
    if (busy_flag === 1'b1) begin
      busy = 1'b1;
      for (k = 0; k < BUSY_CYCLES; k = k + 1) begin
        wait (clk == 1'b0);
        wait (clk == 1'b1);
      end
      busy = 1'b0;
      busy_flag = 1'b0;
    end
  end

endmodule
