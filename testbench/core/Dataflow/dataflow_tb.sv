
module dataflow_tb ();

  ///////////////////////////////////
  ///////////// Imports /////////////
  ///////////////////////////////////
  import csr_pkg::*;
  import dataflow_pkg::*;
  import hazard_unit_pkg::*;
  import instruction_pkg::*;
  import branch_decoder_unit_pkg::*;
  import dataflow_tb_pkg::*;
  import forwarding_unit_pkg::*;
  import alu_pkg::*;

  ///////////////////////////////////
  //////////// Parameters ///////////
  ///////////////////////////////////
  // Wishbone
  localparam integer CacheSize = 8192;
  localparam integer SetSize = 1;
  localparam integer InstDataSize = 32;
  localparam integer HasRV64I = (DataSize == 64);
  localparam integer CacheDataSize = 128;
  localparam integer ProcAddrSize = 32;
  localparam integer MemoryAddrSize = 16;
  localparam integer PeriphAddrSize = 3;
  localparam integer ByteSize = 8;
  localparam integer ByteNum = DataSize/ByteSize;
  // Memory Address
  localparam reg [63:0] RomAddr = 64'h0000000000000000;
  localparam reg [63:0] RomAddrMask = 64'hFFFFFFFFFF000000;
  localparam reg [63:0] RamAddr = 64'h0000000001000000;
  localparam reg [63:0] RamAddrMask = 64'hFFFFFFFFFF000000;
  localparam reg [63:0] UartAddr = 64'h0000000010013000;
  localparam reg [63:0] UartAddrMask = 64'hFFFFFFFFFFFFF000;
  localparam reg [63:0] CsrAddr = 64'hFFFFFFFFFFFFFFC0;
  localparam reg [63:0] CsrAddrMask = 64'hFFFFFFFFFFFFFFC0;
  // MTIME
  localparam integer ClockCycles = 100;

  ///////////////////////////////////
  /////////// DUT Signals ///////////
  ///////////////////////////////////
  // Common
  logic clock;
  logic reset;
  // Instruction Memory
  instruction_t inst;
  logic [DataSize-1:0] inst_mem_addr;
  // Data Memory
  logic [DataSize-1:0] rd_data;
  logic rd_en;
  logic wr_en;
  logic [DataSize-1:0] wr_data;
  logic [DataSize-1:0] data_mem_addr;
  // From Memory Unit
  logic mem_busy;
  // From Control Unit
  logic alua_src;
  logic alub_src;
  logic aluy_src;
  alu_op_t alu_op;
  logic alupc_src;
  logic [1:0] wr_reg_src;
  logic wr_reg_en;
  logic mem_rd_en;
  logic mem_wr_en;
  logic [ByteNum-1:0] mem_byte_en;
  logic mem_signed;
  forwarding_type_t forwarding_type;
  branch_t branch_type;
  cond_branch_t cond_branch_type;
  // Interrupts/Exceptions from UC
  logic ecall;
  logic illegal_instruction;
  // Trap Return
  csr_op_t csr_op;
  logic csr_imm;
  // Interrupts from Memory
  logic external_interrupt;
  logic [DataSize-1:0] msip;
  logic [63:0] mtime;
  logic [63:0] mtimecmp;
  // To Control Unit
  opcode_t opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic csr_addr_invalid;
  privilege_mode_t privilege_mode;
  // From Forwarding Unit
  forwarding_t forward_rs1_id;
  forwarding_t forward_rs2_id;
  forwarding_t forward_rs1_ex;
  forwarding_t forward_rs2_ex;
  forwarding_t forward_rs2_mem;
  // To Forwarding Unit
  forwarding_type_t forwarding_type_id;
  forwarding_type_t forwarding_type_ex;
  forwarding_type_t forwarding_type_mem;
  logic reg_we_mem;
  logic reg_we_wb;
  logic zicsr_ex;
  logic [4:0] rd_ex;
  logic [4:0] rd_mem;
  logic [4:0] rd_wb;
  logic [4:0] rs1_id;
  logic [4:0] rs2_id;
  logic [4:0] rs1_ex;
  logic [4:0] rs2_ex;
  logic [4:0] rs2_mem;
  // From Hazard Unit
  logic stall_if;
  logic stall_id;
  logic flush_id;
  logic flush_ex;
  // To Hazard Unit
  logic reg_we_ex;
  logic mem_rd_en_ex;
  logic mem_rd_en_mem;
  logic store_id;
  // Others
  hazard_t hazard_type;
  rs_used_t rs_used;

  ///////////////////////////////////
  /////////// Interfaces ////////////
  ///////////////////////////////////
  wishbone_if #(
      .DATA_SIZE(InstDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_inst0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_inst1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_data0 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache_data1 (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(MemoryAddrSize)
  ) wish_rom (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(MemoryAddrSize)
  ) wish_ram (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_uart (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(DataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_csr (
      .*
  );

  ///////////////////////////////////
  //////// Simulator Signals ////////
  ///////////////////////////////////
  // Fetch
  if_id_tb_t if_id_tb;
  logic [DataSize-1:0] new_pc = 0, pc = 0;
  // Decode
  id_ex_tb_t id_ex_tb;
  logic [DataSize-1:0] immediate;
  logic [DataSize-1:0] rd_data1, rd_data1_f, rd_data2, rd_data2_f;
  logic [DataSize-1:0] csr_rd_data, csr_wr_data;
  logic trap;
  logic [DataSize-1:0] trap_addr;
  logic csr_addr_invalid_tb;
  logic [DataSize-1:0] mepc, sepc;
  privilege_mode_t privilege_mode_tb;
  // Execute
  ex_mem_tb_t ex_mem_tb;
  logic [DataSize-1:0] alu_y, alu_a_f, alu_b_f;
  // Memory
  mem_wb_tb_t mem_wb_tb;
  logic [DataSize-1:0] wr_data_f = 0;
  // Write Back
  logic we_reg_file;
  logic [DataSize-1:0] reg_data;

  // variáveis
  integer limit = 100;  // número máximo de iterações a serem feitas(evitar loop infinito)
  // Address
  localparam integer FinalAddress = 16781308; // Final execution address
  localparam integer ExternalInterruptAddress = 16781320; // Active/Desactive External Interrupt

  ///////////////////////////////////
  //////////// DUT //////////////////
  ///////////////////////////////////
  dataflow #(
    .DATA_SIZE(DataSize)
  ) DUT (
    .clock,
    .reset,
    .inst,
    .inst_mem_addr,
    .rd_data,
    .rd_en,
    .wr_en,
    .wr_data,
    .data_mem_addr,
    .mem_busy,
    .alua_src,
    .alub_src,
    .aluy_src,
    .alu_op,
    .alupc_src,
    .wr_reg_src,
    .wr_reg_en,
    .mem_rd_en,
    .mem_wr_en,
    .mem_byte_en,
    .mem_signed,
    .forwarding_type,
    .branch_type,
    .cond_branch_type,
    .ecall,
    .illegal_instruction,
    .csr_op,
    .csr_imm,
    .external_interrupt,
    .msip,
    .mtime,
    .mtimecmp,
    .opcode,
    .funct3,
    .funct7,
    .csr_addr_invalid,
    .privilege_mode,
    .forward_rs1_id,
    .forward_rs2_id,
    .forward_rs1_ex,
    .forward_rs2_ex,
    .forward_rs2_mem,
    .forwarding_type_id,
    .forwarding_type_ex,
    .forwarding_type_mem,
    .reg_we_mem,
    .reg_we_wb,
    .zicsr_ex,
    .rd_ex,
    .rd_mem,
    .rd_wb,
    .rs1_id,
    .rs2_id,
    .rs1_ex,
    .rs2_ex,
    .rs2_mem,
    .stall_if,
    .stall_id,
    .flush_id,
    .flush_ex,
    .reg_we_ex,
    .mem_rd_en_ex,
    .mem_rd_en_mem,
    .store_id
  );

  ///////////////////////////////////
  /////// Proc Components ///////////
  ///////////////////////////////////
  control_unit #(
    .BYTE_NUM(ByteNum)
  ) controlUnit (
    .*
  );

  hazard_unit hazardUnit (
    .*
  );

  forwarding_unit forwardingUnit (
    .*
  );

  memory_unit #(
    .Width(DataSize)
  ) memoryUnit (
    .clock,
    .reset,
    .rd_data_mem(rd_en),
    .wr_data_mem(wr_en),
    .inst_mem_ack(wish_proc0.ack),
    .inst_mem_rd_dat(wish_proc0.dat_i_p),
    .data_mem_ack(wish_proc1.ack),
    .data_mem_rd_dat(wish_proc1.dat_i_p),
    .inst_mem_en(wish_proc0.cyc),
    .inst_mem_dat(inst),
    .data_mem_en(wish_proc1.cyc),
    .data_mem_we(wish_proc1.we),
    .data_mem_dat(rd_data),
    .busy(mem_busy)
  );

  assign wish_proc0.stb = wish_proc0.cyc;
  assign wish_proc0.we = 1'b0;
  assign wish_proc0.tgd = 1'b0;
  assign wish_proc0.addr = inst_mem_addr;
  assign wish_proc0.sel = 4'hF;
  assign wish_proc0.dat_o_p = '0;
  assign wish_proc1.stb = wish_proc1.cyc;
  assign wish_proc1.tgd = mem_signed;
  assign wish_proc1.addr = data_mem_addr;
  assign wish_proc1.sel = mem_byte_en;
  assign wish_proc1.dat_o_p = wr_data;

  ///////////////////////////////////
  //////// Mem Components ///////////
  ///////////////////////////////////
  // Instruction Cache
  cache #(
      .CACHE_SIZE(CacheSize),
      .SET_SIZE(SetSize)
  ) instruction_cache (
    .wb_if_ctrl(wish_cache_inst0),
    .wb_if_mem(wish_cache_inst1)
  );

  // Data Cache
  cache #(
      .CACHE_SIZE(CacheSize),
      .SET_SIZE(SetSize)
  ) data_cache (
    .wb_if_ctrl(wish_cache_data0),
    .wb_if_mem(wish_cache_data1)
  );

  // Instruction Memory
  rom #(
      .ROM_INIT_FILE("./ROM.mif"),
      .BUSY_CYCLES(4)
  ) instruction_memory (
      .wb_if_s(wish_rom)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .BUSY_CYCLES(4)
  ) data_memory (
      .wb_if_s(wish_ram)
  );

  // Registradores em memória do CSR
  csr_mem #(
    .DATA_SIZE(DataSize),
    .CLOCK_CYCLES(ClockCycles)
  ) mem_csr (
      .wb_if_s(wish_csr),
      .msip(msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp)
  );

  // Instanciação do barramento
  memory_controller #(
      .ROM_ADDR(RomAddr),
      .RAM_ADDR(RamAddr),
      .UART_ADDR(UartAddr),
      .CSR_ADDR(CsrAddr),
      .ROM_ADDR_MASK(RomAddrMask),
      .RAM_ADDR_MASK(RamAddrMask),
      .UART_ADDR_MASK(UartAddrMask),
      .CSR_ADDR_MASK(CsrAddrMask)
  ) controller (
      .wish_s_proc0(wish_proc0),
      .wish_s_proc1(wish_proc1),
      .wish_s_cache_inst(wish_cache_inst1),
      .wish_s_cache_data(wish_cache_data1),
      .wish_p_rom(wish_rom),
      .wish_p_ram(wish_ram),
      .wish_p_cache_inst(wish_cache_inst0),
      .wish_p_cache_data(wish_cache_data0),
      .wish_p_uart(wish_uart),
      .wish_p_csr(wish_csr)
  );

  ///////////////////////////////////
  /////// Checker Components ////////
  ///////////////////////////////////
  immediate_extender #(
      .N(DataSize)
  ) extensor_imediato (
      .immediate  (immediate),
      .instruction(if_id_tb.inst)
  );

  register_file #(
      .size(DataSize),
      .N(5)
  ) banco_de_registradores (
      .clock(clock),
      .reset(reset),
      .write_enable(we_reg_file),
      .read_address1(if_id_tb.inst.fields.r_type.rs1),
      .read_address2(if_id_tb.inst.fields.r_type.rs2),
      .write_address(mem_wb_tb.rd),
      .write_data(reg_data),
      .read_data1(rd_data1),
      .read_data2(rd_data2)
  );

  csr #(
    .DATA_SIZE(DataSize)
  ) control_status_register (
      // General
      .clock(clock),
      .reset(reset),
      .privilege_mode(privilege_mode_tb),
      // CSR RW interface
      .csr_op(csr_op),
      .wr_en(|if_id_tb.inst[19:15]),
      .addr(id_ex_tb.inst[31:20]),
      .wr_data(csr_wr_data),
      .rd_data(csr_rd_data),
      // Memory Interrupt
      .msip(|msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp),
      // External Interrupt
      .external_interrupt(external_interrupt),
      // Control Unit Exception
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .addr_exception(csr_addr_invalid_tb),
      // Trap Handler
      .trap_en(!stall_id && !mem_busy),
      .trap(trap),
      .trap_addr(trap_addr),
      .pc(id_ex_tb.pc),
      .instruction(id_ex_tb.inst),
      // MRET & SRET
      .mepc(mepc),
      .sepc(sepc)
  );

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  ///////////////////////////////////
  //////// Checker Functions ////////
  ///////////////////////////////////
  function automatic [DataSize-1:0] gen_new_pc(input instruction_t instruction,
                input logic [DataSize-1:0] pc, input logic [DataSize-1:0] imm,
                input logic [DataSize-1:0] A, input logic [DataSize-1:0] B,
                input logic [DataSize-1:0] mepc, input logic [DataSize-1:0] sepc,
                input logic trap, input logic [DataSize-1:0] trap_addr);
    if(trap) return trap_addr;
    unique case(instruction.opcode)
      Jal: return pc + (imm - 4);
      Jalr: return {A[DataSize-1:1], 1'b0} + imm;
      BType: begin
        unique case (instruction.fields.b_type.funct3)
          Beq:  return (A === B) ? pc + (imm - 4) : pc + 4;
          Bne:  return (A !== B) ? pc + (imm - 4) : pc + 4;
          Blt:  return ($signed(A)   <  $signed(B))   ? pc + (imm - 4) : pc + 4;
          Bge:  return ($signed(A)   >= $signed(B))   ? pc + (imm - 4) : pc + 4;
          Bltu: return ($unsigned(A) <  $unsigned(B)) ? pc + (imm - 4) : pc + 4;
          Bgeu: return ($unsigned(A) >= $unsigned(B)) ? pc + (imm - 4) : pc + 4;
          default: return pc + 4;
        endcase
      end
      SystemType: begin
        if(instruction.fields.r_type.funct7 == 7'h18) return mepc;
        else if(instruction.fields.r_type.funct7 == 7'h08) return sepc;
        return pc + 4;
      end
      default: return pc + 4;
    endcase
  endfunction

  function automatic forwarding_type_t gen_forwarding_type(input logic [6:0] opcode,
                                                           input logic [2:0] funct3,
                                                           input logic [6:0] funct7 = 7'h0,
                                                           input logic [1:0] privilege_mode = 2'h3);
    unique case (opcode)
      SType: return Type1_3;
      Jalr, BType: return Type2;
      SystemType: begin
        if(!(funct3 inside {3'h0, 3'h4}) && privilege_mode >= funct7[6:5])
          return funct3[2] ? NoType : Type2;
        else return NoType;
      end
      AluRType, AluRWType, AluIType, AluIWType, LoadType: return Type1;
      default: return NoType; // Lui, Auipc, Jal, Fence
    endcase
  endfunction

  function automatic logic gen_zicsr(input logic [6:0] opcode,
                                     input logic [2:0] funct3);
    return (opcode === SystemType) && !(funct3 inside {3'h0, 3'h4});
  endfunction

  function automatic logic gen_we_reg_file(input logic [6:0] opcode,
                                           input logic [2:0] funct3);
    unique case(opcode)
      Jal, Jalr, AluRType, AluRWType, AluIType, AluIWType, Lui, Auipc: return 1'b1;
      SystemType: begin
        return !(funct3 inside {3'h0, 3'h4}); // This function only executes after Decode
      end
      default: return 1'b0; // SType, BType, Fence
    endcase
  endfunction

  function automatic [DataSize-1:0] forward_data(input logic [DataSize-1:0] A,
                   input logic [DataSize-1:0] B, input logic [DataSize-1:0] C,
                   input logic [DataSize-1:0] D, input forwarding_t forwarding_type);
    unique case (forwarding_type)
      ForwardFromEx:  return B;
      ForwardFromMem: return C;
      ForwardFromWb: return D;
      default: return A; // NoForwarding
    endcase
  endfunction

  function automatic [DataSize-1:0] gen_alu_y(input logic [DataSize-1:0] A,
    input logic [DataSize-1:0] B, input alu_op_t seletor);
    reg [2*DataSize-1:0] mulh, mulhsu, mulhu;
    begin
      unique case (seletor)
        ShiftLeftLogic: return A << (B[$clog2(DataSize)-1:0]);
        SetLessThan: return ($signed(A) < $signed(B));
        SetLessThanUnsigned: return (A < B);
        Xor: return A ^ B;
        ShiftRightLogic: return A >> (B[$clog2(DataSize)-1:0]);
        Or: return A | B;
        And: return A & B;
        Sub: return $signed(A) - $signed(B);
        ShiftRightArithmetic: return $signed(A) >>> (B[$clog2(DataSize)-1:0]);
        Mul: return A * B;
        MulHigh: begin
          mulh = $signed(A) * $signed(B);
          return mulh[2*DataSize-1:DataSize];
        end
        MulHighSignedUnsigned: begin
          mulhsu = $signed(A) * B;
          return mulhsu[2*DataSize-1:DataSize];
        end
        MulHighUnsigned: begin
          mulhu = A * B;
          return mulhu[2*DataSize-1:DataSize];
        end
        Div: return $signed(A) / $signed(B);
        DivUnsigned: return A / B;
        Rem: return $signed(A) % $signed(B);
        RemUnsigned: return A % B;
        default: return $signed(A) + $signed(B); // Add
      endcase
    end
  endfunction

  function automatic logic gen_rd_en(input logic [6:0] opcode);
    return (opcode === LoadType);
  endfunction

  function automatic logic gen_wr_en(input logic [6:0] opcode);
    return (opcode === SType);
  endfunction

  ///////////////////////////////////
  //////// Especial Address /////////
  ///////////////////////////////////
  // Always to finish the simulation
  always @(posedge mem_wr_en) begin
    if(data_mem_addr == 16781308) begin // Final write addr
      $display("End of program!");
      $display("Write data: 0x%x", wr_data);
      $stop;
    end
  end

  // Always to set/reset external_interrupt
  always @(posedge clock, posedge reset) begin
    if(reset) external_interrupt = 1'b0;
    else if(data_mem_addr == ExternalInterruptAddress && mem_wr_en) external_interrupt = |wr_data;
  end

  ///////////////////////////////////
  /////// Dataflow Simulator ////////
  ///////////////////////////////////
  // Fetch
  always @(posedge clock iff (!mem_busy), posedge reset) begin: pc_reg
    if(reset) pc <= '0;
    else if(!stall_if) pc <= new_pc;
  end

  always @(posedge clock iff (!mem_busy), posedge reset) begin: fetch_gen
    if(reset || flush_id) begin
      if_id_tb <= '0;
      if_id_tb.inst <= Fence;
    end else if(!stall_id) begin
      if_id_tb.inst <= inst;
      if_id_tb.pc <= pc;
    end
  end

  CHK_PC: assert property (@(posedge clock) (inst_mem_addr === pc));

  // Decode
  always @(posedge clock iff (!mem_busy), posedge reset) begin: decode_gen
    if(reset || flush_ex) begin
      id_ex_tb <= '0;
    end else if(!stall_id) begin
      id_ex_tb.pc <= if_id_tb.pc;
      id_ex_tb.rs1 <= if_id_tb.inst === Lui ? 5'h0 : if_id_tb.inst[19:15];
      id_ex_tb.read_data_1 <= rd_data1_f;
      id_ex_tb.rs2 <= if_id_tb.inst[24:20];
      id_ex_tb.read_data_2 <= rd_data2_f;
      id_ex_tb.rd <= if_id_tb.inst[11:7];
      id_ex_tb.imm <= immediate;
      id_ex_tb.csr_read_data <= {csr_rd_data[DataSize-1:10],
            (csr_rd_data[9] | (external_interrupt & (if_id_tb.inst[31:20] inside {Mip, Sip}))),
                                 csr_rd_data[8:0]};
      id_ex_tb.inst <= if_id_tb.inst;
    end
  end

  always_comb begin: decode_gen_aux
    rd_data1_f = forward_data(rd_data1, id_ex_tb.csr_read_data, gen_zicsr(ex_mem_tb.inst[6:0],
                ex_mem_tb.inst[14:12]) ? ex_mem_tb.csr_read_data : ex_mem_tb.alu_y,
                reg_data, forward_rs1_id);
    rd_data2_f = forward_data(rd_data2, id_ex_tb.csr_read_data, gen_zicsr(ex_mem_tb.inst[6:0],
                ex_mem_tb.inst[14:12]) ? ex_mem_tb.csr_read_data : ex_mem_tb.alu_y,
                reg_data, forward_rs2_id);
    csr_wr_data = csr_imm ? $unsigned(if_id_tb.inst[19:15]) : rd_data1_f;
    new_pc = gen_new_pc(if_id_tb.inst, pc, immediate, rd_data1_f, rd_data2_f, mepc, sepc,
                        trap, trap_addr);
  end

  CHK_OPCODE: assert property (@(posedge clock) (opcode === if_id_tb.inst[6:0]));
  CHK_FUNCT3: assert property (@(posedge clock) (funct3 === if_id_tb.inst[14:12]));
  CHK_FUNCT7: assert property (@(posedge clock) (funct7 === if_id_tb.inst[31:25]));
  CHK_PRIVILEGE_MODE: assert property (@(posedge clock) (privilege_mode === privilege_mode_tb));
  CHK_ADDR_INVALID: assert property (@(posedge clock) (csr_addr_invalid === csr_addr_invalid_tb));
  CHK_CSR_WR_DATA: assert property (@(posedge clock) (csr_wr_data === DUT.csr_bank.wr_data));
  // Check Privilege only in decode
  CHK_FORWARDING_TYPE_ID: assert property (@(posedge clock) (forwarding_type_id ===
                                    gen_forwarding_type(if_id_tb.inst[6:0], if_id_tb.inst[14:12],
                                    if_id_tb.inst[31:25], privilege_mode_tb)));
  CHK_STORE_ID: assert property (@(posedge clock) (store_id === gen_wr_en(if_id_tb.inst.opcode)));
  CHK_RS1_ID: assert property (@(posedge clock) (rs1_id === (if_id_tb.inst === Lui ? 5'h0 :
                                                                          if_id_tb.inst[19:15])));
  CHK_RS2_ID: assert property (@(posedge clock) (rs2_id === if_id_tb.inst[24:20]));

  // Execute
  always @(posedge clock iff (!mem_busy), posedge reset) begin: execute_gen
    if(reset) begin
      ex_mem_tb <= '0;
    end else begin
      ex_mem_tb.pc <= id_ex_tb.pc;
      ex_mem_tb.rs2 <= id_ex_tb.rs2;
      ex_mem_tb.rd <= id_ex_tb.rd;
      ex_mem_tb.csr_read_data <= id_ex_tb.csr_read_data;
      ex_mem_tb.alu_y <= alu_y;
      ex_mem_tb.write_data <= alu_b_f;
      ex_mem_tb.inst <= id_ex_tb.inst;
    end
  end

  always_comb begin: execute_gen_aux
    alu_y = 0;
    alu_a_f = forward_data(id_ex_tb.read_data_1, id_ex_tb.read_data_1,
                           gen_zicsr(ex_mem_tb.inst[6:0], ex_mem_tb.inst[14:12]) ?
                           ex_mem_tb.csr_read_data : ex_mem_tb.alu_y,
                           reg_data, forward_rs1_ex);
    alu_b_f = forward_data(id_ex_tb.read_data_2, id_ex_tb.read_data_2,
                           gen_zicsr(ex_mem_tb.inst[6:0], ex_mem_tb.inst[14:12]) ?
                           ex_mem_tb.csr_read_data : ex_mem_tb.alu_y,
                           reg_data, forward_rs2_ex);
    unique case(id_ex_tb.inst.opcode)
      LoadType, SType: alu_y = alu_a_f + id_ex_tb.imm;
      Lui: alu_y = id_ex_tb.imm;
      Auipc: alu_y = id_ex_tb.pc + id_ex_tb.imm;
      AluRType, AluRWType: alu_y = gen_alu_y(alu_a_f, alu_b_f,
                  alu_op_t'({id_ex_tb.inst[30], id_ex_tb.inst[25], id_ex_tb.inst[14:12]}));
      AluIType, AluIWType: alu_y = gen_alu_y(alu_a_f, id_ex_tb.imm,
                  alu_op_t'({id_ex_tb.inst[30] & (id_ex_tb.inst[14:12] == 3'b101), 1'b0,
                            id_ex_tb.inst[14:12]}));
      default: alu_y = alu_a_f + alu_b_f; // BType, Jal, Jalr, Fence, SystemType
    endcase
    if(id_ex_tb.inst.opcode inside {AluRWType, AluIWType}) alu_y = {{32{alu_y[31]}}, alu_y[31:0]};
  end

  CHK_FORWARDING_TYPE_EX: assert property (@(posedge clock) (forwarding_type_ex ===
                                  gen_forwarding_type(id_ex_tb.inst[6:0], id_ex_tb.inst[14:12])));
  CHK_ZICSR_EX: assert property (@(posedge clock) (zicsr_ex === gen_zicsr(id_ex_tb.inst[6:0],
                                                                          id_ex_tb.inst[14:12])));
  CHK_REG_WE_EX: assert property (@(posedge clock) (reg_we_ex ===
                                    gen_we_reg_file(id_ex_tb.inst[6:0], id_ex_tb.inst[14:12])));
  CHK_MEM_RD_EN_EX: assert property (@(posedge clock) (mem_rd_en_ex ===
                                                        gen_rd_en(id_ex_tb.inst.opcode)));
  CHK_RS1_EX: assert property (@(posedge clock) (rs1_ex === id_ex_tb.rs1));
  CHK_RS2_EX: assert property (@(posedge clock) (rs2_ex === id_ex_tb.rs2));
  CHK_RD_EX: assert property (@(posedge clock) (rd_ex === id_ex_tb.rd));

  // Memory
  always @(posedge clock iff (!mem_busy), posedge reset) begin: memory_gen
    if(reset) begin
      mem_wb_tb <= '0;
    end else begin
      mem_wb_tb.pc <= ex_mem_tb.pc;
      mem_wb_tb.rd <= ex_mem_tb.rd;
      mem_wb_tb.csr_read_data <= ex_mem_tb.csr_read_data;
      mem_wb_tb.alu_y <= ex_mem_tb.alu_y;
      mem_wb_tb.read_data <= rd_data;
      mem_wb_tb.inst <= ex_mem_tb.inst;
    end
  end

  always_comb begin: memory_gen_aux
    wr_data_f = forward_data(ex_mem_tb.write_data, ex_mem_tb.write_data,
                             ex_mem_tb.write_data, reg_data, forward_rs2_mem);
  end

  CHK_RD_EN: assert property (@(posedge clock) (rd_en === gen_rd_en(ex_mem_tb.inst.opcode)));
  CHK_WR_EN: assert property (@(posedge clock) (wr_en === gen_wr_en(ex_mem_tb.inst.opcode)));
  CHK_WR_DATA: assert property (@(posedge clock) (wr_data === wr_data_f));
  CHK_DATA_MEM_ADDR: assert property (@(posedge clock) (data_mem_addr === ex_mem_tb.alu_y));
  CHK_FORWARDING_TYPE_MEM: assert property (@(posedge clock) (forwarding_type_mem ===
                    gen_forwarding_type(ex_mem_tb.inst[6:0], ex_mem_tb.inst[14:12])));
  CHK_REG_WE_MEM: assert property (@(posedge clock) (reg_we_mem ===
                                gen_we_reg_file(ex_mem_tb.inst[6:0], ex_mem_tb.inst[14:12])));
  CHK_MEM_RD_EN_MEM: assert property (@(posedge clock) (mem_rd_en_mem ===
                                                       gen_rd_en(ex_mem_tb.inst.opcode)));
  CHK_RS2_MEM: assert property (@(posedge clock) (rs2_mem === ex_mem_tb.rs2));
  CHK_RD_MEM: assert property (@(posedge clock) (rd_mem === ex_mem_tb.rd));

  // Write Back
  always_comb begin: write_back_gen_aux
    we_reg_file = gen_we_reg_file(mem_wb_tb.inst[6:0], mem_wb_tb.inst[14:12]);
    reg_data = mem_wb_tb.alu_y;
    unique case(mem_wb_tb.inst.opcode)
      Jal, Jalr: reg_data = mem_wb_tb.pc + 4;
      LoadType: reg_data = mem_wb_tb.read_data;
      SystemType: begin
        if(!(mem_wb_tb.inst[14:12] inside {3'h0, 3'h4})) // Instruction in WB can't be illegal
          reg_data = mem_wb_tb.read_data;
      end
      default: begin // AluRType, AluRWType, AluIType, AluIWType, Lui, Auipc, SType, BType, Fence
      end
    endcase
  end

  CHK_REG_DATA: assert property (@(posedge clock) (reg_data === DUT.bank.write_data));
  CHK_REG_WE_WB: assert property (@(posedge clock) (we_reg_file === DUT.bank.write_enable));

  // testar o DUT
  initial begin
    $display("SOT!");
    reset = 1'b1;
    @(posedge clock);
    reset = 1'b0;
    repeat(limit) begin
      @(posedge clock);
    end
    $stop;
  end
endmodule
