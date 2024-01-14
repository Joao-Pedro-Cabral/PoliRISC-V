
`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module CSR_mem #(
    parameter integer ClockCycles = 100
) (
    input wire CLK_I,
    input wire RST_I,
    input wire CYC_I,
    input wire STB_I,
    input wire WE_I,
    input wire [2:0] ADR_I,
    input wire [`DATA_SIZE-1:0] DAT_I,
    output reg [`DATA_SIZE-1:0] DAT_O,
    output reg ACK_O,
    output wire [`DATA_SIZE-1:0] msip,
    output wire [63:0] mtime,
    output wire [63:0] mtimecmp
);

  wire [`DATA_SIZE-1:0] msip_;
  wire [63:0] mtime_;
  wire [63:0] mtimecmp_;
  wire tick;
  wire [$clog2(ClockCycles)-1:0] cycles;
  wire rd_en, wr_en;

  // Wishbone
  assign rd_en = CYC_I & STB_I & ~WE_I;
  assign wr_en = CYC_I & STB_I &  WE_I;

  // Registradores mapeados em memória
  // MSIP
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) msip_reg (
      .clock(CLK_I),
      .reset(RST_I),
      .enable((ADR_I[1:0] == 2'b00) && wr_en),
      .D(DAT_I),
      .Q(msip_)
  );
  // MTIMER
  sync_parallel_counter #(
      .size(64),
      .init_value(0)
  ) mtime_counter (
      .clock(CLK_I),
      .reset(RST_I),
      .load((ADR_I[1:0] == 2'b10) && wr_en),
`ifdef RV64I
      .load_value(DAT_I),
`else
      .load_value(ADR_I[2] ? {DAT_I, mtime_[31:0]} : {mtime_[63:32], DAT_I}),
`endif
      .inc_enable(tick),
      .dec_enable(1'b0),
      .value(mtime_)
  );
  sync_parallel_counter #(
      .size($clog2(ClockCycles)),
      .init_value(0)
  ) tick_counter (
      .clock(CLK_I),
      .reset(RST_I),
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
      .clock(CLK_I),
      .reset(RST_I),
      .enable((ADR_I[1:0] == 2'b11) && wr_en),
`ifdef RV64I
      .D(DAT_I),
`else
      .D(ADR_I[2] ? {DAT_I, mtimecmp_[31:0]} : {mtimecmp_[63:32], DAT_I}),
`endif
      .Q(mtimecmp_)
  );

  // Lógica de leitura
  always @(*) begin
    case (ADR_I[1:0])
      2'b00:   DAT_O = msip_;
`ifdef RV64I
      2'b10:   DAT_O = mtime_;
      2'b11:   DAT_O = mtimecmp_;
`else
      2'b10:   DAT_O = ADR_I[2] ? mtime_[63:32] : mtime_[31:0];
      2'b11:   DAT_O = ADR_I[2] ? mtimecmp_[63:32] : mtimecmp_[31:0];
`endif
      default: DAT_O = 0;
    endcase
  end

  assign msip = msip_;
  assign mtime = mtime_;
  assign mtimecmp = mtimecmp_;

  // Lógica de ACK
  reg _ack;
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I || _ack) _ack <= 1'b0;
    else if (rd_en || wr_en) _ack <= 1'b1;
  end

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) ACK_O <= 1'b0;
    else if (_ack) ACK_O <= 1'b1;
  end

endmodule
