
`include "macros.vh"

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module CSR_mem (
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

  // Registradores mapeados em memória
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
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtime_reg (
      .clock(clock),
      .reset(reset),
      .enable((addr[1:0] == 2'b10) && wr_en),
`ifdef RV64I
      .D(wr_data),
`else
      .D(addr[2] ? {wr_data, 32'b0} : {32'b0, wr_data}),
`endif
      .Q(mtime_)
  );
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
