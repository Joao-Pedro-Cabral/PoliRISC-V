
module CSR_mem #(
    parameter integer DATA_SIZE = 64,
    parameter integer CLOCK_CYCLES = 100
) (
    input  logic CLK_I,
    input  logic RST_I,
    input  logic CYC_I,
    input  logic STB_I,
    input  logic WE_I,
    input  logic [2:0] ADR_I,
    input  logic [DATA_SIZE-1:0] DAT_I,
    output logic [DATA_SIZE-1:0] DAT_O,
    output logic ACK_O,
    output logic [DATA_SIZE-1:0] msip,
    output logic [63:0] mtime,
    output logic [63:0] mtimecmp
);

  wire [DATA_SIZE-1:0] msip_;
  wire [63:0] mtime_;
  wire [63:0] mtimecmp_;
  wire tick;
  wire [$clog2(CLOCK_CYCLES)-1:0] cycles;
  wire rd_en, wr_en;
  wire [63:0] mtime_load, mtimecmp_d;

  // Wishbone
  assign rd_en = CYC_I & STB_I & ~WE_I;
  assign wr_en = CYC_I & STB_I & WE_I;

  // Registradores mapeados em memória
  // MSIP
  register_d #(
      .N(DATA_SIZE),
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
      .load_value(mtime_load),
      .inc_enable(tick),
      .dec_enable(1'b0),
      .value(mtime_)
  );
  assign mtime_load = (DATA_SIZE == 64) ? DAT_I :
                      (ADR_I[2] ? {DAT_I, mtime_[31:0]} : {mtime_[63:32], DAT_I});
  sync_parallel_counter #(
      .size($clog2(CLOCK_CYCLES)),
      .init_value(0)
  ) tick_counter (
      .clock(CLK_I),
      .reset(RST_I),
      .load(tick),
      .load_value({$clog2(CLOCK_CYCLES) {1'b0}}),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(cycles)
  );
  // timer roda numa frequência menor -> tick
  assign tick = (cycles == CLOCK_CYCLES - 1);
  //MTIMERCMP
  register_d #(
      .N(64),
      .reset_value(0)
  ) mtimecmp_reg (
      .clock(CLK_I),
      .reset(RST_I),
      .enable((ADR_I[1:0] == 2'b11) && wr_en),
      .D(mtimecmp_d),
      .Q(mtimecmp_)
  );
  assign mtimecmp_d = (DATA_SIZE == 64) ? DAT_I :
                      (ADR_I[2] ? {DAT_I,  mtimecmp_[31:0]} : { mtimecmp_[63:32], DAT_I});
  // Lógica de leitura
  always @(*) begin
    case (ADR_I[1:0])
      2'b00:   DAT_O = msip_;
      2'b10:   DAT_O = (DATA_SIZE == 64) ? mtime_ : (ADR_I[2] ? mtime_[63:32] : mtime_[31:0]);
      2'b11:   DAT_O = (DATA_SIZE == 64) ? mtimecmp_ :
                       (ADR_I[2] ? mtimecmp_[63:32] : mtimecmp_[31:0]);
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
    if (RST_I || ACK_O) ACK_O <= 1'b0;
    else if (_ack) ACK_O <= 1'b1;
  end

endmodule
