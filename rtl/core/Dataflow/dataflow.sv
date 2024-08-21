import csr_pkg::*;
import dataflow_pkg::*;
import hazard_unit_pkg::*;
import instruction_pkg::*;
import branch_decoder_unit_pkg::*;
import alu_pkg::*;
import forwarding_unit_pkg::*;
import control_unit_pkg::*;

module dataflow #(
    parameter integer DATA_SIZE = 32
) (
    // Common
    input wire clock,
    input wire reset,
    // To Memory Unit
    output wire mem_unit_en,
    // Instruction Memory
    input instruction_t inst,
    output wire [DATA_SIZE-1:0] inst_mem_addr,
    // Data Memory
    input wire [DATA_SIZE-1:0] rd_data,
    output wire rd_en,
    output wire wr_en,
    output wire [DATA_SIZE/8-1:0] byte_en,
    output wire signed_en,
    output wire [DATA_SIZE-1:0] wr_data,
    output wire [DATA_SIZE-1:0] data_mem_addr,
    // From Memory Unit
    input logic mem_busy,
    // From Control Unit
    input wire alua_src,
    input wire alub_src,
    input wire aluy_src,
    input alu_op_t alu_op,
    input wire alupc_src,
    input wr_reg_t wr_reg_src,
    input wire wr_reg_en,
    input logic mem_rd_en,
    input logic mem_wr_en,
    input logic [DATA_SIZE/8-1:0] mem_byte_en,
    input logic mem_signed,
    input forwarding_type_t forwarding_type,
    input branch_t branch_type,
    input cond_branch_t cond_branch_type,
    // Trap Return/Zicsr
    input csr_op_t csr_op,
    input wire csr_imm,
    // Interrupts from Memory
    input wire external_interrupt,
    input wire [DATA_SIZE-1:0] msip,
    input wire [63:0] mtime,
    input wire [63:0] mtimecmp,
    // To Control Unit
    output opcode_t opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output privilege_mode_t privilege_mode,
    // From Forwarding Unit: Register Bank
    input forwarding_t forward_rs1_id,
    input forwarding_t forward_rs2_id,
    input forwarding_t forward_rs1_ex,
    input forwarding_t forward_rs2_ex,
    input forwarding_t forward_rs2_mem,
    // To Forwarding Unit: Register Bank
    output forwarding_type_t forwarding_type_id,
    output forwarding_type_t forwarding_type_ex,
    output forwarding_type_t forwarding_type_mem,
    output logic reg_we_mem,
    output logic reg_we_wb,
    output logic [4:0] rd_ex,
    output logic [4:0] rd_mem,
    output logic [4:0] rd_wb,
    output logic [4:0] rs1_id,
    output logic [4:0] rs2_id,
    output logic [4:0] rs1_ex,
    output logic [4:0] rs2_ex,
    output logic [4:0] rs2_mem,
    // From Forwarding Unit: CSR Bank
    input forwarding_t forward_csr_id,
    input forwarding_t forward_csr_ex,
    // To Forwarding Unit: CSR Bank
    output logic csr_we_mem,
    output logic csr_we_wb,
    output logic [11:0] csr_addr_id,
    output logic [11:0] csr_addr_ex,
    output logic [11:0] csr_addr_mem,
    output logic [11:0] csr_addr_wb,
    // From Hazard Unit
    input logic stall_if,
    input logic stall_id,
    input logic stall_ex,
    input logic stall_mem,
    input logic stall_wb,
    input logic flush_id,
    input logic flush_ex,
    input logic flush_mem,
    input logic flush_wb,
    // To Hazard Unit
    /* output logic [4:0] rs1_id, */
    /* output logic [4:0] rs2_id, */
    /* output logic [4:0] rd_ex, */
    /* output logic [4:0] rd_mem, */
    output pc_src_t pc_src,
    output logic interrupt,
    output logic flush_all,
    output logic reg_we_ex,
    output logic mem_rd_en_ex,
    output logic mem_rd_en_mem,
    output logic rd_complete_ex,
    output logic store_id
);

  // Pipeline registers
  if_id_t                          if_id_reg;
  id_ex_t                          id_ex_reg;
  ex_mem_t                         ex_mem_reg;
  mem_wb_t                         mem_wb_reg;

  // Fios intermediários
  // Register File
  wire             [          4:0] rs1_addr;
  wire             [DATA_SIZE-1:0] rs1;
  wire             [DATA_SIZE-1:0] rs2;
  wire             [DATA_SIZE-1:0] rd;
  // Extensor de Imediato
  wire             [DATA_SIZE-1:0] immediate;
  // ALU
  wire             [DATA_SIZE-1:0] aluA;
  wire             [DATA_SIZE-1:0] aluB;
  wire             [DATA_SIZE-1:0] aluY;
  wire             [DATA_SIZE-1:0] muxaluY_out;  // aluY or sign_extended(aluY[31:0])
  // Somador PC + 4
  wire             [DATA_SIZE-1:0] pc_plus_4;
  wire             [DATA_SIZE-1:0] cte_4 = 4;
  // Somador PC + Imediato
  wire             [DATA_SIZE-1:0] pc_plus_immediate;
  // PC
  wire             [DATA_SIZE-1:0] pc;
  reg              [DATA_SIZE-1:0] new_pc;
  // CSR
  wire             [DATA_SIZE-1:0] trap_addr;
  wire                             _trap;
  privilege_mode_t                 _privilege_mode;
  // Trap Return
  wire             [DATA_SIZE-1:0] mepc;
  wire             [DATA_SIZE-1:0] sepc;
  logic                            exception;
  // ZICSR
  logic            [DATA_SIZE-1:0] csr_rd_data;
  logic            [DATA_SIZE-1:0] csr_mask_rd;
  logic            [DATA_SIZE-1:0] csr_mask_rd_data;
  logic            [DATA_SIZE-1:0] csr_aux_wr;
  logic            [DATA_SIZE-1:0] csr_wr_data;
  // Branch Decoder Unit
  pc_src_t                         _pc_src;

  // IF stage
  always_ff @(posedge clock iff (~stall_id && ~mem_busy) or posedge reset) begin
    if (reset || flush_id) begin
       if_id_reg <= '0;
       if_id_reg.inst <= Fence;
    end else begin
      if_id_reg.pc <= pc;
      if_id_reg.pc_plus_4 <= pc_plus_4;
      if_id_reg.inst <= inst;
    end
  end
  // Somador PC + 4
  sklansky_adder #(
      .INPUT_SIZE(DATA_SIZE)
  ) pc_4 (
      .A(pc),
      .B(cte_4),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_4)
  );
  always_comb begin
    if(_trap) new_pc = trap_addr;
    else if(mem_wb_reg.csr_op == CsrMret) new_pc = mepc;
    else if(mem_wb_reg.csr_op == CsrSret) new_pc = sepc;
    else begin
      unique case (_pc_src)
        PcOrReadDataPlusImm: begin
          new_pc = pc_plus_immediate;
        end
        default: begin // PcPlus4
          new_pc = pc_plus_4;
        end
      endcase
    end
  end
  register_d #(
      .N(DATA_SIZE),
      .reset_value(0)
  ) pc_register (
      .clock(clock),
      .reset(reset),
      .enable(~stall_if && ~mem_busy),
      .D(new_pc),
      .Q(pc)
  );
  // IF stage


  // ID stage
  logic [DATA_SIZE-1:0] forwarded_rs1_id, forwarded_rs2_id, forwarded_csr_id;
  always_comb begin : id_forwarding_logic
    unique case (forward_rs1_id)
      NoForwarding: begin
        forwarded_rs1_id = rs1;
      end
      ForwardFromEx: begin
        forwarded_rs1_id = id_ex_reg.pc_plus_4;
      end
      ForwardFromMem: begin
        unique case(ex_mem_reg.wr_reg_src)
          WrCsrRdData: forwarded_rs1_id = ex_mem_reg.csr_rd_data;
          WrPcPlus4: forwarded_rs1_id = ex_mem_reg.pc_plus_4;
          default: forwarded_rs1_id = ex_mem_reg.alu_y;
        endcase
      end
      ForwardFromWb: begin
        forwarded_rs1_id = rd;
      end
      default: begin
        forwarded_rs1_id = rs1;
      end
    endcase

    unique case (forward_rs2_id)
      NoForwarding: begin
        forwarded_rs2_id = rs2;
      end
      ForwardFromEx: begin
        forwarded_rs2_id = id_ex_reg.pc_plus_4;
      end
      ForwardFromMem: begin
        unique case(ex_mem_reg.wr_reg_src)
          WrCsrRdData: forwarded_rs2_id = ex_mem_reg.csr_rd_data;
          WrPcPlus4: forwarded_rs2_id = ex_mem_reg.pc_plus_4;
          default: forwarded_rs2_id = ex_mem_reg.alu_y;
        endcase
      end
      ForwardFromWb: begin
        forwarded_rs2_id = rd;
      end
      default: begin
        forwarded_rs2_id = rs2;
      end
    endcase

    unique case (forward_csr_id)
      ForwardFromWb: begin
        forwarded_csr_id = mem_wb_reg.csr_wr_data;
      end
      default: begin // No Forwarding, ForwardFromMem, ForwardFromEx
        forwarded_csr_id = csr_rd_data;
      end
    endcase
  end : id_forwarding_logic

  always_ff @(posedge clock iff (~stall_ex && ~mem_busy) or posedge reset) begin
    if (reset) id_ex_reg <= '0;
    else if (flush_ex) id_ex_reg <= '0;
    else begin
      id_ex_reg.pc <= if_id_reg.pc;
      id_ex_reg.pc_plus_4 <= if_id_reg.pc_plus_4;
      id_ex_reg.rs1 <= rs1_addr;
      id_ex_reg.read_data_1 <= forwarded_rs1_id;
      id_ex_reg.rs2 <= if_id_reg.inst[24:20];
      id_ex_reg.read_data_2 <= forwarded_rs2_id;
      id_ex_reg.rd <= if_id_reg.inst[11:7];
      id_ex_reg.imm <= immediate;
      id_ex_reg.csr_rd_data <= forwarded_csr_id;
      id_ex_reg.mem_read_enable <= mem_rd_en;
      id_ex_reg.mem_write_enable <= mem_wr_en;
      id_ex_reg.mem_byte_en <= mem_byte_en;
      id_ex_reg.mem_signed <= mem_signed;
      id_ex_reg.alua_src <= alua_src;
      id_ex_reg.alub_src <= alub_src;
      id_ex_reg.aluy_src <= aluy_src;
      id_ex_reg.alu_op <= alu_op;
      id_ex_reg.wr_reg_src <= wr_reg_src;
      id_ex_reg.wr_reg_en <= wr_reg_en;
      id_ex_reg.forwarding_type <= forwarding_type;
      id_ex_reg.csr_op <= csr_op;
      id_ex_reg.csr_imm <= csr_imm;
      id_ex_reg.inst <= if_id_reg.inst;
    end
  end

  // Register File
  // Instanciação de Componentes
  assign rs1_addr = if_id_reg.inst[19:15] & {5{(~(if_id_reg.inst[4] & if_id_reg.inst[2]))}};
  register_file #(
      .size(DATA_SIZE),
      .N(5)
  ) bank (
      .clock(clock),
      .reset(reset),
      .write_enable(mem_wb_reg.wr_reg_en && ~mem_busy && ~_trap),
      .read_address1(rs1_addr),
      .read_address2(if_id_reg.inst[24:20]),
      .write_address(mem_wb_reg.rd),
      .write_data(rd),
      .read_data1(rs1),
      .read_data2(rs2)
  );
  // Immediate Extender
  immediate_extender #(
      .N(DATA_SIZE)
  ) estende_imediato (
      .instruction(if_id_reg.inst),
      .immediate  (immediate)
  );
  // Somador PC + Imediato
  sklansky_adder #(
      .INPUT_SIZE(DATA_SIZE)
  ) pc_immediate (
      .A(alupc_src ? {forwarded_rs1_id[DATA_SIZE-1:1], 1'b0} : if_id_reg.pc),
      .B({immediate[DATA_SIZE-1:1], 1'b0}),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_immediate)
  );
  // CSR
  csr #(
    .DATA_SIZE(DATA_SIZE)
  ) csr_bank (
      .clock(clock),
      .reset(reset),
      .en(~mem_busy),
      .csr_op(mem_wb_reg.csr_op),
      // Interrupt Signals
      .external_interrupt(external_interrupt),
      .msip(|msip),
      .mtime(mtime),
      .mtimecmp(mtimecmp),
      .trap_addr(trap_addr),
      .trap(_trap),
      .exception(exception),
      .privilege_mode(_privilege_mode),
      .interrupt_pc(if_id_reg.pc == 0 ? pc : if_id_reg.pc),
      .exception_pc(mem_wb_reg.pc),
      .instruction(mem_wb_reg.inst),
      // CSR RW interface
      .rd_addr(if_id_reg.inst[31:20]),
      .wr_addr(mem_wb_reg.inst[31:20]),
      .wr_data(mem_wb_reg.csr_wr_data),
      .rd_data(csr_rd_data),
      // TrapReturn
      .mepc(mepc),
      .sepc(sepc)
  );
  always_comb begin : branch_type_logic

  end
  branch_decoder_unit #(
      .Width(DATA_SIZE)
  ) branch_decoder_unit_inst (
      .branch_type(branch_type),
      .cond_branch_type(cond_branch_type),
      .read_data_1(forwarded_rs1_id),
      .read_data_2(forwarded_rs2_id),
      .pc_src(_pc_src)
  );
  assign pc_src = _pc_src;
  // ID stage


  // EX stage
  logic [DATA_SIZE-1:0] forwarded_rs1_ex, forwarded_rs2_ex, forwarded_csr_ex;
  always_comb begin : ex_forwarding_logic
    unique case (forward_rs1_ex)
      NoForwarding, ForwardFromEx: begin
        forwarded_rs1_ex = id_ex_reg.read_data_1;
      end
      ForwardFromMem: begin
        unique case(ex_mem_reg.wr_reg_src)
          WrCsrRdData: forwarded_rs1_ex = ex_mem_reg.csr_rd_data;
          WrPcPlus4: forwarded_rs1_ex = ex_mem_reg.pc_plus_4;
          default: forwarded_rs1_ex = ex_mem_reg.alu_y;
        endcase
      end
      ForwardFromWb: begin
        forwarded_rs1_ex = rd;
      end
      default: begin
        forwarded_rs1_ex = id_ex_reg.read_data_1;
      end
    endcase

    unique case (forward_rs2_ex)
      NoForwarding, ForwardFromEx: begin
        forwarded_rs2_ex = id_ex_reg.read_data_2;
      end
      ForwardFromMem: begin
        unique case(ex_mem_reg.wr_reg_src)
          WrCsrRdData: forwarded_rs2_ex = ex_mem_reg.csr_rd_data;
          WrPcPlus4: forwarded_rs2_ex = ex_mem_reg.pc_plus_4;
          default: forwarded_rs2_ex = ex_mem_reg.alu_y;
        endcase
      end
      ForwardFromWb: begin
        forwarded_rs2_ex = rd;
      end
      default: begin
        forwarded_rs2_ex = id_ex_reg.read_data_2;
      end
    endcase

    unique case(forward_csr_ex)
      ForwardFromMem: begin
        forwarded_csr_ex = ex_mem_reg.csr_wr_data;
      end
      ForwardFromWb: begin
        forwarded_csr_ex = mem_wb_reg.csr_wr_data;
      end
      default: begin // No Forwarding
        forwarded_csr_ex = id_ex_reg.csr_rd_data;
      end
    endcase
  end : ex_forwarding_logic

  // CSR Read/Write Logic
  assign csr_mask_rd = '{SEI: (external_interrupt & csr_addr_t'(id_ex_reg.inst[31:20]) == Mip),
                         default: 1'b0};
  assign csr_mask_rd_data = forwarded_csr_ex | csr_mask_rd;
  assign csr_aux_wr = id_ex_reg.csr_imm ? $unsigned(id_ex_reg.inst[19:15]) : forwarded_rs1_ex;
  always_comb begin
    csr_wr_data = csr_aux_wr;
    unique case (id_ex_reg.csr_op)
      CsrRS: csr_wr_data = forwarded_csr_ex | csr_aux_wr;
      CsrRC: csr_wr_data = forwarded_csr_ex & (~csr_aux_wr);
      default: begin
      end
    endcase
  end

  always_ff @(posedge clock iff (~stall_mem && ~mem_busy) or posedge reset) begin
    if (reset) ex_mem_reg <= '0;
    else if(flush_mem) ex_mem_reg <= '0;
    else begin
      ex_mem_reg.pc <= id_ex_reg.pc;
      ex_mem_reg.pc_plus_4 <= id_ex_reg.pc_plus_4;
      ex_mem_reg.rs2 <= id_ex_reg.rs2;
      ex_mem_reg.rd <= id_ex_reg.rd;
      ex_mem_reg.csr_rd_data <= csr_mask_rd_data;
      ex_mem_reg.alu_y <= muxaluY_out;
      ex_mem_reg.write_data <= forwarded_rs2_ex;
      ex_mem_reg.mem_read_enable <= id_ex_reg.mem_read_enable;
      ex_mem_reg.mem_write_enable <= id_ex_reg.mem_write_enable;
      ex_mem_reg.mem_byte_en <= id_ex_reg.mem_byte_en;
      ex_mem_reg.mem_signed <= id_ex_reg.mem_signed;
      ex_mem_reg.wr_reg_src <= id_ex_reg.wr_reg_src;
      ex_mem_reg.wr_reg_en <= id_ex_reg.wr_reg_en;
      ex_mem_reg.forwarding_type <= id_ex_reg.forwarding_type;
      ex_mem_reg.csr_op <= id_ex_reg.csr_op;
      ex_mem_reg.csr_wr_data <= csr_wr_data;
      ex_mem_reg.inst <= id_ex_reg.inst;
    end
  end

  // ALU
generate;
  if(DATA_SIZE == 64) begin: gen_alu_in64
    assign aluA =
      id_ex_reg.alua_src ?
        id_ex_reg.pc : (id_ex_reg.aluy_src ?
          {{32{forwarded_rs1_ex[31]}}, forwarded_rs1_ex[31:0]} : forwarded_rs1_ex);
    assign aluB =
      id_ex_reg.alub_src ?
        id_ex_reg.imm : (id_ex_reg.aluy_src ?
          {{32{forwarded_rs2_ex[31]}}, forwarded_rs2_ex[31:0]} : forwarded_rs2_ex);
    assign muxaluY_out[DATA_SIZE-1:32] = id_ex_reg.aluy_src ? {32{aluY[31]}} : aluY[DATA_SIZE-1:32];
  end else begin: gen_alu_in32
    assign aluA = id_ex_reg.alua_src ? id_ex_reg.pc : forwarded_rs1_ex;
    assign aluB = id_ex_reg.alub_src ? id_ex_reg.imm : forwarded_rs2_ex;
  end
endgenerate
  assign muxaluY_out[31:0] = aluY[31:0];

  alu #(
      .N(DATA_SIZE)
  ) alu (
      .A(aluA),
      .B(aluB),
      .alu_op(id_ex_reg.alu_op),
      .Y(aluY),
      .zero(),
      .negative(),
      .carry_out(),
      .overflow()
  );
  // EX stage


  // MEM stage
  logic [DATA_SIZE-1:0] forwarded_rs2_mem;
  always_comb begin : mem_forwarding_logic
    unique case (forward_rs2_mem)
      NoForwarding, ForwardFromEx, ForwardFromMem: begin
        forwarded_rs2_mem = ex_mem_reg.write_data;
      end
      ForwardFromWb: begin
        forwarded_rs2_mem = rd;
      end
      default: begin
        forwarded_rs2_mem = ex_mem_reg.write_data;
      end
    endcase
  end : mem_forwarding_logic

  always_ff @(posedge clock iff (~stall_wb && ~mem_busy) or posedge reset) begin
    if (reset) mem_wb_reg <= '0;
    else if(flush_wb) mem_wb_reg <= '0;
    else begin
      mem_wb_reg.pc <= ex_mem_reg.pc;
      mem_wb_reg.pc_plus_4 <= ex_mem_reg.pc_plus_4;
      mem_wb_reg.rd <= ex_mem_reg.rd;
      mem_wb_reg.csr_rd_data <= ex_mem_reg.csr_rd_data;
      mem_wb_reg.alu_y <= ex_mem_reg.alu_y;
      mem_wb_reg.read_data <= rd_data;
      mem_wb_reg.wr_reg_src <= ex_mem_reg.wr_reg_src;
      mem_wb_reg.wr_reg_en <= ex_mem_reg.wr_reg_en;
      mem_wb_reg.csr_op <= ex_mem_reg.csr_op;
      mem_wb_reg.csr_wr_data <= ex_mem_reg.csr_wr_data;
      mem_wb_reg.inst <= ex_mem_reg.inst;
    end
  end

  gen_mux #(
      .size(DATA_SIZE),
      .N(2)
  ) wb_mux41 (
      .A({mem_wb_reg.pc_plus_4, mem_wb_reg.read_data, mem_wb_reg.csr_rd_data, mem_wb_reg.alu_y}),
      .S(mem_wb_reg.wr_reg_src),
      .Y(rd)
  );
  // MEM stage

  // Saídas
  // Memory
  assign mem_unit_en = ~exception;
  assign inst_mem_addr = pc;
  assign data_mem_addr = ex_mem_reg.alu_y;
  assign rd_en = ex_mem_reg.mem_read_enable;
  assign wr_en = ex_mem_reg.mem_write_enable;
  assign signed_en = ex_mem_reg.mem_signed;
  assign byte_en = ex_mem_reg.mem_byte_en;
  assign wr_data = forwarded_rs2_mem;
  // Control Unit
  assign opcode = opcode_t'(if_id_reg.inst[6:0]);
  assign funct3 = if_id_reg.inst[14:12];
  assign funct7 = if_id_reg.inst[31:25];
  assign privilege_mode = _privilege_mode;

  // Forwarding Unit: Register Bank
  assign forwarding_type_id = forwarding_type;
  assign forwarding_type_ex = id_ex_reg.forwarding_type;
  assign forwarding_type_mem = ex_mem_reg.forwarding_type;
  assign reg_we_mem = ex_mem_reg.wr_reg_en;
  assign reg_we_wb = mem_wb_reg.wr_reg_en;
  assign rd_ex = id_ex_reg.rd;
  assign rd_mem = ex_mem_reg.rd;
  assign rd_wb = mem_wb_reg.rd;
  assign rs1_id = rs1_addr;
  assign rs2_id = if_id_reg.inst[24:20];
  assign rs1_ex = id_ex_reg.rs1;
  assign rs2_ex = id_ex_reg.rs2;
  assign rs2_mem = ex_mem_reg.rs2;

  // Forwarding Unit: CSR Bank
  assign csr_we_mem = (ex_mem_reg.csr_op == CsrRW) ||
                      ((ex_mem_reg.csr_op inside {CsrRS, CsrRC}) && (|ex_mem_reg.inst[19:15]));
  assign csr_we_wb = (mem_wb_reg.csr_op == CsrRW) ||
                     ((mem_wb_reg.csr_op inside {CsrRS, CsrRC}) && (|mem_wb_reg.inst[19:15]));
  assign csr_addr_id = if_id_reg.inst[31:20];
  assign csr_addr_ex = id_ex_reg.inst[31:20];
  assign csr_addr_mem = ex_mem_reg.inst[31:20];
  assign csr_addr_wb = mem_wb_reg.inst[31:20];
  // Hazard Unit
  assign interrupt = _trap && !exception;
  assign flush_all = exception | (mem_wb_reg.csr_op inside {CsrSret, CsrMret});
  assign rd_complete_ex = id_ex_reg.wr_reg_src inside {WrPcPlus4};
  assign reg_we_ex = id_ex_reg.wr_reg_en;
  assign mem_rd_en_ex = id_ex_reg.mem_read_enable;
  assign mem_rd_en_mem = ex_mem_reg.mem_read_enable;
  assign store_id = mem_wr_en;

endmodule
