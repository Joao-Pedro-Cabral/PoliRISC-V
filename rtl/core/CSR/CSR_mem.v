
`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module CSR_mem #(
    parameter integer ClockCycles = 100
) (
    input wire clock,
    input wire reset,
    input wire rd_en,
    input wire wr_en,
    input wire [2:0] addr,
    input wire [`DATA_SIZE-1:0] wr_data,
    output reg [`DATA_SIZE-1:0] rd_data,
    output wire busy,
    output wire [`DATA_SIZE-1:0] msip,
    output wire [`DATA_SIZE-1:0] ssip,
    output wire [63:0] mtime,
    output wire [63:0] mtimecmp
);

  wire [`DATA_SIZE-1:0] msip_;
  wire [`DATA_SIZE-1:0] ssip_;
  wire [63:0] mtime_;
  wire [63:0] mtimecmp_;
  wire tick;
  wire [$clog2(ClockCycles)-1:0] cycles;

  // Registradores mapeados em memória
  // MSIP
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) msip_reg (
      .clock(clock),
      .reset(reset),
      .enable((addr[1:0] == 2'b00) && wr_en),
      .D(wr_data),
      .Q(msip_)
  );
  // SSIP
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) ssip_reg (
      .clock(clock),
      .reset(reset),
      .enable((addr[1:0] == 2'b01) && wr_en),
      .D(wr_data),
      .Q(ssip_)
  );
  // MTIMER
  sync_parallel_counter #(
      .size(64),
      .init_value(0)
  ) mtime_counter (
      .clock(clock),
      .reset(reset),
      .load((addr[1:0] == 2'b10) && wr_en),
`ifdef RV64I
      .load_value(wr_data),
`else
      .load_value(addr[2] ? {wr_data, 32'b0} : {32'b0, wr_data}),
`endif
      .inc_enable(tick),
      .dec_enable(1'b0),
      .value(mtime_)
  );
  sync_parallel_counter #(
      .size($clog2(ClockCycles)),
      .init_value(0)
  ) tick_counter (
      .clock(clock),
      .reset(reset),
      .load(tick),
      .load_value({$clog2(ClockCycles) {1'b0}}),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(cycles)
  );
  // timer roda numa frequência menor -> tick
  assign tick = (cycles == ClockCycles - 1);
  //MTIMERCMP
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtimecmp_reg (
      .clock(clock),
      .reset(reset),
      .enable((addr[1:0] == 2'b11) && wr_en),
`ifdef RV64I
      .D(wr_data),
`else
      .D(addr[2] ? {wr_data, 32'b0} : {32'b0, wr_data}),
`endif
      .Q(mtimecmp_)
  );

  // Lógica de leitura
  always @(*) begin
    case (addr[1:0])
      2'b00:   rd_data = msip_;
      2'b01:   rd_data = ssip_;
`ifdef RV64I
      2'b10:   rd_data = mtime_;
      default: rd_data = mtimecmp_;
`else
      2'b10:   rd_data = addr[2] ? mtime_[63:32] : mtime_[31:0];
      default: rd_data = addr[2] ? mtimecmp_[63:32] : mtimecmp_[31:0];
`endif
    endcase
  end

  assign msip = msip_;
  assign ssip = ssip_;
  assign mtime = mtime_;
  assign mtimecmp = mtimecmp_;

  // Lógica de busy
  reg _busy;
  always @(posedge clock, posedge reset) begin
    if (reset || _busy) _busy <= 1'b0;
    else if (rd_en || wr_en) _busy <= 1'b1;
  end

  assign busy = _busy;

endmodule
