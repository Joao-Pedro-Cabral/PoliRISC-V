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
    input CLK_I,
    input [DATA_SIZE-1:0] ADR_I,
    input [DATA_SIZE-1:0] DAT_I,
    input TGC_I,
    input WE_I,
    input STB_I,
    input [DATA_SIZE/BYTE_SIZE-1:0] SEL_I,
    output reg [DATA_SIZE-1:0] DAT_O,
    output reg ACK_O

);
  reg busy_flag;

  function automatic [ADDR_SIZE-1:0] offset_and_truncate_address(input [DATA_SIZE-1:0] addr,
                                                                 input integer offset);
    offset_and_truncate_address = addr + offset;
  endfunction

  reg [BYTE_SIZE-1:0] ram[2**ADDR_SIZE-1:0];

  initial begin
    $readmemb(RAM_INIT_FILE, ram);
    ACK_O = 1'b1;
  end

  integer i;
  always @(posedge CLK_I) begin
    for (i = 0; i < DATA_SIZE / BYTE_SIZE; i = i + 1) begin
      if (STB_I && SEL_I[i] && WE_I) begin
        ram[offset_and_truncate_address(ADR_I, i)] <= DAT_I[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
      end
    end
  end

  integer j;
  always @(posedge CLK_I) begin
    for (j = 0; j < DATA_SIZE / BYTE_SIZE; j = j + 1) begin
      if (STB_I && TGC_I && SEL_I[j]) begin
        DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= ram[offset_and_truncate_address(ADR_I, j)];
      end else begin
        if (STB_I && SEL_I[j] && WE_I) begin
          DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= DAT_I[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
        end else begin
          DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= 0;
        end
      end
    end
  end

  always @* begin
    if (STB_I === 1'b1) if (TGC_I === 1'b1 || WE_I !== 0) busy_flag <= 1'b1;
  end

  integer k;
  always @(posedge CLK_I) begin
    if (busy_flag === 1'b1) begin
      ACK_O = 1'b0;
      for (k = 0; k < BUSY_CYCLES; k = k + 1) begin
        wait (CLK_I == 1'b0);
        wait (CLK_I == 1'b1);
      end
      ACK_O = 1'b1;
      busy_flag = 1'b0;
    end
  end

endmodule
