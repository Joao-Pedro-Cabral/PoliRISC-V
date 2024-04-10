
module csr_mem_tb ();

  import csr_mem_pkg::*;
  import macros_pkg::*;
  import extensions_pkg::*;

  localparam integer IsRV64I = (DataSize == 64);

  localparam integer Seed = 69_420;
  localparam integer AmntOfTests = 10_000;
  localparam integer ClockCycles = 30;

  // DUT
  // Inputs
  logic clock, reset;
  logic [DataSize-1:0] wr_data;
  logic [2:0] addr;
  wishbone_if #(.DATA_SIZE(DataSize), .ADDR_SIZE(3)) wb_if (.*);

  // Outputs
  logic ack;
  logic [DataSize-1:0] msip, rd_data;
  logic [63:0] mtime, mtimecmp;

  // Auxiliares
  logic wr_en, rd_en;
  logic [63:0] expected_data;
  logic [4:0] cycles;
  logic tick, tick_;
  logic [63:0] mtime_, mtimecmp_;
  logic [DataSize-1:0] msip_;

  csr_mem #(
      .DATA_SIZE(DataSize),
      .CLOCK_CYCLES(ClockCycles)
  ) DUT (
      .wb_if_s(wb_if),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // Wishbone
  assign wb_if.primary.cyc = rd_en | wr_en;
  assign wb_if.primary.stb = rd_en | wr_en;
  assign wb_if.primary.we  = wr_en;
  assign wb_if.primary.sel = 0;
  assign wb_if.primary.addr = addr;
  assign wb_if.primary.dat_o_p = wr_data;
  assign ack = wb_if.primary.ack;
  assign rd_data = wb_if.primary.dat_i_p;

  // Components
  sync_parallel_counter #(
      .size(5),
      .init_value(0)
  ) tick_counter (
      .clock(clock),
      .reset(reset),
      .load(tick),
      .load_value(5'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(cycles)
  );
  assign tick = (cycles == (ClockCycles - 1));

  always_ff @(posedge clock, posedge reset) begin
    if(reset) msip_ <= 0;
    else if(wr_en && (addr[1:0] == Msip)) msip_ <= wr_data;
  end

  always_ff @(posedge clock, posedge reset) begin
    if(reset) mtime_ <= 0;
    else if(wr_en && (addr[1:0] == Mtime)) begin
      if(IsRV64I) mtime_ <= wr_data;
      else mtime_ <= addr[2] ? {wr_data, mtime_[31:0]} : {mtime_[63:32], wr_data};
    end
    else if(tick) mtime_ <= mtime_ + 1;
  end

  always_ff @(posedge clock, posedge reset) begin
    if(reset) mtimecmp_ <= 0;
    else if(wr_en && (addr[1:0] == Mtimecmp)) begin
      if(IsRV64I) mtimecmp_ <= wr_data;
      else mtimecmp_ <= addr[2] ? {wr_data, mtimecmp_[31:0]} : {mtimecmp_[63:32], wr_data};
    end
  end

  event   write_data_event;
  integer j;
  always @(write_data_event) begin
    for (j = 0; j < DataSize / 32; j = j + 1) begin
      wr_data[32*j+:32] <= $urandom;
    end
  end

  task automatic CheckRead;
    begin
      rd_en = 1'b0;
      @(negedge clock);
      CHECK_ACK_READ: assert (ack === 1'b1);
      unique case (addr[1:0])
        Msip: begin
          CHECK_MSIP_READ: assert (msip_ === msip);
          CHECK_RD_MSIP_READ: assert (msip_ === rd_data);
        end
        Mtime: begin
          CHECK_MTIME_READ: assert (mtime_ === mtime);
          CHECK_RD_MTIME_READ: assert ((IsRV64I ? mtime_ : (addr[2] ? mtime_[63:32]
                                        : mtime_[31:0])) === rd_data);
        end
        Mtimecmp: begin
          CHECK_MTIMECMP_READ: assert (mtimecmp_ === mtimecmp);
          CHECK_RD_MTIMECMP_READ: assert ((IsRV64I ? mtimecmp_ : (addr[2] ? mtimecmp_[63:32]
                                        : mtimecmp_[31:0])) === rd_data);
        end
        default: begin
        end
      endcase
    end
  endtask

  task automatic CheckWrite;
    begin
      wr_en  = 1'b0;
      tick_  = tick;
      @(negedge clock);
      CHECK_ACK_WRITE: assert (ack === 1'b1);
      unique case (addr[1:0])
        Msip: begin
          CHECK_MSIP_WRITE: assert (wr_data === msip);
          CHECK_RD_MSIP_WRITE: assert (wr_data === rd_data);
        end
        Mtime: begin
          if(IsRV64I) begin
            if (tick_) expected_data = wr_data + 1;
            else expected_data = wr_data;
          end else begin
            if (tick_) begin
              if (addr[2]) expected_data = {wr_data, mtime_[31:0]} + 1;
              else expected_data = {mtime_[63:32], wr_data} + 1;
            end else begin
              if (addr[2]) expected_data = {wr_data, mtime_[31:0]};
              else expected_data = {mtime_[63:32], wr_data};
            end
          end
          CHECK_MTIME_WRITE: assert (expected_data === mtime);
          CHECK_RD_MTIME_WRITE: assert ((IsRV64I ? expected_data : (addr[2] ? expected_data[63:32]
                                        : expected_data[31:0])) === rd_data);
        end
        Mtimecmp: begin
          CHECK_MTIMECMP_WRITE: assert (wr_data === (IsRV64I ? mtimecmp :
                                (addr[2] ? mtimecmp[63:32] : mtimecmp[31:0])));
        end
        default: begin  // Nothing to do (addr = 2'b01)
        end
      endcase
    end
  endtask

  always #1 clock = ~clock;

  // Initial para estimular o DUT
  initial begin
    clock = 1'b0;
    reset = 1'b0;

    @(negedge clock);
    addr  = $urandom(Seed);  // inicializando a Seed
    reset = 1'b1;
    @(negedge clock);
    addr  = 3'b0;
    reset = 1'b0;

    $display("SOT: [%0t]", $time);

    repeat(AmntOfTests) begin
      rd_en = $urandom;
      wr_en = ~rd_en;
      addr  = $urandom;
      if (wr_en) begin
        ->write_data_event;
      end

      @(negedge clock);

      if (rd_en) begin
        CheckRead;
      end else begin
        CheckWrite;
      end

      @(negedge clock);
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
