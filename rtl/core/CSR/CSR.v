
// Note: Privilege checks is made in UC
// Note: Never writes in CSR if a trap happened
// Note: mret/sret + wr_en is a invalid input

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
    input wire [31:0] instruction,
    input wire [63:0] mem_mtime,
    input wire [63:0] mem_mtimecmp,
    input wire illegal_instruction,
    input wire ecall,
    input wire mret,
    input wire sret,
    output reg [`DATA_SIZE-1:0] rd_data,
    output reg addr_exception,
    output wire [`DATA_SIZE-1:0] mepc,
    output wire [`DATA_SIZE-1:0] sepc,
    output wire [`DATA_SIZE-1:0] trap_addr,
    output wire trap,
    output wire [1:0] privilege_mode
);

  // Defines

  // Control Logic
  wire wr_en_, mret_, sret_;

  // MSTATUS
  localparam integer SIE = 1, MIE = 3, SPIE = 5, MPIE = 7, SPP = 8, MPP = 11;
  wire [`DATA_SIZE-1:0] mstatus;
  reg sie, mie, spie, mpie, spp;
  reg [1:0] mpp;

  // SSTATUS
  wire [`DATA_SIZE-1:0] sstatus;

  // MISA
  wire [`DATA_SIZE-1:0] misa;

  // MTVEC
  wire [`DATA_SIZE-1:0] mtvec;

  // STVEC
  wire [`DATA_SIZE-1:0] stvec;

  // MIDELEG
  wire [`DATA_SIZE-1:0] mideleg;

  // MEDELEG
  wire [`DATA_SIZE-1:0] medeleg;

  // MIP
  localparam integer SSIP = 1, MSIP = 3, STIP = 5, MTIP = 7, SEIP = 9, MEIP = 11;
  wire [`DATA_SIZE-1:0] mip;  // read mip
  wire [`DATA_SIZE-1:0] mip_;  // interrupt mip (!= SEIP)

  // SIP
  wire [`DATA_SIZE-1:0] sip;

  // MIE
  localparam integer SSIE = 1, MSIE = 3, STIE = 5, MTIE = 7, SEIE = 9, MEIE = 11;
  wire [`DATA_SIZE-1:0] mie_;

  // SIE
  wire [`DATA_SIZE-1:0] sie_;

  // MSCRATCH
  wire [`DATA_SIZE-1:0] mscratch;

  // SSCRATCH
  wire [`DATA_SIZE-1:0] sscratch;

  // MEPC
  reg  [`DATA_SIZE-1:0] mepc_;

  // SEPC
  reg  [`DATA_SIZE-1:0] sepc_;

  // MCAUSE
  // Exception Code
  localparam integer SSI = 1, MSI = 3, STI = 5, MTI = 7, SEI = 9, MEI = 11;  // Interrupts
  localparam integer II = 2, ECU = 8, ECS = 9, ECM = 11;  // Exceptions
  reg [`DATA_SIZE-1:0] mcause;
  reg [`DATA_SIZE-1:0] cause_async, cause_sync;
  wire [`DATA_SIZE-1:0] cause;
  wire [5:0] interrupt_vector;  // If bit i is high, so interrupt 2*i + 1 happened
  wire [3:0] exception_vector;  // 3: ECM, 2: ECS, 1: ECU, 0: II
  wire m_legal_write;  // check if wr_data is valid for mcause
  wire s_legal_write;  // check if wr_data is valid for scause
  // Trap signals
  wire _trap, sync_trap, async_trap;
  reg m_trap, s_trap;
  wire [`DATA_SIZE-1:0] m_trap_addr, s_trap_addr;
  wire [`DATA_SIZE-3:0] m_trap_addr_vet, s_trap_addr_vet;

  // SCAUSE
  reg [`DATA_SIZE-1:0] scause;

  // MTVAL
  reg [`DATA_SIZE-1:0] mtval;

  // STVAL
  reg [`DATA_SIZE-1:0] stval;

  // PRIV
  reg [1:0] priv;

  // Functions
  // Checks if write to mcause is legal
  function automatic check_cause_write(input reg [`DATA_SIZE-1:0] cause, input reg is_mcause);
    reg interrupt;
    reg [`DATA_SIZE-2:0] code;
    begin
      interrupt = cause[`DATA_SIZE-1];
      code = cause[`DATA_SIZE-2:0];
      if (interrupt) begin
        case (code)
          SSI: check_cause_write = 1'b1;
          MSI: check_cause_write = 1'b1;
          STI: check_cause_write = 1'b1;
          MTI: check_cause_write = 1'b1;
          SEI: check_cause_write = 1'b1;
          MEI: check_cause_write = 1'b1;
          default: check_cause_write = 1'b0;
        endcase
      end else begin  // Exception
        case (code)
          II: check_cause_write = 1'b1;
          ECU: check_cause_write = 1'b1;
          ECS: check_cause_write = 1'b1;
          // ECM is available only in mcause
          ECM: check_cause_write = is_mcause;
          default: check_cause_write = 1'b0;
        endcase
      end
    end
  endfunction

  // Logic

  // Control Logic (Mask Inputs)
  assign mret_ = mret & !_trap;
  assign sret_ = sret & !mret & !_trap;
  assign wr_en_ = wr_en & !sret & !mret & !_trap;

  // MSTATUS
  // Read-only 0 fields
  assign mstatus[`DATA_SIZE-1:MPP+2] = 0;  // MPP is two bits
  assign mstatus[MPP-1:SPP+1] = 0;
  assign {mstatus[SPIE+1], mstatus[MIE+1], mstatus[SIE+1], mstatus[SIE-1]} = 0;
  // WARL fields
  assign mstatus[MIE] = mie;
  assign mstatus[MPIE] = mpie;
  assign mstatus[MPP+1:MPP] = mpp;
  always @(posedge clock, posedge reset) begin
    if (reset) {mie, mpie, mpp} = 0;
    else if (m_trap) begin
      mie  <= 1'b0;
      mpie <= mie;
      mpp  <= priv;
    end else if (mret_) begin
      mie  <= mpie;
      mpie <= 1'b1;
      mpp  <= 2'b00;
    end else if (wr_en_ && (addr == 12'h300)) begin
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
    else if (s_trap) begin
      sie  <= 1'b0;
      spie <= sie;
      spp  <= priv[0];
    end else if (sret_) begin
      sie  <= spie;
      spie <= 1'b1;
      spp  <= 1'b0;
      // Common with S-Mode
    end else if (wr_en_ && (addr == 12'h300 || addr == 12'h100)) begin
      sie  <= wr_data[SIE];
      spie <= wr_data[SPIE];
      spp  <= wr_data[SPP];
    end
  end

  // SSTATUS
  genvar l;
  generate
    for (l = 0; l < `DATA_SIZE; l = l + 1) begin : gen_sstatus
      // hide M-Mode bits for S-Mode
      if (l == MIE || l == MPIE || l == MPP || l == MPP + 1) assign sstatus[l] = 1'b0;
      else assign sstatus[l] = mstatus[l];
    end
  endgenerate

  // MISA
  assign misa[`DATA_SIZE-1:`DATA_SIZE-2] = `DATA_SIZE / 32;
  assign misa[`DATA_SIZE-3:26] = 0;
  assign misa[25:0] = 26'h1400100;  // U, S implementados + RV64I

  // MTVEC
  assign mtvec[1] = 1'b0;  // Reserved
  register_d #(
      .N(`DATA_SIZE - 1),
      .reset_value(0)
  ) mtvec_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h305)),
      .D({wr_data[`DATA_SIZE-1:2], wr_data[0]}),
      .Q({mtvec[`DATA_SIZE-1:2], mtvec[0]})
  );

  // STVEC
  assign stvec[1] = 1'b0;  // Reserved
  register_d #(
      .N(`DATA_SIZE - 1),
      .reset_value(0)
  ) stvec_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h105)),
      .D({wr_data[`DATA_SIZE-1:2], wr_data[0]}),
      .Q({stvec[`DATA_SIZE-1:2], stvec[0]})
  );

  // MIDELEG
  // Read-only 0 fields
  assign mideleg[`DATA_SIZE-1:SEI+1] = 0;
  assign {mideleg[SEI-1:STI+1], mideleg[STI-1:SSI+1], mideleg[SSI-1]} = 0;
  // WARL fields
  register_d #(
      .N(3),
      .reset_value(3'b0)
  ) mideleg_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h303)),
      .D({wr_data[SSI], wr_data[STI], wr_data[SEI]}),
      .Q({mideleg[SSI], mideleg[STI], mideleg[SEI]})
  );

  // MEDELEG
  assign {medeleg[`DATA_SIZE-1:ECS-1], medeleg[ECU-1:II+1], medeleg[II-1:0]} = 0;
  // WARL fields
  register_d #(
      .N(3),
      .reset_value(3'b0)
  ) medeleg_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h302)),
      .D({wr_data[ECS], wr_data[ECU], wr_data[II]}),
      .Q({medeleg[ECS], medeleg[ECU], medeleg[II]})
  );

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
      .enable(wr_en_ && addr == 12'h344),  // only writes in M-Mode
      .D({wr_data[STIP], wr_data[SEIP]}),
      .Q({mip[STIP], mip[SEIP]})
  );
  assign mip_[`DATA_SIZE-1:SEIP+1] = mip[`DATA_SIZE-1:SEIP+1];
  assign mip_[SEIP] = mip[SEIP] | external_interrupt;
  assign mip_[SEIP-1:0] = mip[SEIP-1:0];

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
      .enable(wr_en_ && (addr == 12'h304)),
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
      .enable(wr_en_ && ((addr == 12'h304) || (addr == 12'h104))),
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

  // MSCRATCH
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) mscratch_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h340)),
      .D(wr_data),
      .Q(mscratch)
  );

  // SSCRATCH
  register_d #(
      .N(`DATA_SIZE),
      .reset_value(0)
  ) sscratch_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (addr == 12'h140)),
      .D(wr_data),
      .Q(sscratch)
  );

  // MEPC
  always @(posedge clock, posedge reset) begin
    if (reset) mepc_ <= 0;
    else if (m_trap) mepc_ <= pc;
    else if (wr_en_ && (addr == 12'h341)) mepc_ <= {wr_data[`DATA_SIZE-1:2], 2'b00};
  end
  assign mepc = mepc_;

  // SEPC
  always @(posedge clock, posedge reset) begin
    if (reset) sepc_ <= 0;
    else if (s_trap) sepc_ <= pc;
    else if (wr_en_ && (addr == 12'h141)) sepc_ <= {wr_data[`DATA_SIZE-1:2], 2'b00};
  end
  assign sepc = sepc_;

  // MCAUSE
  always @(posedge clock, posedge reset) begin
    if (reset) mcause <= 0;
    else if (m_trap) mcause <= cause;
    else if (m_legal_write && wr_en_ && (addr == 12'h342)) mcause <= wr_data;  // WLRL
  end
  assign m_legal_write = check_cause_write(wr_data, 1'b1);

  // SCAUSE
  always @(posedge clock, posedge reset) begin
    if (reset) scause <= 0;
    else if (s_trap) scause <= cause;
    else if (s_legal_write && wr_en_ && (addr == 12'h142)) scause <= wr_data;  // WLRL
  end
  assign s_legal_write = check_cause_write(wr_data, 1'b0);

  // MTVAL
  always @(posedge clock, posedge reset) begin
    if (reset) mtval <= 0;
    //  Store Illegal Instruction
    else if (m_trap && !async_trap && sync_trap && illegal_instruction) mtval <= instruction;
    else if (wr_en_ && (addr == 12'h343)) mtval <= wr_data;
  end

  // STVAL
  always @(posedge clock, posedge reset) begin
    if (reset) stval <= 0;
    //  Store Illegal Instruction
    else if (s_trap && !async_trap && sync_trap && illegal_instruction) stval <= instruction;
    else if (wr_en_ && (addr == 12'h143)) stval <= wr_data;
  end

  // PRIV
  assign privilege_mode = priv;
  always @(posedge clock, posedge reset) begin
    if (reset) priv <= 2'b11;  // M-Mode
    else if (m_trap) priv <= 2'b11;
    else if (s_trap) priv <= 2'b01;
    else if (mret) priv <= mstatus[MPP+1:MPP];
    else if (sret) priv <= {1'b0, mstatus[SPP]};
  end

  // read data
  always @(*) begin
    rd_data = 0;
    addr_exception = 1'b0;
    case (addr)
      12'h100: rd_data = sstatus;
      12'h104: rd_data = sie_;
      12'h105: rd_data = stvec;
      12'h140: rd_data = sscratch;
      12'h141: rd_data = sepc_;
      12'h142: rd_data = scause;
      12'h143: rd_data = stval;
      12'h144: rd_data = sip;
      12'h300: rd_data = mstatus;
      12'h301: rd_data = misa;
      12'h302: rd_data = medeleg;
      12'h303: rd_data = mideleg;
      12'h304: rd_data = mie_;
      12'h305: rd_data = mtvec;
      12'h340: rd_data = mscratch;
      12'h341: rd_data = mepc_;
      12'h342: rd_data = mcause;
      12'h343: rd_data = mtval;
      12'h344: rd_data = mip;
      default: addr_exception = 1'b1;
    endcase
  end

  // Trap
  // Interrupt Vector
  genvar i;
  generate
    // Maps interrupt code 2*i + 1 to interrupt vector bit i
    for (i = 0; i < 6; i = i + 1) begin : gen_interrupt_vector
      if (i % 2 == 1)  // MEI, MTI, MSI: U, S -> Always Enabled, M -> MIE
        assign interrupt_vector[i] = mie_[2*i+1] & mip_[2*i+1] &
            ((!priv[1]) | (priv[0] & mstatus[MIE]));
      // SEI, STI, SSI: U -> Always Enabled, S -> SIE or !mideleg, M -> MIE
      else
        assign interrupt_vector[i] = mie_[2*i+1] & mip_[2*i+1] & ((!priv[1] & !priv[0]) |
            (!priv[1] & (!mideleg[2*i+1] | mstatus[SIE])) | (priv[0] & priv[1] & mstatus[MIE]));
    end
  endgenerate
  // Exception Vector
  assign exception_vector[0] = illegal_instruction & ((!priv[1] & !priv[0]) |
            (!priv[1] & (!mideleg[2] | mstatus[SIE])) | (priv[0] & priv[1] & mstatus[MIE])); // II
  assign exception_vector[1] = ecall & !priv[0] & !priv[1];  // ECU
  assign exception_vector[2] = ecall & priv[0] & !priv[1] & (!medeleg[9] | mstatus[SIE]);  // ECS
  assign exception_vector[3] = ecall & priv[0] & priv[1] & mstatus[MIE];  // ECM
  // Trap
  assign async_trap = |(interrupt_vector);
  assign sync_trap = |(exception_vector);
  always @(*) begin : trap_calc
    cause_async = 0;
    cause_sync = 0;
    m_trap = 0;
    s_trap = 0;
    // 1st Priority Mux
    // M-Trap: M-Mode AND !mi(e)deleg[i]
    // S-Trap: !M-Mode AND mi(e)deleg[i]
    if (interrupt_vector[5]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = MEI;
      m_trap = !mideleg[MEI];
      s_trap = mideleg[MEI];
    end else if (interrupt_vector[3]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = MTI;
      m_trap = !mideleg[MTI];
      s_trap = mideleg[MTI];
    end else if (interrupt_vector[1]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = MSI;
      m_trap = !mideleg[MSI];
      s_trap = mideleg[MSI];
    end else if (interrupt_vector[4]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = SEI;
      m_trap = !mideleg[SEI];
      s_trap = mideleg[SEI];
    end else if (interrupt_vector[2]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = STI;
      m_trap = !mideleg[STI];
      s_trap = mideleg[STI];
    end else if (interrupt_vector[0]) begin
      cause_async[`DATA_SIZE-1] = 1'b1;
      cause_async[`DATA_SIZE-2:0] = SSI;
      m_trap = !mideleg[SSI];
      s_trap = mideleg[SSI];
    end else if (exception_vector[0]) begin
      m_trap = !medeleg[II];
      s_trap = medeleg[II];
    end else if (exception_vector[1]) begin
      m_trap = !medeleg[ECU];
      s_trap = medeleg[ECU];
    end else if (exception_vector[2]) begin
      m_trap = !medeleg[ECS];
      s_trap = medeleg[ECS];
    end else if (exception_vector[3]) begin
      m_trap = !medeleg[ECM];
      s_trap = medeleg[ECM];
    end
    // 2nd Priority Mux -> Exclusive for cause_sync -> Decrease Critical Path
    if (exception_vector[0]) cause_sync = II;
    else if (|exception_vector[3:1]) cause_sync = {2'b10, priv};
  end
  assign cause = async_trap ? cause_async : cause_sync;  // Interrupt > Exception
  assign _trap = m_trap | s_trap;
  assign trap = _trap;

  // Trap Address
  // M-Trap Address
  assign m_trap_addr[1:0] = 2'b00;
  assign m_trap_addr[`DATA_SIZE-1:2] = (mtvec[0] && async_trap) ? m_trap_addr_vet
                                                                : mtvec[`DATA_SIZE-1:2];
  sklansky_adder #(
      .INPUT_SIZE(`DATA_SIZE - 2)
  ) m_trap_addr_vet_adder (
      .A(mtvec[`DATA_SIZE-1:2]),
      .B(cause_async[`DATA_SIZE-3:0]),  // MSb -> overflow
      .c_in(1'b0),
      .c_out(),
      .S(m_trap_addr_vet)
  );
  // S-Trap Address
  assign s_trap_addr[1:0] = 2'b00;
  assign s_trap_addr[`DATA_SIZE-1:2] = (stvec[0] && async_trap) ? s_trap_addr_vet
                                                                : stvec[`DATA_SIZE-1:2];
  sklansky_adder #(
      .INPUT_SIZE(`DATA_SIZE - 2)
  ) s_trap_addr_vet_adder (
      .A(stvec[`DATA_SIZE-1:2]),
      .B(cause_async[`DATA_SIZE-3:0]),  // MSb -> overflow
      .c_in(1'b0),
      .c_out(),
      .S(s_trap_addr_vet)
  );
  // Real Trap Address
  assign trap_addr = m_trap ? m_trap_addr : s_trap_addr;

endmodule
