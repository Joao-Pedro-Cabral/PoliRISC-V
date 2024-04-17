
module cache_tb ();

  import macros_pkg::*;

  localparam integer AmntOfTests = 10_000;
  localparam integer ClockPeriod = 10;
  localparam integer BusyCycles = 5;

  localparam integer CacheSize = 4096;
  localparam integer BlockSize = 128;
  localparam integer AddrSize = 15;
  localparam integer DataSize = 32;
  localparam integer ByteSize = 8;

  localparam string InitFile = "./MIFs/memory/ROM/bios/de10nano_bios.mif";

  /* Sinais de teste */
  logic clock = 1'b0, reset = 1'b0, rd_en = 1'b0, wr_en = 1'b0;
  logic [AddrSize-1:0] addr;
  logic [ByteSize-1:0] mem [2**AddrSize-1:0];
  logic [DataSize-1:0] wr_data, rd_data, expected_data;
  /* //// */

  /* Barramentos */
  wishbone_if #(.DATA_SIZE(BlockSize), .BYTE_SIZE(ByteSize), .ADDR_SIZE(AddrSize)) wb_if_mem (.*);
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
  assign wb_if_ctrl.primary.sel = 0;
  assign wb_if_ctrl.primary.addr = addr;
  assign wb_if_ctrl.primary.dat_o_p = wr_data;
  assign ack = wb_if_ctrl.primary.ack;
  assign rd_data = wb_if_ctrl.primary.dat_i_p;

  // Generate Expected Data
  always_comb begin
    for(int i = 0; i < DataSize/ByteSize; i++) begin
      expected_data[i*ByteSize+:ByteSize] = mem[addr + i];
    end
  end

  initial begin
    $readmemb(InitFile, mem);
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;

    $display("[%0t] SOT", $time);

    // Teste de leitura da Cache
    repeat(AmntOfTests) begin
      @(negedge clock);
      wr_data = $urandom;
      addr = $urandom;
      addr = (addr%4) << 2; // align 32 bits
      rd_en = $urandom;
      wr_en = ~rd_en;
      @(negedge clock);

      if(wr_en) begin
        for(int i = 0; i < DataSize/ByteSize; i++) begin
          mem[addr + i] = wr_data[i*ByteSize+:ByteSize];
        end
      end

      @(posedge ack);
      @(negedge clock);

      if(rd_en) begin
        CHK_READ: assert(rd_data === expected_data);
      end else begin
        CHK_WRITE: assert(rd_data === wr_data);
      end
    end
    $display("[%0t] EOT", $time);
    $stop;
  end

endmodule
