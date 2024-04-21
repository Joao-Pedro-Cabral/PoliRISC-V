
module cache_tb ();

  import macros_pkg::*;

  localparam integer AmntOfTests = 10_000;
  localparam integer ClockPeriod = 10;
  localparam integer BusyCycles = 5;

  localparam integer CacheSize = 2048;
  localparam integer BlockSize = 128;
  localparam integer AddrSize = 32;
  localparam integer DataSize = 32;
  localparam integer ByteSize = 8;
  localparam integer SelSize = DataSize/ByteSize;

  localparam integer MemAddrSize = 13;

  localparam string InitFile = "./MIFs/memory/ROM/bios/de10nano_bios.mif";

  /* Sinais de teste */
  logic clock = 1'b0, reset = 1'b0, rd_en = 1'b0, wr_en = 1'b0;
  logic [AddrSize-1:0] addr;
  logic [SelSize-1:0] sel;
  logic rd_signed;
  logic [ByteSize-1:0] mem [2**MemAddrSize-1:0];
  logic [DataSize-1:0] wr_data, rd_data, aligned_data, expected_data;
  logic [2:0] access_to_same_addr;
  /* //// */

  function automatic logic [SelSize-1:0] gen_random_sel();
    logic [$clog2(SelSize):0] temp;
    begin
      temp = $urandom();
      return (2**(2**temp) - 1);
    end
  endfunction

  function automatic logic [AddrSize-1:0] gen_random_addr(input reg [SelSize-1:0] sel);
    logic [AddrSize-1:0] addr;
    begin
      addr = $urandom;
      addr >>= $clog2(sel+1);
      addr <<= $clog2(sel+1);
      return addr%2**MemAddrSize;
    end
  endfunction

  function automatic logic [DataSize-1:0] get_expected_data(input reg [DataSize-1:0] aligned_data,
                                  input reg [SelSize-1:0] sel, input reg rd_signed);
    logic [DataSize-1:0] sel2, data;
    begin
      for(int i = 0; i < SelSize; i++)
        sel2[i*ByteSize+:ByteSize] = {ByteSize{sel[i]}};
      data = sel2 & aligned_data;
      if(!rd_signed) return data;
      for(int i = SelSize; i >= 1; i /= 2)
        if(sel[i-1]) return (data | ({DataSize{data[ByteSize*(2**$clog2(i))-1]}} & ~sel2));
    end
  endfunction

  /* Barramentos */
  wishbone_if #(.DATA_SIZE(BlockSize), .BYTE_SIZE(ByteSize), .ADDR_SIZE(MemAddrSize)) wb_if_mem (.*);
  wishbone_if #(.DATA_SIZE(DataSize), .BYTE_SIZE(ByteSize), .ADDR_SIZE(AddrSize)) wb_if_ctrl (.*);
  /* //// */

  single_port_ram #(
    .RAM_INIT_FILE(InitFile),
    .BUSY_CYCLES(BusyCycles)
  ) cache_ram (
    .wb_if_s(wb_if_mem)
  );

  cache #(
      .CACHE_SIZE(CacheSize)
  ) DUT (.*);

  // Generate Clock
  always #(ClockPeriod / 2) clock = ~clock;

  // Wishbone
  assign wb_if_ctrl.primary.cyc = rd_en | wr_en;
  assign wb_if_ctrl.primary.stb = rd_en | wr_en;
  assign wb_if_ctrl.primary.we = wr_en;
  assign wb_if_ctrl.primary.sel = sel;
  assign wb_if_ctrl.primary.tgd = rd_signed;
  assign wb_if_ctrl.primary.addr = addr;
  assign wb_if_ctrl.primary.dat_o_p = wr_data;
  assign ack = wb_if_ctrl.primary.ack;
  assign rd_data = wb_if_ctrl.primary.dat_i_p;

  // Generate Expected Data
  always_comb begin
    for(int i = 0; i < SelSize; i++) begin
      aligned_data[i*ByteSize+:ByteSize] = mem[addr + i];
    end
  end

  initial begin
    $readmemb(InitFile, mem);
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;
    @(negedge clock);

    $display("[%0t] SOT", $time);

    // Teste de leitura da Cache
    repeat(AmntOfTests) begin
      sel = gen_random_sel();
      addr = gen_random_addr(sel);
      access_to_same_addr = $urandom + 1;
      for(int i = 0; i < access_to_same_addr; i++) begin
        rd_signed = $urandom;
        wr_data = $urandom;
        rd_en = $urandom;
        wr_en = ~rd_en;
        @(negedge clock);

        if(wr_en) begin
          for(int i = 0; i < SelSize; i++) begin
            if(sel[i])
              mem[addr + i] = wr_data[i*ByteSize+:ByteSize];
          end
        end

        @(posedge ack);
        @(negedge clock);

        expected_data = get_expected_data(aligned_data, sel, rd_signed);

        if(rd_en) begin
          CHK_READ: assert(rd_data === expected_data);
        end else begin
          @(negedge clock);
          CHK_WRITE: assert(rd_data === expected_data);
        end

        wr_en = 1'b0;
        rd_en = 1'b0;
        @(negedge clock);
      end
    end
    $display("[%0t] EOT", $time);
    $stop;
  end

endmodule
