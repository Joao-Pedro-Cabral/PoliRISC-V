

`ifdef RV64I
`define DATA_SIZE 64
`else
`define DATA_SIZE 32
`endif

module CSR_mem (
    input wire clock,
    input wire reset,
    input wire msip_en,
    input wire ssip_en,
    input wire mtime_en,
    input wire mtimecmp_en,
    input wire high_addr,
    input wire [`DATA_SIZE-1:0] wr_data,
    output wire [`DATA_SIZE-1:0] msip,
    output wire [`DATA_SIZE-1:0] ssip,
    output wire [63:0] mtime,
    output wire [63:0] mtimecmp,
    output wire busy
);

  // Registradores mapeados em memória
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) msip_reg (
      .clock(clock),
      .reset(reset),
      .enable(msip_en),
      .D(wr_data),
      .Q(msip)
  );
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) ssip_reg (
      .clock(clock),
      .reset(reset),
      .enable(ssip_en),
      .D(wr_data),
      .Q(ssip)
  );
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtime_reg (
      .clock(clock),
      .reset(reset),
      .enable(mtime_en),
`ifdef RV64I
      .D(wr_data),
`else
      .D(high_addr ? {wr_data, 32'b0} : {32'b0, wr_data}),
`endif
      .Q(mtime)
  );
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtimecmp_reg (
      .clock(clock),
      .reset(reset),
      .enable(mtimecmp_en),
`ifdef RV64I
      .D(wr_data),
`else
      .D(high_addr ? {wr_data, 32'b0} : {32'b0, wr_data}),
`endif
      .Q(mtimecmp)
  );

  // Lógica de busy
  reg _busy;
  always @(posedge clock, posedge reset) begin
    if (reset || _busy) _busy <= 1'b0;
    else if (msip_en || ssip_en || mtime_en || mtimecmp_en) _busy <= 1'b1;
  end

  assign busy = _busy;

endmodule
