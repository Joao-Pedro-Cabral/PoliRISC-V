
// Note: Never writes in CSR if a trap happened

import csr_pkg::*;

module csr #(
    parameter integer DATA_SIZE = 64
) (
    input logic clock,
    input logic reset,
    input logic en,
    input csr_op_t csr_op,
    input logic [11:0] rd_addr,
    input logic [11:0] wr_addr,
    input logic [DATA_SIZE-1:0] wr_data,
    input logic external_interrupt,
    input logic msip,
    input logic [DATA_SIZE-1:0] interrupt_pc,
    input logic [DATA_SIZE-1:0] exception_pc,
    input logic [31:0] instruction,
    input logic [63:0] mtime,
    input logic [63:0] mtimecmp,
    output logic [DATA_SIZE-1:0] rd_data,
    output logic [DATA_SIZE-1:0] mepc,
    output logic [DATA_SIZE-1:0] sepc,
    output logic [DATA_SIZE-1:0] trap_addr,
    output logic trap,
    output logic exception,
    output privilege_mode_t privilege_mode
);

  // Defines

  // Control Logic
  logic wr_en_, mret_, sret_;

  // Exceptions
  logic ecall, addr_exception, illegal_instruction;

  // CSR
  logic [DATA_SIZE-1:0]
      mstatus,
      sstatus,
      misa,
      mvendorid,
      marchid,
      mimpid,
      mhartid,
      mtvec,
      stvec,
      mideleg,
      medeleg,
      mip,
      sip,
      mie_,
      sie_,
      mscratch,
      sscratch,
      mepc_,
      sepc_,
      mcause,
      scause,
      mtval,
      stval;

  // MCAUSE Au
  // Exception Code
  logic [DATA_SIZE-1:0] cause, cause_async, cause_sync;
  // Trap signals
  logic _trap, sync_trap, async_trap, m_trap, s_trap;
  logic [DATA_SIZE-1:0] m_trap_addr, s_trap_addr;

  // PRIV
  privilege_mode_t priv;

  // Functions
  // Checks if write to mcause is legal
  function automatic logic check_cause_write(input reg [DATA_SIZE-1:0] cause, input reg is_mcause);
    reg interrupt;
    interrupt_t code;
    begin
      interrupt = cause[DATA_SIZE-1];
      code = interrupt_t'(cause[DATA_SIZE-2:0]);
      if (interrupt) return code inside {SSI, MSI, STI, MTI, SEI, MEI};
      else begin  // Exception
        if (is_mcause) return code inside {II, ECU, ECS, ECM};
        else return code inside {II, ECU, ECS};
      end
    end
  endfunction

  // Logic

  // Control Logic (Mask Inputs)
  assign mret_  = (csr_op == CsrMret) & en & !_trap;
  assign sret_  = (csr_op == CsrSret) & en & !_trap;
  assign wr_en_ = (csr_op inside {CsrRW, CsrRS, CsrRC}) & en & !_trap;

  // Exceptions
  assign illegal_instruction = (csr_op == CsrIllegalInstruction) ||
                               (csr_op inside {CsrRW, CsrRS, CsrRC} && addr_exception);
  assign ecall = (csr_op == CsrEcall);

  // XSTATUS
  logic sie, mie, spie, mpie, spp;
  privilege_mode_t mpp;
  assign mstatus = '{
          SIE: sie,
          MIE: mie,
          SPIE: spie,
          MPIE: mpie,
          SPP: spp,
          MPP + 1: mpp[1],
          MPP: mpp,
          default: 0
      };
  assign sstatus = '{SIE: sie, SPIE: spie, SPP: spp, default: 0};
  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      {mie, mpie} <= 0;
      mpp <= Machine;
    end else if (m_trap) begin
      mie  <= 1'b0;
      mpie <= mie;
      mpp  <= priv;
    end else if (mret_) begin
      mie  <= mpie;
      mpie <= 1'b1;
      mpp  <= Machine;
    end else if (wr_en_ && (wr_addr == Mstatus)) begin
      mie  <= wr_data[MIE];
      mpie <= wr_data[MPIE];
      if (wr_data[MPP+1:MPP] != 2'b10) mpp <= privilege_mode_t'(wr_data[MPP+1:MPP]);
    end
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) {sie, spie, spp} <= 0;
    else if (s_trap) begin
      sie  <= 1'b0;
      spie <= sie;
      spp  <= priv[0];
    end else if (sret_) begin
      sie  <= spie;
      spie <= 1'b1;
      spp  <= 1'b0;
      // Common with S-Mode
    end else if (wr_en_ && (wr_addr inside {Mstatus, Sstatus})) begin
      sie  <= wr_data[SIE];
      spie <= wr_data[SPIE];
      spp  <= wr_data[SPP];
    end
  end

  // MISA
  assign misa[DATA_SIZE-1:DATA_SIZE-2] = DATA_SIZE / 32;
  assign misa[DATA_SIZE-3:0] = 26'h1401100;  // U, S implementados + RV64I

  // MVENDORID
  assign mvendorid = 0;  // non-commercial implementation

  // MARCHID
  assign marchid = 0;

  // MIMPID
  assign mimpid = 0;

  // MHARTID
  assign mhartid = 0;  // no threads

  // MTVEC
  assign mtvec[1] = 1'b0;  // Reserved
  register_d #(
      .N(DATA_SIZE - 1),
      .reset_value(0)
  ) mtvec_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (wr_addr == Mtvec)),
      .D({wr_data[DATA_SIZE-1:2], wr_data[0]}),
      .Q({mtvec[DATA_SIZE-1:2], mtvec[0]})
  );

  // STVEC
  assign stvec[1] = 1'b0;  // Reserved
  register_d #(
      .N(DATA_SIZE - 1),
      .reset_value(0)
  ) stvec_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (wr_addr == Stvec)),
      .D({wr_data[DATA_SIZE-1:2], wr_data[0]}),
      .Q({stvec[DATA_SIZE-1:2], stvec[0]})
  );

  // MIDELEG
  always_ff @(posedge clock, posedge reset) begin
    if (reset) mideleg <= 0;
    else if (wr_en_ && (wr_addr == Mideleg))
      mideleg <= '{SSI: wr_data[SSI], STI: wr_data[STI], SEI: wr_data[SEI], default: 0};
  end

  // MEDELEG
  always_ff @(posedge clock, posedge reset) begin
    if (reset) medeleg <= 0;
    else if (wr_en_ && (wr_addr == Medeleg))
      medeleg <= '{II: wr_data[II], ECS: wr_data[ECS], ECU: wr_data[ECU], default: 0};
  end

  // XIP
  logic ssip, stip, seip;
  assign mip = '{
          SSI: ssip,
          MSI: msip,
          STI: stip,
          MTI: (mtime >= mtimecmp),
          SEI: seip,
          MEI: external_interrupt,
          default: 0
      };
  assign sip = '{SSI: ssip, STI: stip, SEI: seip, default: 0};
  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      stip <= 0;
      seip <= 0;
    end else if (wr_en_ && wr_addr == Mip) begin
      stip <= wr_data[STI];
      seip <= wr_data[SEI];
    end
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      ssip <= 0;
    end else if (wr_en_ && wr_addr inside {Mip, Sip}) begin
      ssip <= wr_data[SSI];
    end
  end

  // XIE
  logic ssie, msie, stie, mtie, seie, meie;
  assign mie_ = '{SSI: ssie, MSI: msie, STI: stie, MTI: mtie, SEI: seie, MEI: meie, default: 0};
  assign sie_ = '{SSI: ssie, STI: stie, SEI: seie, default: 0};
  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      msie <= 0;
      mtie <= 0;
      meie <= 0;
    end else if (wr_en_ && wr_addr == Mie) begin
      msie <= wr_data[MSI];
      mtie <= wr_data[MTI];
      meie <= wr_data[MEI];
    end
  end

  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      ssie <= 0;
      stie <= 0;
      seie <= 0;
    end else if (wr_en_ && wr_addr inside {Mie, Sie}) begin
      ssie <= wr_data[SSI];
      stie <= wr_data[STI];
      seie <= wr_data[SEI];
    end
  end

  // MSCRATCH
  register_d #(
      .N(DATA_SIZE),
      .reset_value(0)
  ) mscratch_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (wr_addr == Mscratch)),
      .D(wr_data),
      .Q(mscratch)
  );

  // SSCRATCH
  register_d #(
      .N(DATA_SIZE),
      .reset_value(0)
  ) sscratch_reg (
      .clock(clock),
      .reset(reset),
      .enable(wr_en_ && (wr_addr == Sscratch)),
      .D(wr_data),
      .Q(sscratch)
  );

  // MEPC
  always @(posedge clock, posedge reset) begin
    if (reset) mepc_ <= 0;
    else if (m_trap && async_trap) mepc_ <= interrupt_pc;
    else if (m_trap && sync_trap)  mepc_ <= exception_pc;
    else if (wr_en_ && (wr_addr == Mepc)) mepc_ <= {wr_data[DATA_SIZE-1:2], 2'b00};
  end
  assign mepc = mepc_;

  // SEPC
  always @(posedge clock, posedge reset) begin
    if (reset) sepc_ <= 0;
    else if (s_trap && async_trap) sepc_ <= interrupt_pc;
    else if (s_trap && sync_trap)  sepc_ <= exception_pc;
    else if (wr_en_ && (wr_addr == Sepc)) sepc_ <= {wr_data[DATA_SIZE-1:2], 2'b00};
  end
  assign sepc = sepc_;

  // MCAUSE
  logic m_legal_write;
  always @(posedge clock, posedge reset) begin
    if (reset) mcause <= 0;
    else if (m_trap) mcause <= cause;
    else if (m_legal_write && wr_en_ && (wr_addr == Mcause)) mcause <= wr_data;  // WLRL
  end
  assign m_legal_write = check_cause_write(wr_data, 1'b1);

  // SCAUSE
  logic s_legal_write;
  always @(posedge clock, posedge reset) begin
    if (reset) scause <= 0;
    else if (s_trap) scause <= cause;
    else if (s_legal_write && wr_en_ && (wr_addr == Scause)) scause <= wr_data;  // WLRL
  end
  assign s_legal_write = check_cause_write(wr_data, 1'b0);

  // MTVAL
  always @(posedge clock, posedge reset) begin
    if (reset) mtval <= 0;
    //  Store Illegal Instruction
    else if (m_trap && !async_trap && sync_trap && illegal_instruction) mtval <= instruction;
    else if (wr_en_ && (wr_addr == Mtval)) mtval <= wr_data;
  end

  // STVAL
  always @(posedge clock, posedge reset) begin
    if (reset) stval <= 0;
    //  Store Illegal Instruction
    else if (s_trap && !async_trap && sync_trap && illegal_instruction) stval <= instruction;
    else if (wr_en_ && (wr_addr == Stval)) stval <= wr_data;
  end

  // PRIV
  assign privilege_mode = priv;
  always @(posedge clock, posedge reset) begin
    if (reset) priv <= Machine;  // M-Mode
    else if (m_trap) priv <= Machine;
    else if (s_trap) priv <= Supervisor;
    else if (mret_) priv <= privilege_mode_t'(mstatus[MPP+1:MPP]);
    else if (sret_) priv <= privilege_mode_t'({1'b0, mstatus[SPP]});
  end

  // read data
  always_comb begin
    rd_data = 0;
    unique case (rd_addr)
      Sstatus: rd_data = sstatus;
      Sie: rd_data = sie_;
      Stvec: rd_data = stvec;
      Sscratch: rd_data = sscratch;
      Sepc: rd_data = sepc_;
      Scause: rd_data = scause;
      Stval: rd_data = stval;
      Sip: rd_data = sip;
      Mstatus: rd_data = mstatus;
      Misa: rd_data = misa;
      Medeleg: rd_data = medeleg;
      Mideleg: rd_data = mideleg;
      Mie: rd_data = mie_;
      Mtvec: rd_data = mtvec;
      Mscratch: rd_data = mscratch;
      Mepc: rd_data = mepc_;
      Mcause: rd_data = mcause;
      Mtval: rd_data = mtval;
      Mip: rd_data = mip;
      Mvendorid: rd_data = mvendorid;
      Marchid: rd_data = marchid;
      Mimpid: rd_data = mimpid;
      Mhartid: rd_data = mhartid;
      default: rd_data = 0;
    endcase
  end

  assign addr_exception = !(wr_addr inside {Sstatus, Sie, Stvec, Sscratch, Sepc, Scause, Stval, Sip,
                                            Mstatus, Misa, Medeleg, Mideleg, Mie, Mtvec, Mscratch,
                                            Mepc, Mcause, Mtval, Mip, Mvendorid, Marchid, Mimpid,
                                            Mhartid});

  // Trap
  logic [5:0] interrupt_vector;  // If bit i is high, so interrupt 2*i + 1 happened
  logic [3:0] exception_vector;  // 3: ECM, 2: ECS, 1: ECU, 0: II
  logic m_trap_, s_trap_;
  // Interrupt Vector
  genvar i;
  generate
    // Maps interrupt code 2*i + 1 to interrupt vector bit i
    for (i = 0; i < 6; i = i + 1) begin : gen_interrupt_vector
      if (i % 2 == 1)  // MEI, MTI, MSI: U, S -> Always Enabled, M -> MIE
        assign interrupt_vector[i] =  mip[2*i+1]  &
            ((priv inside {User, Supervisor}) | ((priv == Machine) & mie_[2*i+1] & mie));
      // SEI, STI, SSI: U -> Always Enabled, S -> SIE or !mideleg, M -> mideleg
      else
        assign interrupt_vector[i] =  mip[2*i+1] & ((priv == User) |
            (!priv[1] & sie & mie_[2*i+1]));
    end
  endgenerate
  // Exception Vector
  assign exception_vector[0] = illegal_instruction & ((priv == User) |
            (priv == Supervisor & (!medeleg[II] | sie)) |
            (priv == Machine & mie));  // II
  assign exception_vector[1] = ecall & (priv == User);  // ECU
  assign exception_vector[2] = ecall & (priv == Supervisor) & (!medeleg[ECS] | sie); // ECS
  assign exception_vector[3] = ecall & (priv == Machine) & mie;  // ECM
  // Trap
  assign async_trap = |(interrupt_vector);
  assign sync_trap = |(exception_vector);
  always_comb begin : trap_calc
    cause_async = 0;
    cause_sync = 0;
    m_trap_ = 0;
    s_trap_ = 0;
    // 1st Priority Mux
    // M-Trap: M-Mode AND !mi(e)deleg[i]
    // S-Trap: !M-Mode AND mi(e)deleg[i]
    if (interrupt_vector[5]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = MEI;
      m_trap_ = 1'b1;
      s_trap_ = 1'b0;
    end else if (interrupt_vector[3]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = MTI;
      m_trap_ = 1'b1;
      s_trap_ = 1'b0;
    end else if (interrupt_vector[1]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = MSI;
      m_trap_ = 1'b1;
      s_trap_ = 1'b0;
    end else if (interrupt_vector[4]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = SEI;
      m_trap_ = !mideleg[SEI];
      s_trap_ = !priv[1] & mideleg[SEI];
    end else if (interrupt_vector[2]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = STI;
      m_trap_ = !mideleg[STI];
      s_trap_ = !priv[1] & mideleg[STI];
    end else if (interrupt_vector[0]) begin
      cause_async[DATA_SIZE-1] = 1'b1;
      cause_async[DATA_SIZE-2:0] = SSI;
      m_trap_ = !mideleg[SSI];
      s_trap_ = !priv[1] & mideleg[SSI];
    end else if (exception_vector[0]) begin
      m_trap_ = priv[1] | !medeleg[II];
      s_trap_ = !priv[1] & medeleg[II];
    end else if (exception_vector[1]) begin
      m_trap_ = !medeleg[ECU];
      s_trap_ = medeleg[ECU];  // priv = 2'b00
    end else if (exception_vector[2]) begin
      m_trap_ = !medeleg[ECS];
      s_trap_ = medeleg[ECS];  // priv = 2'b01
    end else if (exception_vector[3]) begin
      m_trap_ = 1'b1;
      s_trap_ = 1'b0;
    end
    // 2nd Priority Mux -> Exclusive for cause_sync -> Decrease Critical Path
    if (exception_vector[0]) cause_sync = II;
    else if (|exception_vector[3:1]) cause_sync = {2'b10, priv};
  end
  assign cause  = async_trap ? cause_async : cause_sync;  // Interrupt > Exception
  assign m_trap = m_trap_ & en;
  assign s_trap = s_trap_ & en;
  assign _trap  = m_trap | s_trap;
  assign trap   = _trap;
  assign exception = sync_trap & en;

  // Trap Address
  logic [DATA_SIZE-3:0] m_trap_addr_vet, s_trap_addr_vet;
  // M-Trap Address
  assign m_trap_addr[1:0] = 2'b00;
  assign m_trap_addr[DATA_SIZE-1:2] = (mtvec[0] && async_trap) ? m_trap_addr_vet
                                                                : mtvec[DATA_SIZE-1:2];
  sklansky_adder #(
      .INPUT_SIZE(DATA_SIZE - 2)
  ) m_trap_addr_vet_adder (
      .A(mtvec[DATA_SIZE-1:2]),
      .B(cause_async[DATA_SIZE-3:0]),  // MSb -> overflow
      .c_in(1'b0),
      .c_out(),
      .S(m_trap_addr_vet)
  );
  // S-Trap Address
  assign s_trap_addr[1:0] = 2'b00;
  assign s_trap_addr[DATA_SIZE-1:2] = (stvec[0] && async_trap) ? s_trap_addr_vet
                                                                : stvec[DATA_SIZE-1:2];
  sklansky_adder #(
      .INPUT_SIZE(DATA_SIZE - 2)
  ) s_trap_addr_vet_adder (
      .A(stvec[DATA_SIZE-1:2]),
      .B(cause_async[DATA_SIZE-3:0]),  // MSb -> overflow
      .c_in(1'b0),
      .c_out(),
      .S(s_trap_addr_vet)
  );
  // Real Trap Address
  assign trap_addr = m_trap ? m_trap_addr : s_trap_addr;

endmodule
