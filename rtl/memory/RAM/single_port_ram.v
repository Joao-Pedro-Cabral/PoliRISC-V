
module single_port_ram #(
    parameter RAM_INIT_FILE = "ram_init_file.mif",
    parameter ADDR_SIZE = 2,
    parameter BYTE_SIZE = 4,
    parameter DATA_SIZE = 4,
    parameter BUSY_CYCLES = 3
) (
    input wire CLK_I,
    input wire [DATA_SIZE-1:0] ADR_I,
    input wire [DATA_SIZE-1:0] DAT_I,
    input wire CYC_I,
    input wire WE_I,
    input wire STB_I,
    input wire [DATA_SIZE/BYTE_SIZE-1:0] SEL_I,
    output reg [DATA_SIZE-1:0] DAT_O,
    output reg ACK_O

);
  reg [1:0] busy_flag;

  function automatic [ADDR_SIZE-1:0] offset_and_truncate_address(input [DATA_SIZE-1:0] addr,
                                                                 input integer offset);
    offset_and_truncate_address = addr + offset;
  endfunction

  reg [BYTE_SIZE-1:0] ram[2**ADDR_SIZE-1:0];

  initial begin
    $readmemb(RAM_INIT_FILE, ram);
    ACK_O = 1'b0;
    busy_flag = 1'b0;
  end

  integer i;
  always @(posedge CLK_I) begin
    for (i = 0; i < DATA_SIZE / BYTE_SIZE; i = i + 1) begin
      if (STB_I && CYC_I && SEL_I[i] && WE_I) begin
        ram[offset_and_truncate_address(ADR_I, i)] <= DAT_I[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
      end
    end
  end

  integer j;
  always @(posedge CLK_I) begin
    for (j = 0; j < DATA_SIZE / BYTE_SIZE; j = j + 1) begin
      if (STB_I && CYC_I && SEL_I[j]) begin
        DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= ram[offset_and_truncate_address(ADR_I, j)];
      end else begin
        if (STB_I && CYC_I && SEL_I[j] && WE_I) begin
          DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= DAT_I[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
        end else begin
          DAT_O[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= 0;
        end
      end
    end
  end

  always @(posedge CLK_I) begin
    ACK_O <= 1'b0;
    if (busy_flag == 2'b10) begin
      ACK_O  <= 1'b1;
      busy_flag <= 2'b00;
    end else if (busy_flag != 2'b00) begin
      busy_flag <= {busy_flag[1] ^ busy_flag[0], ~busy_flag[0]}; // busy_flag + 1
    end else if (STB_I && CYC_I) begin
      busy_flag <= 2'b01;
    end
  end

endmodule
