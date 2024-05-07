
// TODO: Trocar immediate assertion por Concurrent Assertion
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

  ///////////////////////////////////
  //////////// Parameters ///////////
  ///////////////////////////////////
  // Wishbone
  localparam integer CacheSize = 8192;
  localparam integer SetSize = 1;
  localparam integer HasRV64I = (DataSize == 64);
  localparam integer InstDataSize = 32;
  localparam integer DataSize = 32;
  localparam integer CacheDataSize = 128;
  localparam integer ProcAddrSize = 32;
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
  logic [DataSize-1:0] mem_msip;
  logic [63:0] mem_mtime;
  logic [63:0] mem_mtimecmp;
  // To Control Unit
  logic [6:0] opcode;
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
      .ADDR_SIZE(ProcAddrSize)
  ) wish_rom (
      .*
  );
  wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
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
  logic [DataSize-1:0] new_pc = 0;
  // Decode
  id_ex_tb_t id_ex_tb;
  logic [DataSize-1:0] immediate = 0;
  logic [DataSize-1:0] rd_data1, rd_data2;
  logic [DataSize-1:0] csr_rd_data, csr_wr_data;
  logic trap;
  logic [DataSize-1:0] trap_addr;
  logic csr_addr_invalid_tb = 0;
  logic [DataSize-1:0] mepc, sepc;
  privilege_mode_t privilege_mode_tb = Machine;
  logic branch_taken;
  // Execute
  ex_mem_t ex_mem_tb;
  logic [DataSize-1:0] alu_y;
  // Memory
  // Write Back

  // variáveis
  integer limit = 10000;  // número máximo de iterações a serem feitas(evitar loop infinito)
  integer i;
  genvar j;
  // Address
  localparam integer FinalAddress = 16781308; // Final execution address
  localparam integer ExternalInterruptAddress = 16781320; // Active/Desactive External Interrupt

  ///////////////////////////////////
  //////////// DUT //////////////////
  ///////////////////////////////////
  dataflow (
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
    .mem_addr_src,
    .forwarding_type,
    .branch_type,
    .cond_branch_type,
    .ecall,
    .illegal_instruction,
    .csr_op,
    .csr_imm,
    .external_interrupt,
    .mem_msip,
    .mem_mtime,
    .mem_mtimecmp,
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
    .rd_data_mem(wish_proc1.cyc | wish_proc1.stb),
    .wr_data_mem((wish_proc1.cyc | wish_proc1.stb) & wish_proc1.we),
    .inst_mem_ack(wish_proc0.ack),
    .inst_mem_rd_dat(wish_proc0.dat_i_p),
    .data_mem_ack(wish_proc1.ack),
    .data_mem_rd_dat(wish_proc1.dat_i_p),,
    .inst_mem_en(wish_proc0.cyc),
    .inst_mem_dat(inst),
    .data_mem_en(wish_proc1.cyc),
    .data_mem_we(wish_proc1.we),
    .data_mem_dat(rd_data),
    .busy(mem_busy)
  );

  assign wish_proc0.stb = wish_proc0.cyc;
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
    .wb_if_mem(wish_cache_inst1)
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
  csr_mem mem_csr (
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
      .instruction(if_id_tb.instruction)
  );

  register_file #(
      .size(DataSize),
      .N(5)
  ) banco_de_registradores (
      .clock(clock),
      .reset(reset),
      .write_enable(wr_reg_en && !(wr_reg_src == 2'b01 && csr_addr_exception_)),
      .read_address1(id_ex_tb.rs1),
      .read_address2(id_ex_tb.rs2),
      .write_address(instruction[11:7]),
      .write_data(reg_data),
      .read_data1(rd_data1),
      .read_data2(rd_data2)
  );

  CSR control_status_register (
      // General
      .clock(clock),
      .reset(reset),
      .privilege_mode(privilege_mode_tb),
      // CSR RW interface
      .csr_op(csr_op),
      .wr_en(|if_id_tb.inst[19:15])
      .addr(id_ex_tb.inst[31:20]),
      .wr_data(csr_wr_data),
      .rd_data(csr_rd_data),
      // Memory Interrupt
      .mem_msip(|msip),
      .mem_mtime(mtime),
      .mem_mtimecmp(mtimecmp),
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

  // geração do LUT linear -> função não suporta array
  generate
    for (j = 0; j < NLineI; j = j + 1) assign LUT_linear[NColumnI*(j+1)-1:NColumnI*j] = LUT_uc[j];
  endgenerate

  // função para determinar os seletores(sinais provenientes da UC) a partir do opcode, funct3 e funct7
  function automatic [DfSrcSize-1:0] find_instruction(
      input reg [6:0] opcode, input reg [2:0] funct3, input reg [6:0] funct7,
      input reg [NColumnI*NLineI-1:0] LUT_linear);
    integer i;
    reg [DfSrcSize-1:0] temp;
    begin
      temp = 0;
      // os valores de i nos for estão ligados a como o mif foi montado com base no sheets
      // U,J : apenas opcode
      if (opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
        for (i = 0; i < 3; i = i + 1)
        if (opcode === LUT_linear[(NColumnI*(i+1)-7)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end  // I, S, B: opcode e funct3
      else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 ||
              opcode === 7'b0010011 || opcode === 7'b0011011 || opcode === 7'b1100111 ||
              opcode === 7'b1110011) begin
        for (i = 3; i < 44; i = i + 1) begin
          if (opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
              funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3]) begin
            // SRLI e SRAI: funct7
            if (opcode == 7'b0010011 && funct3 === 3'b101) begin
              if (funct7[6:1] == LUT_linear[(NColumnI*(i+1)-16)+:6])
                temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
            end // ECALL + Privilegied
            else if(opcode === 7'b1110011) begin
              // ECALL, MRET, SRET
              if(funct3 === 3'b000 && funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7]) begin
                if(funct7 === 7'b0) temp = LUT_linear[NColumnI*i+:(NColumnI-17)]; // ECALL
                // MRET, SRET
                else if({funct7[6:5], funct7[3:0]} === 6'b001000 &&
                (privilege_mode[0] && (privilege_mode[1] | !funct7[4])))
                  temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
              end
              // Zicsr
              else if(funct3 !== 3'b000 && privilege_mode >= funct7[4:3])
                temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
            end else temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
          end
        end
      end  // R: opcode, funct3 e funct7
      else if (opcode === 7'b0111011 || opcode === 7'b0110011) begin
        for (i = 44; i < 72; i = i + 1)
        if(opcode === LUT_linear[(NColumnI*(i+1)-7)+:7] &&
             funct3 === LUT_linear[(NColumnI*(i+1)-10)+:3] &&
             funct7 === LUT_linear[(NColumnI*(i+1)-17)+:7])
          temp = LUT_linear[NColumnI*i+:(NColumnI-17)];
      end
      if(temp == 0 && opcode !== 7'b0001111) temp[DfSrcSize-1] = 1'b1; // Não achou a instrução
      find_instruction = temp;
    end
  endfunction

  function automatic [DataSize-1:0] CSR_function(
    input reg [DataSize-1:0] rd_data, input reg [DataSize-1:0] mask, input reg [1:0] op);
    begin
      case(op)
        2'b01: CSR_function = mask; // W
        2'b10: CSR_function = rd_data | mask; // S
        2'b11: CSR_function = rd_data & (~mask); // C
        default: CSR_function = 0;
      endcase
    end
  endfunction

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
      Jal, Jalr: return pc + imm;
      BType: begin
        unique case (instruction.b_type.funct3)
          Beq:  return (A === B) ? pc + imm : pc + 4;
          Bne:  return (A !== B) ? pc + imm : pc + 4;
          Blt:  return ($signed(A)   <  $signed(B))   ? pc + imm : pc + 4;
          Bge:  return ($signed(A)   >= $signed(B))   ? pc + imm : pc + 4;
          Bltu: return ($unsigned(A) <  $unsigned(B)) ? pc + imm : pc + 4;
          Bgeu: return ($unsigned(A) >= $unsigned(B)) ? pc + imm : pc + 4;
          default: return pc + 4;
        endcase
      end
      SystemType: begin
        if(instruction.r_type.funct7 == 7'h18) return mepc;
        else if(instruction.r_type.funct7 == 7'h08) return sepc;
        return pc + 4;
      end
      default: return pc + 4;
    endcase
  endfunction

  function automatic [DataSize-1:0] gen_alu_y(input logic [DataSize-1:0] A,
    input logic [DataSize-1:0] B, input alu_op_t seletor);
    reg [2*DataSize-1:0] mulh, mulhsu, mulhu;
    begin
      case (seletor)
        Add: return $signed(A) + $signed(B);
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
        default: return 0;
      endcase
    end
  endfunction

  // flags da ULA -> Apenas conferidas para B-type
  assign xorB = B ^ {DataSize{1'b1}};
  assign {carry_out_, add_sub} = A + xorB + 1;
  assign zero_ = ~(|add_sub);
  assign negative_ = add_sub[DataSize-1];
  assign overflow_ = (~(A[DataSize-1] ^ B[DataSize-1] ^ sub))
                   & (A[DataSize-1] ^ add_sub[DataSize-1]);

  // geração do A_immediate
  assign A_immediate = A + immediate;

  // sinais do DF vindos da UC
  assign {
      // Sinais determinados pelo estado
      pc_en, // DfSrcSize + 1
      ir_en, // DfSrcSize
      illegal_instruction, // DfSrcSize - 1
      // Sinais determinados pelo opcode
      alua_src, alub_src,
      aluy_src,
      alu_src, sub, arithmetic, alupc_src, wr_reg_src, mem_addr_src, ecall, mret, sret, csr_imm,
      csr_op, csr_wr_en,
      // Sinais que não dependem apenas do opcode
      pc_src,  // NotOnlyOp -1
      wr_reg_en,  // NotOnlyOp -2
      mem_wr_en, mem_rd_en, mem_byte_en} = db_df_src;

  // Always to finish the simulation
  always @(posedge mem_wr_en) begin
    if(mem_addr == 16781308) begin // Final write addr
      $display("End of program!");
      $display("Write data: 0x%x", wr_data);
      $stop;
    end
  end

  // Always to set/reset external_interrupt
  always @(posedge clock, posedge reset) begin
    if(reset) external_interrupt = 1'b0;
    else if(mem_addr == ExternalInterruptAddress && mem_wr_en) external_interrupt = |wr_data;
  end

  ///////////////////////////////////
  /////// Dataflow Simulator ////////
  ///////////////////////////////////
  task automatic DoReset();
    begin
      db_df_src = 0;
      reg_data = 0;
      aluA = 0;
      aluB = 0;
      csr_wr_data = 0;
      pc_4 = 0;
      pc_imm = 0;
      @(negedge clock);
      reset = 1'b1;
      @(posedge clock);
      @(negedge clock);
      reset = 1'b0;
      next_pc = pc;
    end
  endtask

  // Fetch
  always @(posedge clock iff (not mem_busy), posedge reset) begin: fetch_gen_always
    if(reset) begin
      if_id_tb <= '0;
    end else if(!stall_if) begin
      if_id_tb.instruction <= inst;
      if_id_tb.pc <= new_pc;
    end
  end

  always @(posedge clock) begin: fetch_check_always
    CHK_PC: assert(inst_mem_addr === if_id_tb.pc);
  end

  // Decode
  always @(posedge clock iff (not mem_busy), posedge reset) begin: decode_gen_always
    if(reset || flush_id) begin
      id_ex_tb <= '0;
    end else if(!stall_id) begin
      id_ex_tb.pc <= if_id_tb.pc;
      id_ex_tb.rs1 <= if_id_tb.instruction === Lui ? 5'h0 : if_id_tb.instruction[19:15];
      id_ex_tb.read_data_1 <= rd_data1;
      id_ex_tb.rs2 <= if_id_tb.instruction[24:20];
      id_ex_tb.read_data_1 <= rd_data2;
      id_ex_tb.rd <= if_id_tb.instruction[11:7];
      id_ex_tb.imm <= immediate;
      id_ex_tb.csr_read_data <= {csr_rd_data[DATA_SIZE-1:10],
            (csr_rd_data[9] | (external_interrupt & (if_id_reg.inst[31:20] inside {Mip, Sip}))),
                                 csr_rd_data[8:0]};
      id_ex_tb.inst <= if_id_tb.inst;
    end
  end

  always_comb begin: decode_gen_aux
    csr_wr_data = csr_imm ? $unsigned(if_id_tb.inst[19:15]) : rd_data1;
    new_pc = gen_new_pc(if_id_tb.inst, if_id_tb.pc, immediate, rd_data1, rd_data2, mepc, sepc,
                        trap, trap_addr);
  end

  always @(posedge clock) begin: decode_check_always
    CHK_OPCODE: assert(opcode === id_ex_tb.instruction[6:0]);
    CHK_FUNCT3: assert(funct3 === id_ex_tb.instruction[14:12]);
    CHK_FUNCT7: assert(funct7 === id_ex_tb.instruction[31:25]);
    CHK_PRIVILEGE_MODE: assert(privilege_mode === privilege_mode_tb);
    CHK_ADDR_INVALID: assert(csr_addr_invalid === csr_addr_invalid_tb);
    CHK_CSR_WR_DATA: assert(csr_wr_data === DUT.csr_aux_wr);
  end

  // Execute
  always @(posedge clock iff (not mem_busy), posedge reset) begin: execute_gen_always
    if(reset || flush_ex) begin
      ex_mem_tb <= '0;
    end else begin
      ex_mem_tb.pc <= pc;
      ex_mem_tb.rs2 <= id_ex_tb.rs2;
      ex_mem_tb.rd <= id_ex_tb.rd;
      ex_mem_tb.csr_read_data <= id_ex_tb.csr_read_data;
      ex_mem_tb.alu_y <= alu_y;
      ex_mem_tb.write_data <= id_ex_tb.read_data_2;
      ex_mem_tb.inst <= id_ex_tb.inst;
    end
  end

  always_comb begin: execute_gen_aux
    alu_y = 'x;
    unique case(id_ex_tb.inst.opcode)
      LoadType, Stype: alu_y = id_ex_tb.read_data_1 + id_ex_tb.imm;
      Lui: alu_y = id_ex_tb.imm;
      Auipc: alu_y = id_ex_tb.pc + id_ex_tb.imm;
      AluRType, AluRWType: alu_y = gen_alu_y(id_ex_tb.read_data_1, id_ex_tb.read_data_2,
                  alu_op_t'({id_ex_tb.inst[30], id_ex_tb.inst[25], id_ex_tb.inst[14:12]}));
      AluIType, AluIWType: alu_y = gen_alu_y(id_ex_tb.read_data_1, id_ex_tb.imm,
                  alu_op_t'({id_ex_tb.inst[30] & (id_ex_tb.inst[14:12] == 3'b101), 1'b0,
                            id_ex_tb.inst[14:12]}));
      default: begin
      end
    endcase
  end

  task automatic DoDecode();
    begin
      @(negedge clock);
      // Checo opcode, funct3 e funct7
      `ASSERT(opcode === instruction[6:0]);
      `ASSERT(funct3 === instruction[14:12]);
      `ASSERT(funct7 === instruction[31:25]);
      // Obtenho os sinais da UC -> Sheets
      df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
      db_df_src = 0;
    end
  endtask

  task automatic DoExecute();
    begin
      // Atribuo ao tb os valores do sheets
      db_df_src[DfSrcSize:NotOnlyOp] = {1'b0, df_src[DfSrcSize-1:NotOnlyOp]};
      db_df_src[NotOnlyOp-3:0] = df_src[NotOnlyOp-3:0];
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          db_df_src[NotOnlyOp-1] = df_src[NotOnlyOp-1];
          @(negedge clock);
          // Confiro o endereço de acesso
          `ASSERT(mem_addr === A + immediate);
          // Caso seja store -> confiro a palavra a ser escrita
          if (opcode[5]) `ASSERT(wr_data === B);
          @(posedge mem_ack);
          db_df_src[ByteNum+1:ByteNum] = 2'b00;
          // caso necessário escrevo no banco
          db_df_src[NotOnlyOp-2] = df_src[NotOnlyOp-2];
          db_df_src[DfSrcSize+1] = 1'b1; // Incremento PC
          if (!opcode[5]) reg_data = rd_data;
          @(negedge clock);
          // Caso load -> confiro a leitura
          if (!opcode[5]) `ASSERT(DUT.rd === reg_data);
          next_pc = pc + 4;
        end
        // Branch(B*)
        7'b1100011: begin
          @(negedge clock);
          // Decido o valor de pc_src com base em funct3 e no valor das flags simuladas
          if (funct3[2:1] === 2'b00) db_df_src[NotOnlyOp-1] = zero_ ^ funct3[0];
          else if (funct3[2:1] === 2'b10) db_df_src[NotOnlyOp-1] = negative_ ^ overflow ^ funct3[0];
          else if (funct3[2:1] === 2'b11) db_df_src[NotOnlyOp-1] = carry_out_ ~^ funct3[0];
          else begin
            $display("Error B-type: Invalid funct3! funct3 : %x", funct3);
            $stop;
          end
          pc_4                   = pc + 4;
          pc_imm                 = pc + immediate;
          db_df_src[DfSrcSize+1] = 1'b1;
          db_df_src[NotOnlyOp-2] = 1'b0;
          // Decido o próximo valor de pc
          if (db_df_src[NotOnlyOp-1]) next_pc = pc_imm;
          else next_pc = pc_4;
          // Confiro as flags da ULA
          `ASSERT(overflow === overflow_);
          `ASSERT(carry_out === carry_out_);
          `ASSERT(negative === negative_);
          `ASSERT(zero === zero_);
        end
        // LUI e AUIPC
        7'b0110111, 7'b0010111: begin
          // Habilito o pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          if (opcode[5]) reg_data = immediate;  // LUI
          else reg_data = pc + immediate;  // AUIPC
          next_pc = pc + 4;
          @(negedge clock);
          // Confiro se reg_data está correto
          `ASSERT(reg_data === DUT.rd);
        end
        // JAL e JALR
        7'b1101111, 7'b1100111: begin
          // Habilito pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          reg_data = pc + 4;  // escrever pc + 4 no banco -> Link
          @(negedge clock);
          if (opcode[3]) pc_imm = pc + immediate;  // JAL
          else pc_imm = {A_immediate[31:1], 1'b0};  // JALR
          next_pc = pc_imm;
          // Confiro a escrita no banco
          `ASSERT(DUT.rd === reg_data);
        end
        // ULA R/I-type
        7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
          // Habilito pc e o banco
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = {df_src[NotOnlyOp-1], 1'b1};
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
          // Uso ULA_function para calcular o reg_data
          aluA = opcode[3] ? {{32{A[31]}}, A[31:0]} : A;
          aluB = opcode[3] ? {{32{B[31]}}, B[31:0]} : B;
          if (opcode[5]) reg_data = ULA_function(aluA, aluB, {funct7[0], funct7[5], funct3});
          else if (funct3 === 3'b101) reg_data = ULA_function(aluA, immediate, {funct7[0] &
                                                (opcode != 7'b0010011), funct7[5], funct3});
          else reg_data = ULA_function(aluA, immediate, {2'b00, funct3});
          // opcode[3] = 1'b1 -> RV64I
          if (opcode[3]) reg_data = {{32{reg_data[31]}}, reg_data[31:0]};
          next_pc = pc + 4;
          // Verifico reg_data
          `ASSERT(reg_data === DUT.rd);
        end
        // FENCE
        7'b0001111: begin
          // Conservativo: NOP
          db_df_src[DfSrcSize+1] = 1'b1;
          next_pc = pc + 4;
          @(negedge clock);
        end
        // ECALL, MRET, SRET, CSRR* (SYSTEM)
        7'b1110011: begin
          db_df_src[NotOnlyOp-1:NotOnlyOp-2] = df_src[NotOnlyOp-1:NotOnlyOp-2];
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
          if(funct3 === 3'b000) begin
            if(funct7 === 0) next_pc = trap_addr; // Ecall
            else if(funct7 === 7'b0011000 && privilege_mode === 2'b11) next_pc = mepc; // MRET
            else if(funct7 === 7'b0001000 && privilege_mode[0] === 1'b1) next_pc = sepc; // SRET
            else begin
              $display("Error SYSTEM: Invalid funct7! funct7 : %x", funct7);
              $stop;
            end
          end
          else if(funct3 !== 3'b100) begin // CSRR*
            reg_data = csr_rd_data;
            if(instruction[31:20] == 12'h344 || instruction[31:20] == 12'h144)
              reg_data[registradores_de_controle.SEIP] =
                csr_rd_data[registradores_de_controle.SEIP] | external_interrupt;
            if(funct3[2]) csr_wr_data = CSR_function(csr_rd_data, instruction[19:15], funct3[1:0]);
            else csr_wr_data = CSR_function(csr_rd_data, A, funct3[1:0]);
            // Sempre checo a leitura/escrita até se ela não acontecer
            if(csr_addr_exception_) db_df_src[DfSrcSize-1] = 1'b1;
            `ASSERT(csr_addr_exception === csr_addr_exception_);
            if(privilege_mode >= funct7[4:3]) begin
              `ASSERT(csr_wr_data === DUT.csr_wr_data);
              `ASSERT(reg_data === DUT.rd);
            end
            next_pc = pc + 4;
          end
          else begin
              $display("Error SYSTEM: Invalid funct3! funct3 : %x", funct3);
              $stop;
          end
        end
        default: begin
          // Habilito pc e illegal_instruction
          db_df_src[DfSrcSize-1] = 1'b1;
          db_df_src[DfSrcSize+1] = 1'b1;
          @(negedge clock);
        end
      endcase
    end
  endtask

  // testar o DUT
  initial begin
    if(HasRV64I)
      $readmemb("./MIFs/core/core/RV64I.mif", LUT_uc);
    else
      $readmemb("./MIFs/core/core/RV32I.mif", LUT_uc);
    $display("SOT!");
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      case(estado)
        Fetch: DoFetch;
        Decode: DoDecode;
        Execute: DoExecute;
        default: DoReset;
      endcase
      #1;
      `ASSERT(DUT._trap === csr_trap);
      `ASSERT(privilege_mode === csr_privilege_mode);
      _trap = csr_trap;
      _trap_addr = trap_addr;
      @(posedge clock);
      // Atualizando estado  e pc
      estado = (estado + 1)%3;
      pc = _trap ? _trap_addr : next_pc;
      next_pc = pc;
    end
    $stop;
  end
endmodule
