import csr_pkg::*;
import dataflow_pkg::*;
import hazard_unit_pkg::*;
import instruction_pkg::*;
import branch_decoder_unit_pkg::*;

module dataflow #(
    parameter integer DATA_SIZE = 32
) (
    // Common
    input wire clock,
    input wire reset,
    // Instruction Memory
    input instruction_t inst,
    output wire [DATA_SIZE-1:0] inst_mem_addr,
    // Data Memory
    input wire [DATA_SIZE-1:0] rd_data,
    output wire rd_en,
    output wire wr_en,
    output wire [DATA_SIZE-1:0] wr_data,
    output wire [DATA_SIZE-1:0] data_mem_addr,
    // From Memory Unit
    input logic mem_busy,
    // From Control Unit
    input wire alua_src,
    input wire alub_src,
`ifdef RV64I
    input wire aluy_src,
`endif
    input alu_op_t alu_op,
    input wire alupc_src,
    input wire [1:0] wr_reg_src,
    input wire wr_reg_en,
    input logic mem_rd_en,
    input logic mem_wr_en,
    input logic [DATA_SIZE/8-1:0] mem_byte_en,
    input wire mem_addr_src,
    input forwarding_type_t forwarding_type,
    input branch_t branch_type,
    input cond_branch_t cond_branch_type,
    // Interrupts/Exceptions from UC
    input wire ecall,
    input wire illegal_instruction,
    // Trap Return
    input csr_op_t csr_op,
    // Interrupts from Memory
    input wire external_interrupt,
    input wire [DATA_SIZE-1:0] mem_msip,
    input wire [63:0] mem_mtime,
    input wire [63:0] mem_mtimecmp,
    input wire csr_wr_en,
    input wire [1:0] csr_op,
    input wire csr_imm,
    // To Control Unit
    output wire [6:0] opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire csr_addr_invalid,
    output privilege_mode_t privilege_mode,
    // From Forwarding Unit
    input forwarding_t forward_rs1_id,
    input forwarding_t forward_rs2_id,
    input forwarding_t forward_rs1_ex,
    input forwarding_t forward_rs2_ex,
    input forwarding_t forward_rs2_mem,
    // To Forwarding Unit
    output forwarding_type_t forwarding_type_id,
    output forwarding_type_t forwarding_type_ex,
    output forwarding_type_t forwarding_type_mem,
    output logic reg_we_mem,
    output logic reg_we_wb,
    output logic zicsr_ex,
    output logic [4:0] rd_ex,
    output logic [4:0] rd_mem,
    output logic [4:0] rd_wb,
    output logic [4:0] rs1_id,
    output logic [4:0] rs2_id,
    output logic [4:0] rs1_ex,
    output logic [4:0] rs2_ex,
    output logic [4:0] rs2_mem,
    // From Hazard Unit
    input logic stall_if,
    input logic stall_id,
    input logic flush_id,
    input logic flush_ex,
    // To Hazard Unit
    /* output logic [4:0] rs1_id, */
    /* output logic [4:0] rs2_id, */
    /* output logic [4:0] rd_ex, */
    /* output logic [4:0] rd_mem, */
    output logic reg_we_ex,
    output logic reg_we_mem,
    output logic mem_rd_en_ex,
    output logic mem_rd_en_mem,
    /* output logic zicsr_ex, */
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
  // ULA
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
  // ZICSR
  wire             [DATA_SIZE-1:0] csr_rd_data;
  wire             [DATA_SIZE-1:0] csr_mask_rd_data;
  wire             [DATA_SIZE-1:0] csr_aux_wr;
  // Branch Decoder Unit
  pc_src_t                         pc_src;

  // IF stage
  always_ff @(posedge clock iff (~stall_if && ~mem_busy) or posedge reset) begin
    if (reset) if_id_reg <= '0;
    else if (flush_id) if_id_reg <= '0;
    else begin
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
    unique case (pc_src)
      PcPlus4: begin
        new_pc = trap_addr;
      end
      Sepc: begin
        new_pc = sepc;
      end
      Mepc: begin
        new_pc = mepc;
      end
      PcOrReadDataPlusImm: begin
        new_pc = pc_plus_immediate;
      end
      default: begin
        new_pc = pc_plus_4;
      end
    endcase
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
  logic [DATA_SIZE-1:0] forwarded_rs1_id, forwarded_rs2_id;
  always_comb begin : id_forwarding_logic
    unique case (forward_rs1_id)
      NoForwarding: begin
        forwarded_rs1_id = rs1;
      end
      ForwardFromEx: begin
        forwarded_rs1_id = id_ex_reg.csr_read_data;
      end
      ForwardFromMem: begin
        forwarded_rs1_id = ex_mem_reg.zicsr ? ex_mem_reg.csr_read_data : ex_mem_reg.alu_y;
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
        forwarded_rs2_id = id_ex_reg.csr_read_data;
      end
      ForwardFromMem: begin
        forwarded_rs2_id = ex_mem_reg.zicsr ? ex_mem_reg.csr_read_data : ex_mem_reg.alu_y;
      end
      ForwardFromWb: begin
        forwarded_rs2_id = rd;
      end
      default: begin
        forwarded_rs2_id = rs2;
      end
    endcase
  end : id_forwarding_logic

  always_ff @(posedge clock iff (~stall_id && ~mem_busy) or posedge reset) begin
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
      id_ex_reg.csr_read_data <= csr_mask_rd_data;
      id_ex_reg.zicsr <=
        if_id_reg.inst.opcode == SystemType && ~if_id_reg.inst.fields.i_type.funct3;
      id_ex_reg.mem_read_enable <= mem_rd_en;
      id_ex_reg.mem_wr_en <= mem_wr_en;
      id_ex_reg.mem_byte_en <= mem_byte_en;
      id_ex_reg.alua_src <= alua_src;
      id_ex_reg.alub_src <= alub_src;
`ifdef RV64I
      id_ex_reg.aluy_src <= aluy_src;
`endif
      id_ex_reg.alu_op <= alu_op;
      id_ex_reg.wr_reg_src <= wr_reg_src;
      id_ex_reg.wr_reg_en <= wr_reg_en;
      id_ex_reg.forwarding_type <= forwarding_type;
    end
  end

  // Register File
  // Instanciação de Componentes
  // caso seja realizada uma leitura do SEIP(9) é preciso realizar o OR com o external_interrupt
  assign rs1_addr = if_id_reg.inst[19:15] & {5{(~(if_id_reg.inst[4] & if_id_reg.inst[2]))}};
  register_file #(
      .size(DATA_SIZE),
      .N(5)
  ) int_reg_state (
      .clock(clock),
      .reset(reset),
      // You can't write an illegal value coming from CSR
      // FIXME: what to do w/ csr_addr_invalid
      .write_enable(mem_wb_reg.wr_reg_en),
      .read_address1(rs1_addr),
      .read_address2(if_id_reg.inst[24:20]),
      .write_address(if_id_reg.inst[11:7]),
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
  assign csr_mask_rd_data[8:0] = csr_rd_data[8:0];
  assign csr_mask_rd_data[9] =
    (if_id_reg.inst[31:20] == 12'h344 || if_id_reg.inst[31:20] == 12'h144)
                                            ? (csr_rd_data[9] | external_interrupt)
                                            : csr_rd_data[9];
  assign csr_mask_rd_data[DATA_SIZE-1:10] = csr_rd_data[DATA_SIZE-1:10];
  assign csr_aux_wr = csr_imm ? $unsigned(if_id_reg.inst[19:15]) : forwarded_rs1_id;
  CSR csr_bank (
      .clock(clock),
      .reset(reset),
      .trap_en(~stall_id && ~mem_busy),
      .csr_op(csr_op),
      // Interrupt/Exception Signals
      .ecall(ecall),
      .illegal_instruction(illegal_instruction),
      .external_interrupt(external_interrupt),
      .msip(|mem_msip),
      .mtime(mem_mtime),
      .mtimecmp(mem_mtimecmp),
      .trap_addr(trap_addr),
      .trap(_trap),
      .privilege_mode(_privilege_mode),
      .addr_exception(csr_addr_invalid),
      .pc(if_id_reg.pc),
      .instruction(if_id_reg.inst),
      // CSR RW interface
      .addr(if_id_reg.inst[31:20]),
      .wr_data(csr_aux_wr),
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
      .read_data_1(rs1),
      .read_data_2(rs2),
      .pc_src(pc_src)
  );
  // ID stage


  // EX stage
  logic [DATA_SIZE-1:0] forwarded_rs1_ex, forwarded_rs2_ex;
  always_comb begin : ex_forwarding_logic
    unique case (forward_rs1_ex)
      NoForwarding, ForwardFromEx: begin
        forwarded_rs1_ex = id_ex_reg.read_data_1;
      end
      ForwardFromMem: begin
        forwarded_rs1_ex = ex_mem_reg.zicsr ? ex_mem_reg.csr_read_data : ex_mem_reg.alu_y;
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
        forwarded_rs2_ex = ex_mem_reg.zicsr ? ex_mem_reg.csr_read_data : ex_mem_reg.alu_y;
      end
      ForwardFromWb: begin
        forwarded_rs2_ex = rd;
      end
      default: begin
        forwarded_rs2_ex = id_ex_reg.read_data_2;
      end
    endcase
  end : ex_forwarding_logic

  always_ff @(posedge clock iff (~mem_busy) or posedge reset) begin
    if (reset) ex_mem_reg <= '0;
    else begin
      ex_mem_reg.pc_plus_4 <= id_ex_reg.pc_plus_4;
      ex_mem_reg.rs2 <= id_ex_reg.rs2;
      ex_mem_reg.rd <= id_ex_reg.rd;
      ex_mem_reg.csr_read_data <= id_ex_reg.csr_read_data;
      ex_mem_reg.zicsr <= id_ex_reg.zicsr;
      ex_mem_reg.alu_y <= muxaluY_out;
      ex_mem_reg.write_data <= id_ex_reg.read_data_2;
      ex_mem_reg.mem_read_enable <= id_ex_reg.mem_read_enable;
      ex_mem_reg.mem_write_enable <= id_ex_reg.mem_write_enable;
      ex_mem_reg.mem_byte_en <= id_ex_reg.mem_byte_enable;
      ex_mem_reg.wr_reg_src <= id_ex_reg.wr_reg_src;
      ex_mem_reg.wr_reg_en <= id_ex_reg.wr_reg_en;
      ex_mem_reg.forwarding_type <= id_ex_reg.forwarding_type;
    end
  end

  // ULA
`ifdef RV64I
  assign aluA =
    id_ex_reg.alua_src ?
      id_ex_reg.pc : (id_ex_reg.aluy_src ?
        {{32{forwarded_rs1_ex[31]}}, forwarded_rs1_ex[31:0]} : forwarded_rs1_ex);
  assign aluB =
    id_ex_reg.alub_src ?
      id_ex_reg.imm : (id_ex_reg.aluy_src ?
        {{32{forwarded_rs2_ex[31]}}, forwarded_rs2_ex[31:0]} : forwarded_rs2_ex);
  assign muxaluY_out[DATA_SIZE-1:32] = id_ex_reg.aluy_src ? {32{aluY[31]}} : aluY[DATA_SIZE-1:32];
`else
  assign aluA = id_ex_reg.alua_src ? id_ex_reg.pc : forwarded_rs1_ex;
  assign aluB = id_ex_reg.alub_src ? id_ex_reg.imm : forwarded_rs2_ex;
`endif
  // Mascarar LUI no Rs1
  assign muxaluY_out[31:0] = aluY[31:0];

  ULA #(
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
  logic [DATA_SIZE-1:0] forwarded_rs1_mem, forwarded_rs2_mem;
  always_comb begin : ex_forwarding_logic
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
  end : ex_forwarding_logic

  always_ff @(posedge clock iff (~mem_busy) or posedge reset) begin
    if (reset) mem_wb_reg <= '0;
    else begin
      mem_wb_reg.pc_plus_4 <= ex_mem_reg.pc_plus_4;
      mem_wb_reg.rd <= ex_mem_reg.rd;
      mem_wb_reg.csr_read_data <= ex_mem_reg.csr_read_data;
      mem_wb_reg.alu_y <= ex_mem_reg.alu_y;
      mem_wb_reg.read_data <= rd_data;
      mem_wb_reg.wr_reg_src <= ex_mem_reg.wr_reg_src;
      mem_wb_reg.wr_reg_en <= ex_mem_reg.wr_reg_en;
    end
  end
  gen_mux #(
      .size(DATA_SIZE),
      .N(2)
  ) mux11 (
      .A({mem_wb_reg.pc_plus_4, mem_wb_reg.read_data, mem_wb_reg.csr_read_data, mem_wb_reg.alu_y}),
      .S(mem_wb_reg.wr_reg_src),
      .Y(rd)
  );
  // MEM stage

  // Saídas
  // Memory
  assign inst_mem_addr = pc;
  assign data_mem_addr = ex_mem_reg.alu_y;
  assign rd_en = ex_mem_reg.mem_read_enable;
  assign wr_en = ex_mem_reg.mem_write_enable;
  assign wr_data = forwarded_rs2_mem;
  // Control Unit
  assign opcode = if_id_reg.inst[6:0];
  assign funct3 = if_id_reg.inst[14:12];
  assign funct7 = if_id_reg.inst[31:25];
  assign privilege_mode = _privilege_mode;

  // Forwarding Unit
  assign forwarding_type_id = forwarding_type;
  assign forwarding_type_ex = id_ex_reg.forwarding_type;
  assign forwarding_type_mem = ex_mem_reg.forwarding_type;
  assign reg_we_mem = ex_mem_reg.wr_reg_en;
  assign reg_we_wb = mem_wb_reg.wr_reg_en;
  assign zicsr_ex = id_ex_reg.zicsr;
  assign rd_ex = id_ex_reg.rd;
  assign rd_mem = ex_mem_reg.rd;
  assign rd_wb = mem_wb_reg.rd;
  assign rs1_id = rs1_addr;
  assign rs2_id = if_id_reg.inst[24:20];
  assign rs1_ex = id_ex_reg.rs1;
  assign rs2_ex = id_ex_reg.rs2;
  assign rs2_mem = ex_mem_reg.rs2;

  // Hazard Unit
  assign reg_we_ex = id_ex_reg.wr_reg_en;
  assign reg_we_mem = ex_mem_reg.wr_reg_en;
  assign mem_rd_en_ex = id_ex_reg.mem_read_enable;
  assign mem_rd_en_mem = ex_mem_reg.mem_read_enable;
  assign store_id = id_ex_reg.mem_write_enable;

endmodule
