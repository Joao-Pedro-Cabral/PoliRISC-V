`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

`define ASSERT(cond, message) if (!(cond)) begin $display message ; $stop; end

module CSR_mem_tb ();

  localparam integer Seed = 69_420;
  localparam integer AmntOfTests = 3000;

  // Inputs
  reg clock;
  reg reset;
  reg rd_en;
  reg wr_en;
  reg [2:0] addr;
  reg [`DATA_SIZE-1:0] wr_data;

  // Outputs
  wire [`DATA_SIZE-1:0] rd_data;
  wire busy;
  wire [`DATA_SIZE-1:0] msip;
  wire [63:0] mtime;
  wire [63:0] mtimecmp;

  // Auxiliares
  reg [63:0] mtime_data;
  wire [6:0] cycles;
  wire tick;
  reg tick_;
  reg [63:0] mtime_;

  CSR_mem #(
      .ClockCycles(100)
  ) DUT (
      .clock(clock),
      .reset(reset),
      .rd_en(rd_en),
      .wr_en(wr_en),
      .addr(addr),
      .wr_data(wr_data),
      .rd_data(rd_data),
      .busy(busy),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

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
  assign tick = (cycles == 99);

  event   write_data_event;
  integer j;
  always @(write_data_event) begin
    for (j = 0; j < `DATA_SIZE / 32; j = j + 1) begin
      wr_data[32*j+:32] <= $urandom;
    end
  end

  task automatic CheckRead;
    begin
      rd_en = 1'b0;
      @(negedge clock);
      `ASSERT(busy === 1'b0, ("[CheckRead]\nbusy = 0b%d", busy))
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
          if(addr[2]) begin
            `ASSERT(rd_data === DUT.mtime_[63:32],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[63:32] = 0x%x",
                    addr, rd_data, DUT.mtime_[63:32]))

            `ASSERT(rd_data === mtime[63:32],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtime[63:32] = 0x%x",
                    addr, rd_data, mtime[63:32]))
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
          if(addr[2]) begin
            `ASSERT(rd_data === DUT.mtimecmp_[63:32],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nDUT.mtime_[63:32] = 0x%x",
                    addr, rd_data, DUT.mtimecmp_[63:32]))

            `ASSERT(rd_data === mtimecmp[63:32],
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp[63:32] = 0x%x",
                    addr, rd_data, mtimecmp[63:32]))
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
          `ASSERT(rd_data === `DATA_SIZE'b0,
                    ("[CheckRead]\naddr = 0x%x,\nrd_data = 0x%x",
                    addr, rd_data))
        end
      endcase
    end
  endtask

  task automatic CheckWrite;
    begin
      wr_en = 1'b0;
      tick_ = tick;
      mtime_ = mtime;
      @(negedge clock);
      `ASSERT(busy === 1'b0, ("[CheckWrite]\nbusy = 0b%d", busy))
      case (addr[1:0])
        2'b00: begin
          `ASSERT(wr_data === DUT.msip_,
                  ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nDUT.msip_ = 0x%x",
                  addr, wr_data, DUT.msip_))

          `ASSERT(wr_data === msip,
                  ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nmsip = 0x%x", addr, wr_data, msip))
        end

`ifdef RV64I
        2'b10: begin
          if(tick_) wr_data = wr_data + 1;
          else wr_data = wr_data;
          `ASSERT(wr_data === DUT.mtime_,
                  ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nDUT.mtime_ = 0x%x",
                  addr, wr_data, DUT.mtime_))

          `ASSERT(
              wr_data === mtime,
              ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nmtime = 0x%x", addr, wr_data, mtime))
        end
        2'b11: begin
          `ASSERT(wr_data === DUT.mtimecmp_,
                  ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nDUT.mtimecmp_ = 0x%x",
                  addr, wr_data, DUT.mtimecmp_))

          `ASSERT(wr_data === mtimecmp,
                  ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nmtimecmp = 0x%x",
                  addr, wr_data, mtimecmp))
        end
`else
        2'b10: begin
          if(tick_) begin
            if(addr[2]) mtime_data = {wr_data, mtime_[31:0]} + 1;
            else mtime_data = {mtime_[63:32], wr_data} + 1;
          end else begin
            if(addr[2]) mtime_data = {wr_data, mtime_[31:0]};
            else mtime_data = {mtime_[63:32], wr_data};
          end
          `ASSERT(mtime_data === DUT.mtime_,
                  ("[CheckWrite]\naddr = 0x%x,\nmtime_data = 0x%x,\nDUT.mtime_ = 0x%x",
                  addr, mtime_data, DUT.mtime_))

          `ASSERT(mtime_data === mtime,
                  ("[CheckWrite]\naddr = 0x%x,\nmtime_data = 0x%x,\nmtime = 0x%x",
                  addr, mtime_data, mtime))
        end
        2'b11: begin
          if(addr[2]) begin
            `ASSERT(wr_data === DUT.mtimecmp_[63:32],
                    ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nDUT.mtime_[63:32] = 0x%x",
                    addr, wr_data, DUT.mtimecmp_[63:32]))

            `ASSERT(wr_data === mtimecmp[63:32],
                    ("[CheckWrite]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp[63:32] = 0x%x",
                    addr, rd_data, mtimecmp[63:32]))
          end
          else begin
            `ASSERT(wr_data === DUT.mtimecmp_[31:0],
                    ("[CheckWrite]\naddr = 0x%x,\nwr_data = 0x%x,\nDUT.mtime_[31:0] = 0x%x",
                    addr, wr_data, DUT.mtimecmp_[31:0]))

            `ASSERT(wr_data === mtimecmp[31:0],
                    ("[CheckWrite]\naddr = 0x%x,\nrd_data = 0x%x,\nmtimecmp[31:0] = 0x%x",
                    addr, rd_data, mtimecmp[31:0]))
          end
        end
`endif
        default: begin // Nothing to do (addr = 2'b01)
        end
      endcase
    end
  endtask

  // Initial para estimular o DUT
  integer i;
  initial begin
    clock = 1'b0;

    @(negedge clock);
    addr  = $urandom(Seed);  // inicializando a Seed
    reset = 1'b1;
    @(negedge clock);
    addr  = 3'b0;
    reset = 1'b0;

    $display(" SOT: [%0t]", $time);

    for (i = 0; i < AmntOfTests; i = i + 1) begin
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


  always #1 clock = ~clock;

endmodule
