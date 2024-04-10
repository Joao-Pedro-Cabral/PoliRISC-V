
module single_port_ram #(
  parameter string RAM_INIT_FILE = "ram_init_file.mif",
  parameter integer BUSY_CYCLES = 3
) (
  wishbone_if.secondary wb_if_s
);

  localparam integer DataSize = $size(wb_if_s.dat_i_s);
  localparam integer ByteSize = DataSize/$size(wb_if_s.sel);
  localparam integer AddrSize = $size(wb_if_s.addr);

  logic [$clog2(BUSY_CYCLES):0] busy_flag = 0;

  function automatic logic [AddrSize-1:0] offset_and_truncate_address(input reg [DataSize-1:0] addr,
                                                                      input integer offset);
    offset_and_truncate_address = addr + offset;
  endfunction

  reg [ByteSize-1:0] ram[2**AddrSize-1:0];

  initial begin
    $readmemb(RAM_INIT_FILE, ram);
  end

  always @(posedge wb_if_s.clock) begin
    for (int i = 0; i < DataSize / ByteSize; i = i + 1) begin
      if (wb_if_s.stb && wb_if_s.cyc && wb_if_s.sel[i] && wb_if_s.we) begin
        ram[offset_and_truncate_address(wb_if_s.addr, i)] <=
                wb_if_s.dat_i_s[(i+1)*ByteSize-1-:ByteSize];
      end
    end
  end

  always @(posedge wb_if_s.clock) begin
    for (int j = 0; j < DataSize / ByteSize; j = j + 1) begin
      if (wb_if_s.stb && wb_if_s.cyc && wb_if_s.sel[j]) begin
        wb_if_s.dat_o_s[(j+1)*ByteSize-1-:ByteSize] <=
          ram[offset_and_truncate_address(wb_if_s.addr, j)];
      end else begin
        if (wb_if_s.stb && wb_if_s.cyc && wb_if_s.sel[j] && wb_if_s.we) begin
          wb_if_s.dat_o_s[(j+1)*ByteSize-1-:ByteSize] <=
                wb_if_s.dat_i_s[(j+1)*ByteSize-1-:ByteSize];
        end else begin
          wb_if_s.dat_o_s[(j+1)*ByteSize-1-:ByteSize] <= 0;
        end
      end
    end
  end

  always @(posedge wb_if_s.clock) begin : wishbone_ack
    wb_if_s.ack <= 1'b0;
    if (busy_flag) begin
      busy_flag <= busy_flag + 1;
      if(busy_flag === BUSY_CYCLES) wb_if_s.ack <= 1'b1;
      else if(busy_flag === BUSY_CYCLES + 1) busy_flag <= 1'b0;
    end else if (wb_if_s.cyc && wb_if_s.stb) begin
      busy_flag <= 1'b1;
    end
  end

endmodule
