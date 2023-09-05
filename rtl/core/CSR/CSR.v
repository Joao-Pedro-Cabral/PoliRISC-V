
`include "macros.vh"

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
    input wire external_interrupt,
    input wire mem_msip,
    input wire mem_ssip,
    input wire [`DATA_SIZE-1:0] pc,
    input wire [63:0] mem_mtime,
    input wire [63:0] mem_mtimecmp,
    input wire illegal_instruction,
    input wire ecall,
    input wire mret,
    input wire sret,
    output reg [`DATA_SIZE-1:0] rd_data,
    output wire [`DATA_SIZE-1:0] mepc,
    output wire [`DATA_SIZE-1:0] sepc,
    output wire trap,
    output wire [1:0] privilege_mode
);

  // Defines

  // MSTATUS
  localparam integer SIE = 1, MIE = 3, SPIE = 5, MPIE = 7, SPP = 8, MPP = 11, MPRV = 17;
  wire [`DATA_SIZE-1:0] mstatus;
  reg sie, mie, spie, mpie, spp, mprv;
  reg [1:0] mpp;

  // STATUS
  wire [`DATA_SIZE-1:0] sstatus;

  // MIP
  localparam integer SSIP = 1, MSIP = 3, STIP = 5, MTIP = 7, SEIP = 9, MEIP = 11;
  wire [`DATA_SIZE-1:0] mip;

  // SIP
  wire [`DATA_SIZE-1:0] sip;

  // MIE
  localparam integer SSIE = 1, MSIE = 3, STIE = 5, MTIE = 7, SEIE = 9, MEIE = 11;
  wire [`DATA_SIZE-1:0] mie_;

  // SIE
  wire [`DATA_SIZE-1:0] sie_;

  // MEPC
  reg  [`DATA_SIZE-1:0] mepc_;

  // SEPC
  reg  [`DATA_SIZE-1:0] sepc_;

  // MCAUSE
  // Exception Code
  localparam integer SSI = 1, MSI = 3, STI = 5, MTI = 7, SEI = 9, MEI = 11;  // Interrupts
  localparam integer II = 2, ECU = 8, ECS = 9, ECM = 11;  // Exceptions (without ECALL)
  reg [`DATA_SIZE-1:0] mcause;
  wire [`DATA_SIZE-1:0] mcause_async;
  wire [5:0] m_interrupt_vector;  // If bit i is high, so interrupt 2*i + 1 happened
  wire legal_write;  // 1: wr_data[`DATA_SIZE-2:0] has 1 or 0 high bit
  // Trap signals
  wire _trap, sync_trap, async_trap;

  // SCAUSE
  reg [`DATA_SIZE-1:0] scause;

  // PRIV
  reg [1:0] priv;

  // Functions
  // Checks if write to mcause is legal
  function automatic check_mcause_write(input reg interrupt, input reg [`DATA_SIZE-2:0] code);
    begin
      if (interrupt) begin
        case (code)
          SSI: check_mcause_write = 1'b1;
          MSI: check_mcause_write = 1'b1;
          STI: check_mcause_write = 1'b1;
          MTI: check_mcause_write = 1'b1;
          SEI: check_mcause_write = 1'b1;
          MEI: check_mcause_write = 1'b1;
          default: check_mcause_write = 1'b0;
        endcase
      end else begin  // Exception
        case (code)
          II: check_mcause_write = 1'b1;
          ECU: check_mcause_write = 1'b1;
          ECS: check_mcause_write = 1'b1;
          ECM: check_mcause_write = 1'b1;
          default: check_mcause_write = 1'b0;
        endcase
      end
    end
  endfunction

  // Generate exception code for highest priority interrupt
  function automatic [`DATA_SIZE-2:0] gen_cause_async(input reg [5:0] interrupt_vector);
    begin
      // Priority mux
      if (interrupt_vector[5]) gen_cause_async = MEI;
      else if (interrupt_vector[3]) gen_cause_async = MTI;
      else if (interrupt_vector[1]) gen_cause_async = MSI;
      else if (interrupt_vector[4]) gen_cause_async = SEI;
      else if (interrupt_vector[2]) gen_cause_async = STI;
      else if (interrupt_vector[0]) gen_cause_async = SSI;
      else gen_cause_async = 0;
    end
  endfunction

  // Logic

  // MSTATUS
  // Read-only 0 fields
  assign mstatus[`DATA_SIZE-1:MPRV+1] = 0;
  assign mstatus[MPRV-1:MPP+2] = 0;  // MPP is two bits
  assign mstatus[MPP-1:SPP+1] = 0;
  assign {mstatus[SPIE+1], mstatus[MIE+1], mstatus[SIE+1], mstatus[SIE-1]} = 0;
  // WARL fields
  assign mstatus[MIE] = mie;
  assign mstatus[MPIE] = mpie;
  assign mstatus[MPP+1:MPP] = mpp;
  always @(posedge clock, posedge reset) begin
    if (reset) {mie, mpie, mpp} = 0;
    // All traps go to M-Mode
    else if (_trap) begin
      mie  <= 1'b0;
      mpie <= mie;
      mpp  <= priv;
    end else if (mret) begin
      mie  <= mpie;
      mpie <= 1'b1;
      mpp  <= 2'b11;
    end else if (wr_en && (addr == 12'h300)) begin
      mie  <= wr_data[MIE];
      mpie <= wr_data[MPIE];
      if (wr_data[MPP+1:MPP] != 2'b10) mpp <= wr_data[MPP+1:MPP];
    end
  end

  assign mstatus[SIE]  = sie;
  assign mstatus[SPIE] = spie;
  assign mstatus[SPP]  = spp;
  always @(posedge clock, posedge reset) begin
    if (reset) {sie, spie, spp} = 0;
    // No traps go to S-Mode
    else if (!_trap) begin
      if (sret) begin
        sie  <= spie;
        spie <= 1'b1;
        spp  <= 1'b1;
        // Common with S-Mode
      end else if (wr_en && (addr == 12'h300 || addr == 12'h100)) begin
        sie  <= wr_data[SIE];
        spie <= wr_data[SPIE];
        spp  <= wr_data[SPP];
      end
    end
  end

  assign mstatus[MPRV] = mprv;
  always @(posedge clock, posedge reset) begin
    if (reset) mprv <= 1'b0;
    else if (!_trap) begin
      if ((mret && mpp != 2'b11) || sret) mprv <= 1'b0;
      else if (wr_en && (addr == 12'h300)) mprv <= wr_data[MPRV];
    end
  end

  // SSTATUS
  genvar l;
  generate
    for (l = 0; l < `DATA_SIZE; l = l + 1) begin : gen_sstatus
      // hide M-Mode bits for S-Mode
      if (l == MIE || l == MPIE || l == MPP || l == MPP + 1 || l == MPRV) assign sip[l] = 1'b0;
      else assign sip[l] = mip[l];
    end
  endgenerate

  // MIP
  // Read-only 0 fields
  assign mip[`DATA_SIZE-1:MEIE+1] = 0;
  assign {mip[MEIE-1], mip[SEIE-1], mip[MTIE-1], mip[STIE-1], mip[MSIE-1], mip[SSIE-1]} = 0;
  // Read-only (memory-mapped) fields
  assign mip[SSIP] = mem_ssip;
  assign mip[MSIP] = mem_msip;
  assign mip[MTIP] = mem_mtime >= mem_mtimecmp;
  assign mip[MEIP] = external_interrupt;
  // WARL fields
  register_d #(
      .N(2),
      .reset_value(2'b0)
  ) mip_reg (
      .clock(clock),
      .reset(reset),
      // only write in M-Mode
      .enable(!_trap && wr_en && (addr == 12'h344 || addr == 12'h144) && (priv == 2'b11)),
      .D({wr_data[STIP], wr_data[SEIP]}),
      .Q({mip[STIP], mip[SEIP]})
  );

  // SIP
  genvar k;
  generate
    for (k = 0; k < `DATA_SIZE; k = k + 1) begin : gen_sip
      // hide M-Mode bits for S-Mode
      if (k == MSIP || k == MTIP || k == MEIP) assign sip[k] = 1'b0;
      else assign sip[k] = mip[k];
    end
  endgenerate

  // MIE
  // Read-only 0 fields
  assign mie_[`DATA_SIZE-1:MEIE+1] = 0;
  assign {mie_[MEIE-1], mie_[SEIE-1], mie_[MTIE-1], mie_[STIE-1], mie_[MSIE-1], mie_[SSIE-1]} = 0;
  // WARL fields -> Exclusive M-Mode
  register_d #(
      .N(3),
      .reset_value(3'b0)
  ) mie_reg (
      .clock(clock),
      .reset(reset),
      .enable(!_trap && wr_en && (addr == 12'h304)),
      .D({wr_data[MSIE], wr_data[MTIE], wr_data[MEIE]}),
      .Q({mie_[MSIE], mie_[MTIE], mie_[MEIE]})
  );

  // WARL fields -> Common M/S-Mode
  register_d #(
      .N(3),
      .reset_value(3'b0)
  ) sie_reg (
      .clock(clock),
      .reset(reset),
      .enable(!_trap && wr_en && ((addr == 12'h304) || (addr == 12'h104))),
      .D({wr_data[SSIE], wr_data[STIE], wr_data[SEIE]}),
      .Q({mie_[SSIE], mie_[STIE], mie_[SEIE]})
  );

  // SIE
  genvar j;
  generate
    for (j = 0; j < `DATA_SIZE; j = j + 1) begin : gen_sie
      // hide M-Mode bits for S-Mode
      if (j == MSIE || j == MTIE || j == MEIE) assign sie_[j] = 1'b0;
      else assign sie_[j] = mie_[j];
    end
  endgenerate

  // MEPC
  always @(posedge clock, posedge reset) begin
    if (reset) mepc_ <= 0;
    else if (_trap) mepc_ <= pc;  // All traps go to M-Mode
    else if (wr_en && (addr == 12'h341)) mepc_ <= {wr_data[`DATA_SIZE-1:2], 2'b00};
  end
  assign mepc = mepc_;

  // SEPC
  always @(posedge clock, posedge reset) begin
    if (reset) sepc_ <= 0;
    else if (!_trap && (wr_en && (addr == 12'h141))) sepc_ <= {wr_data[`DATA_SIZE-1:2], 2'b00};
  end
  assign sepc = sepc_;

  // MCAUSE
  always @(posedge clock, posedge reset) begin
    if (reset) mcause <= 0;
    else if (async_trap) mcause <= mcause_async;  // All traps are taken in M-Mode
    else if (sync_trap) begin
      if (illegal_instruction) mcause <= II;
      else if (ecall) mcause <= {2'b10, priv};  // ECU, ECS or ECM
    end else if (legal_write && wr_en && (addr == 12'h342)) mcause <= wr_data;  // WLRL
  end
  assign legal_write = check_mcause_write(mcause[`DATA_SIZE-1], mcause[`DATA_SIZE-2:0]);
  // Trap
  assign trap = _trap;
  assign _trap = async_trap | sync_trap;
  // Async Traps
  assign async_trap = |(mcause_async[`DATA_SIZE-2:0]);
  genvar i;
  generate
    // Maps interrupt code 2*i + 1 to interrupt vector bit i
    for (i = 0; i < 6; i = i + 1) begin : gen_interrupt_vector
      if (i % 2 == 1)
        assign m_interrupt_vector[i] = mie_[2*i+1] & mip[2*i+1] & (!priv[1] | mstatus[MIE]);
      else
        assign m_interrupt_vector[i] = mie_[2*i+1] & mip[2*i+1] & ((!priv[1] & !priv[0]) | mstatus[SIE]);
    end
  endgenerate
  assign mcause_async = {1'b1, gen_cause_async(m_interrupt_vector)};
  // Sync Traps
  assign sync_trap = illegal_instruction | ecall;

  // SCAUSE
  always @(posedge clock, posedge reset) begin
    if (reset) scause <= 0;
    else if (legal_write && wr_en && (addr == 12'h142)) scause <= wr_data;  // WLRL
  end

  // PRIV
  assign privilege_mode = priv;
  always @(posedge clock, posedge reset) begin
    if (reset) priv <= 2'b11;  // M-Mode
    else begin
      if (_trap) priv <= 2'b11;  // No support to mideleg/medeleg
      else if (mret) priv <= mstatus[MPP+1:MPP];
      else if (sret) priv <= {1'b0, mstatus[SPP]};
    end
  end

  // read data
  always @(*) begin
    case (addr)
      12'h100: rd_data = sstatus;
      12'h104: rd_data = sie_;
      12'h141: rd_data = sepc_;
      12'h142: rd_data = scause;
      12'h144: rd_data = sip;
      12'h300: rd_data = mstatus;
      12'h304: rd_data = mie_;
      12'h341: rd_data = mepc_;
      12'h342: rd_data = mcause;
      12'h344: rd_data = mip;
      default: rd_data = 0;
    endcase
  end

endmodule
