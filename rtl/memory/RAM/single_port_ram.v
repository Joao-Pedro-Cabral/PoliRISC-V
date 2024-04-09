
module single_port_ram #(
  parameter string RAM_INIT_FILE = "ram_init_file.mif",
  parameter integer BYTE_SIZE = 4,
  parameter integer BUSY_CYCLES = 3
) (
  wishbone_if.secondary wb_if_s
);

  localparam integer DataSize = $size(wb_if_s.dat_i_s);
  localparam integer AddrSize = $size(wb_if_s.addr);

  logic busy_flag = 1'b0;

  function automatic logic [AddrSize-1:0] offset_and_truncate_address(input reg [DataSize-1:0] addr,
                                                                      input integer offset);
    offset_and_truncate_address = addr + offset;
  endfunction

  reg [BYTE_SIZE-1:0] ram[2**AddrSize-1:0];

  initial begin
    $readmemb(RAM_INIT_FILE, ram);
  end

  always @(posedge CLK_I) begin
    for (int i = 0; i < DataSize / BYTE_SIZE; i = i + 1) begin
      if (wb_if_s.stb && wb_if_s.cyc && SEL_I[i] && wb_if_s.we) begin
        ram[offset_and_truncate_address(wb_if_s.addr, i)] <=
                wb_if_s.dat_i_s[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
      end
    end
  end

  always @(posedge CLK_I) begin
    for (int j = 0; j < DataSize / BYTE_SIZE; j = j + 1) begin
      if (wb_if_s.stb && wb_if_s.cyc && SEL_I[j]) begin
        wb_if_s.dat_o_s[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <=
          ram[offset_and_truncate_address(wb_if_s.addr, j)];
      end else begin
        if (wb_if_s.stb && wb_if_s.cyc && SEL_I[j] && wb_if_s.we) begin
          wb_if_s.dat_o_s[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <=
                wb_if_s.dat_i_s[(i+1)*BYTE_SIZE-1-:BYTE_SIZE];
        end else begin
          wb_if_s.dat_o_s[(j+1)*BYTE_SIZE-1-:BYTE_SIZE] <= 0;
        end
      end
    end
  end

  always @(posedge CLK_I) begin
    wb_if_s.ack <= 1'b0;
    if (busy_flag === 1'b1) begin
      repeat(BUSY_CYCLES) begin
        wait (wb_if_s.clock == 1'b0);
        wait (wb_if_s.clock == 1'b1);
      end
      wb_if_s.ack <= 1'b1;
      busy_flag <= 1'b0;
    end
  end

endmodule
