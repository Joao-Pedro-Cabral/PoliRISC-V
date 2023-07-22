
`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module CSR (
    input wire clock,
    input wire reset,
    input wire wr_en,
    input wire [11:0] addr,
    input wire [`DATA_SIZE-1:0] wr_data,
    output wire [`DATA_SIZE-1:0] rd_data
);

wire [63:0] mtime;
wire mtime_clock;

// mtime
  sync_parallel_counter #(
      .size(64),
      .init_value(0)
  ) mtime_reg (
      .clock(mtime_clock),
      .load(1'b0),
      .load_value(64'd0),
      .reset(reset),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(bits_sent)
  );

endmodule
