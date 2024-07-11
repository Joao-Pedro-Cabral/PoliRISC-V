
module csr_mem #(
    parameter integer DATA_SIZE = 64,
    parameter integer CLOCK_CYCLES = 100
) (
    wishbone_if.secondary wb_if_s,
    output logic [DATA_SIZE-1:0] msip,
    output logic [63:0] mtime,
    output logic [63:0] mtimecmp
);

  import csr_mem_pkg::*;

  logic [DATA_SIZE-1:0] msip_;
  logic [63:0] mtime_;
  logic [63:0] mtimecmp_;
  logic tick;
  logic [$clog2(CLOCK_CYCLES)-1:0] cycles;
  logic rd_en, wr_en;
  logic [63:0] mtime_load, mtimecmp_d;
  logic ack;

  // Wishbone
  always_comb begin
    rd_en = wb_if_s.rd_en();
    wr_en = wb_if_s.wr_en();
  end

  // Registradores mapeados em memória
  // MSIP
  register_d #(
      .N(DATA_SIZE),
      .reset_value(0)
  ) msip_reg (
      .clock(wb_if_s.clock),
      .reset(wb_if_s.reset),
      .enable((wb_if_s.addr[5:4] == Msip) && wr_en && ack),
      .D(wb_if_s.dat_i_s),
      .Q(msip_)
  );
  // MTIME
  sync_parallel_counter #(
      .size(64),
      .init_value(0)
  ) mtime_counter (
      .clock(wb_if_s.clock),
      .reset(wb_if_s.reset),
      .load((wb_if_s.addr[5:4] == Mtime) && wr_en && ack),
      .load_value(mtime_load),
      .inc_enable(tick),
      .dec_enable(1'b0),
      .value(mtime_)
  );
  assign mtime_load = (DATA_SIZE == 64) ? wb_if_s.dat_i_s :
                      (wb_if_s.addr[6] ? {wb_if_s.dat_i_s, mtime_[31:0]} :
                      {mtime_[63:32], wb_if_s.dat_i_s});
  sync_parallel_counter #(
      .size($clog2(CLOCK_CYCLES)),
      .init_value(0)
  ) tick_counter (
      .clock(wb_if_s.clock),
      .reset(wb_if_s.reset),
      .load(tick),
      .load_value({$clog2(CLOCK_CYCLES) {1'b0}}),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(cycles)
  );
  // timer roda numa frequência menor -> tick
  assign tick = (cycles == CLOCK_CYCLES - 1);
  //MTIMECMP
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtimecmp_reg (
      .clock(wb_if_s.clock),
      .reset(wb_if_s.reset),
      .enable((wb_if_s.addr[5:4] == Mtimecmp) && wr_en && ack),
      .D(mtimecmp_d),
      .Q(mtimecmp_)
  );
  assign mtimecmp_d = (DATA_SIZE == 64) ? wb_if_s.dat_i_s :
                      (wb_if_s.addr[6] ? {wb_if_s.dat_i_s,  mtimecmp_[31:0]} :
                      { mtimecmp_[63:32], wb_if_s.dat_i_s});
  // Lógica de leitura
  always_comb begin
    case (wb_if_s.addr[5:4])
      Msip: wb_if_s.dat_o_s = msip_;
      Mtime:
      wb_if_s.dat_o_s = (DATA_SIZE == 64) ? mtime_ :
                       (wb_if_s.addr[6] ? mtime_[63:32] : mtime_[31:0]);
      Mtimecmp:
      wb_if_s.dat_o_s = (DATA_SIZE == 64) ? mtimecmp_ :
                       (wb_if_s.addr[6] ? mtimecmp_[63:32] : mtimecmp_[31:0]);
      default: wb_if_s.dat_o_s = 0;
    endcase
  end

  assign msip = msip_;
  assign mtime = mtime_;
  assign mtimecmp = mtimecmp_;

  // Lógica de ACK
  always @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (wb_if_s.reset || ack) ack <= 1'b0;
    else if (rd_en || wr_en) ack <= 1'b1;
  end

  assign wb_if_s.ack = ack;

endmodule
