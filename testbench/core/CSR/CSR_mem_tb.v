
module CSR_mem_tb ();

  import extensions_pkg::*;

  localparam integer IsRV64I = (DataSize == 64);

  localparam integer Seed = 69_420;
  localparam integer AmntOfTests = 3000;
  localparam integer ClockCycles = 100;

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
  logic [63:0] expected_data;
  logic [6:0] cycles;
  logic tick;
  logic tick_;
  logic [63:0] mtime_;

  CSR_mem #(
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
  assign wb_if.primary.addr = addr;
  assign wb_if.primary.dat_o_p = wr_data;
  assign ack = wb_if.primary.ack;
  assign rd_data = wb_if.primary.dat_i_p;

  sync_parallel_counter #(
      .size(7),
      .init_value(0)
  ) tick_counter (
      .clock(clock),
      .reset(reset),
      .load(tick),
      .load_value(7'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(cycles)
  );
  assign tick = (cycles == (ClockCycles - 1));

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
      case (addr[1:0])
        2'b00: begin
          `ASSERT(rd_data === DUT.msip_,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.msip_ = 0x%x",
                  addr, rd_data, DUT.msip_))

          `ASSERT(rd_data === msip,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmsip = 0x%x", addr, rd_data, msip))
        end

`ifdef RV64I
        2'b10: begin
          `ASSERT(rd_data === DUT.mtime_,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_ = 0x%x",
                  addr, rd_data, DUT.mtime_))

          `ASSERT(
              rd_data === mtime,
              ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtime = 0x%x", addr, rd_data, mtime))
        end
        2'b11: begin
          `ASSERT(rd_data === DUT.mtimecmp_,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtimecmp_ = 0x%x",
                  addr, rd_data, DUT.mtimecmp_))

          `ASSERT(rd_data === mtimecmp,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp = 0x%x",
                  addr, rd_data, mtimecmp))
        end
`else
        2'b10: begin
          if (addr[2]) begin
            `ASSERT(
                rd_data === DUT.mtime_[63:32],
                ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[63:32] = 0x%x", addr, rd_data, DUT.mtime_[63:32]))

            `ASSERT(
                rd_data === mtime[63:32],
                ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtime[63:32] = 0x%x", addr, rd_data, mtime[63:32]))
          end else begin
            `ASSERT(rd_data === DUT.mtime_[31:0],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[31:0] = 0x%x",
                    addr, rd_data, DUT.mtime_[31:0]))

            `ASSERT(rd_data === mtime[31:0],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtime[31:0] = 0x%x",
                    addr, rd_data, mtime[31:0]))
          end
        end
        2'b11: begin
          if (addr[2]) begin
            `ASSERT(
                rd_data === DUT.mtimecmp_[63:32],
                ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[63:32] = 0x%x", addr, rd_data, DUT.mtimecmp_[63:32]))

            `ASSERT(
                rd_data === mtimecmp[63:32],
                ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp[63:32] = 0x%x", addr, rd_data, mtimecmp[63:32]))
          end else begin
            `ASSERT(rd_data === DUT.mtimecmp_[31:0],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[31:0] = 0x%x",
                    addr, rd_data, DUT.mtimecmp_[31:0]))

            `ASSERT(rd_data === mtimecmp[31:0],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp[31:0] = 0x%x",
                    addr, rd_data, mtimecmp[31:0]))
          end
        end
`endif
        default: begin
          `ASSERT(rd_data === DataSize'b0,
                  ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x", addr, rd_data))
        end
      endcase
    end
  endtask

  // TODO: Create enum to addr
  task automatic CheckWrite;
    begin
      wr_en  = 1'b0;
      tick_  = tick;
      mtime_ = mtime;
      @(negedge clock);
      CHECK_ACK_WRITE: assert (ack === 1'b1);
      case (addr[1:0])
        2'b00: begin
          CHECK_MSIP_WRITE: assert (wr_data === msip);
          CHECK_RD_MSIP_WRITE: assert (wr_data === rd_data);
        end
        2'b10: begin
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
          CHECK_RD_MTIME_WRITE: assert (expected_data === rd_data);
        end
        2'b11: begin
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
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
