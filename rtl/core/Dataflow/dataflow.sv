import csr_pkg::*;
import dataflow_pkg::*;
import hazard_unit_pkg::*;
import instruction_pkg::*;

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
    input wire pc_src,
    input wire pc_en,
    input wire [1:0] wr_reg_src,
    input wire wr_reg_en,
    input logic mem_rd_en,
    input logic mem_wr_en,
    input logic [DATA_SIZE/8-1:0] mem_byte_en,
    input wire mem_addr_src,
    input forwarding_type_t forwarding_type,
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
    output wire csr_addr_exception,
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
    output hazard_t hazard_type,
    output rs_used_t rs_used,
    output logic [4:0] rs1_id,
    output logic [4:0] rs2_id,
    output logic [4:0] rd_ex,
    output logic [4:0] rd_mem,
    output logic reg_we_ex,
    output logic reg_we_mem,
    output logic mem_rd_en_ex,
    output logic mem_rd_en_mem,
    //output logic zicsr_ex,
    output logic store_id
    // TODO: add branch decoder unit signals
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

  // PC
  always_comb begin
    if (_trap) new_pc = trap_addr;
    else if (csr_op == CsrMret) new_pc = mepc;
    else if (csr_op == CsrSret) new_pc = sepc;
    else if (pc_src) new_pc = pc_plus_immediate;
    else new_pc = pc_plus_4;
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

  // Memory
  assign inst_mem_addr = pc;
  // IF stage


  // ID stage
  always_ff @(posedge clock iff (~stall_id && ~mem_busy) or posedge reset) begin
    if (reset) id_ex_reg <= '0;
    else if (flush_ex) id_ex_reg <= '0;
    else begin
      id_ex_reg.pc <= if_id_reg.pc;
      id_ex_reg.pc_plus_4 <= if_id_reg.pc_plus_4;
      id_ex_reg.rs1 <= rs1_addr;
      id_ex_reg.read_data_1 <= rs1;
      id_ex_reg.rs2 <= if_id_reg.inst[24:20];
      id_ex_reg.read_data_2 <= rs2;
      id_ex_reg.rd <= if_id_reg.inst[11:7];
      id_ex_reg.imm <= immediate;
      id_ex_reg.csr_read_data <= csr_mask_rd_data;
      id_ex_reg.zicsr <= if_id_reg.inst.opcode == SystemType &&
        ~if_id_reg.inst.fields.i_type.funct3;
      id_ex_reg.mem_read_enable <= mem_rd_en;
      id_ex_reg.mem_wr_en <= mem_wr_en;
      id_ex_reg.mem_byte_en <= mem_byte_en;
      id_ex_reg.alua_src <= alua_src;
      id_ex_reg.alub_src <= alub_src;
`ifdef RV64I
      id_ex_reg.aluy_src <= aluy_src;
`endif
      id_ex_reg.alu_op <= alu_op;
      id_ex_reg.alupc_src <= alupc_src;  // TODO: analyze the use of alupc_src in the file
    end
  end

  // Register File
  // Instanciação de Componentes
  // caso seja realizada uma leitura do SEIP(9) é preciso realizar o OR com o external_interrupt
  assign csr_mask_rd_data[8:0] = csr_rd_data[8:0];
  assign csr_mask_rd_data[9] = (if_id_reg.inst[31:20] == 12'h344 || if_id_reg.inst[31:20] == 12'h144)
                                            ? (csr_rd_data[9] | external_interrupt)
                                            : csr_rd_data[9];
  assign csr_mask_rd_data[DATA_SIZE-1:10] = csr_rd_data[DATA_SIZE-1:10];
  assign rs1_addr = if_id_reg.inst[19:15] & {5{(~(if_id_reg.inst[4] & if_id_reg.inst[2]))}};
  register_file #(
      .size(DATA_SIZE),
      .N(5)
  ) int_reg_state (
      .clock(clock),
      .reset(reset),
      // You can't write an illegal value coming from CSR
      .write_enable(wr_reg_en && !(wr_reg_src == 2'b01 && csr_addr_exception)),
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
  // CSR
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
      .addr_exception(csr_addr_exception),
      .pc(pc),
      .instruction(if_id_reg.inst),
      // CSR RW interface
      .addr(if_id_reg.inst[31:20]),
      .wr_data(csr_aux_wr),
      .rd_data(csr_rd_data),
      // TrapReturn
      .mepc(mepc),
      .sepc(sepc)
  );

  // ID stage

  // ULA
`ifdef RV64I
  assign aluA = id_ex_reg.alua_src ? id_ex_reg.pc : (id_ex_reg.aluy_src ? {{32{id_ex_reg.read_data_1[31]}}, id_ex_reg.read_data_1[31:0]} : id_ex_reg.read_data_1);
  assign aluB = id_ex_reg.alub_src ? immediate : (aluy_src ? {{32{id_ex_reg.read_data_2[31]}}, id_ex_reg.read_data_2[31:0]} : id_ex_reg.read_data_2);
  assign muxaluY_out[DATA_SIZE-1:32] = aluy_src ? {32{aluY[31]}} : aluY[DATA_SIZE-1:32];
`else
  assign aluA = id_ex_reg.alua_src ? id_ex_reg.pc : id_ex_reg.read_data_1;
  assign aluB = id_ex_reg.alub_src ? immediate : id_ex_reg.read_data_2;
`endif

  ULA #(
      .N(DATA_SIZE)
  ) alu (
      .A(aluA),
      .B(aluB),
      .seletor(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .Y(aluY),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow)
  );
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
  // Somador PC + Imediato
  sklansky_adder #(
      .INPUT_SIZE(DATA_SIZE)
  ) pc_immediate (
      .A(alupc_src ? {rs1[DATA_SIZE-1:1], 1'b0} : pc),
      .B({immediate[DATA_SIZE-1:1], 1'b0}),
      .c_in(1'b0),
      .c_out(),
      .S(pc_plus_immediate)
  );
  gen_mux #(
      .size(DATA_SIZE),
      .N(2)
  ) mux11 (
      .A({mem_wb_reg.pc_plus_4, mem_wb_reg.read_data, mem_wb_reg.csr_read_data, muxaluY_out}),
      .S(mem_wb_reg.wr_reg_src),
      .Y(rd)
  );

  // Atribuições intermediárias
  // Mascarar LUI no Rs1
  assign muxaluY_out[31:0] = aluY[31:0];

  // Zicsr
  assign csr_aux_wr = csr_imm ? $unsigned(if_id_reg.inst[19:15]) : rs1;

  // Saídas
  // Memory
  assign wr_data = ex_mem_reg.read_data_2;
  // Control Unit
  assign opcode = if_id_reg.inst[6:0];
  assign funct3 = if_id_reg.inst[14:12];
  assign funct7 = if_id_reg.inst[31:25];
  assign privilege_mode = _privilege_mode;

endmodule
