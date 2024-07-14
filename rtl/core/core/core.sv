
module core #(
    parameter integer DATA_SIZE = 32
) (
    // Common
    input logic clock,
    input logic reset,
    // Bus Interface
    wishbone_if.primary wish_proc0,
    wishbone_if.primary wish_proc1,
    // Interrupts from Memory
    input logic external_interrupt,
    input logic [DATA_SIZE-1:0] msip,
    input logic [63:0] mtime,
    input logic [63:0] mtimecmp
);

  ///////////////////////////////////
  ///////////// Imports /////////////
  ///////////////////////////////////
  import csr_pkg::*;
  import dataflow_pkg::*;
  import hazard_unit_pkg::*;
  import instruction_pkg::*;
  import branch_decoder_unit_pkg::*;
  import forwarding_unit_pkg::*;
  import alu_pkg::*;
  import control_unit_pkg::*;

  ///////////////////////////////////
  //////////// Parameters ///////////
  ///////////////////////////////////
  localparam integer ByteNum = DATA_SIZE/8;

  ///////////////////////////////////
  /////////// DUT Signals ///////////
  ///////////////////////////////////
  // To Memory Unit
  logic mem_unit_en;
  // Instruction Memory
  instruction_t inst;
  logic [DATA_SIZE-1:0] inst_mem_addr;
  // Data Memory
  logic [DATA_SIZE-1:0] rd_data;
  logic rd_en;
  logic wr_en;
  logic [DATA_SIZE/8-1:0] byte_en;
  logic signed_en;
  logic [DATA_SIZE-1:0] wr_data;
  logic [DATA_SIZE-1:0] data_mem_addr;
  // From Memory Unit
  logic mem_busy;
  // From Control Unit
  logic alua_src;
  logic alub_src;
  logic aluy_src;
  alu_op_t alu_op;
  logic alupc_src;
  wr_reg_t wr_reg_src;
  logic wr_reg_en;
  logic mem_rd_en;
  logic mem_wr_en;
  logic [ByteNum-1:0] mem_byte_en;
  logic mem_signed;
  forwarding_type_t forwarding_type;
  branch_t branch_type;
  cond_branch_t cond_branch_type;
  // Trap Return
  csr_op_t csr_op;
  logic csr_imm;
  // To Control Unit
  opcode_t opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  privilege_mode_t privilege_mode;
  // From Forwarding Unit : Register Bank
  forwarding_t forward_rs1_id;
  forwarding_t forward_rs2_id;
  forwarding_t forward_rs1_ex;
  forwarding_t forward_rs2_ex;
  forwarding_t forward_rs2_mem;
  // To Forwarding Unit : Register Bank
  forwarding_type_t forwarding_type_id;
  forwarding_type_t forwarding_type_ex;
  forwarding_type_t forwarding_type_mem;
  logic reg_we_mem;
  logic reg_we_wb;
  logic rd_complete_ex;
  logic [4:0] rd_ex;
  logic [4:0] rd_mem;
  logic [4:0] rd_wb;
  logic [4:0] rs1_id;
  logic [4:0] rs2_id;
  logic [4:0] rs1_ex;
  logic [4:0] rs2_ex;
  logic [4:0] rs2_mem;
  // From Forwarding Unit: CSR Bank
  forwarding_t forward_csr_id;
  forwarding_t forward_csr_ex;
  // To Forwarding Unit: CSR Bank
  logic csr_we_mem;
  logic csr_we_wb;
  logic [11:0] csr_addr_id;
  logic [11:0] csr_addr_ex;
  logic [11:0] csr_addr_mem;
  logic [11:0] csr_addr_wb;
  // From Hazard Unit
  logic stall_if;
  logic stall_id;
  logic stall_ex;
  logic stall_mem;
  logic stall_wb;
  logic flush_id;
  logic flush_ex;
  logic flush_mem;
  logic flush_wb;
  // To Hazard Unit
  pc_src_t pc_src;
  logic interrupt;
  logic flush_all;
  logic reg_we_ex;
  logic mem_rd_en_ex;
  logic mem_rd_en_mem;
  logic store_id;
  // Others
  hazard_t hazard_type;
  rs_used_t rs_used;

  ///////////////////////////////////
  /////////// Dataflow //////////////
  ///////////////////////////////////
  dataflow #(
    .DATA_SIZE(DATA_SIZE)
  ) DUT (
    .clock,
    .reset,
    .mem_unit_en,
    .inst,
    .inst_mem_addr,
    .rd_data,
    .rd_en,
    .wr_en,
    .byte_en,
    .signed_en,
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
    .csr_op,
    .csr_imm,
    .external_interrupt,
    .msip,
    .mtime,
    .mtimecmp,
    .opcode,
    .funct3,
    .funct7,
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
    .rd_complete_ex,
    .rd_ex,
    .rd_mem,
    .rd_wb,
    .rs1_id,
    .rs2_id,
    .rs1_ex,
    .rs2_ex,
    .rs2_mem,
    .forward_csr_id,
    .forward_csr_ex,
    .csr_we_mem,
    .csr_we_wb,
    .csr_addr_id,
    .csr_addr_ex,
    .csr_addr_mem,
    .csr_addr_wb,
    .stall_if,
    .stall_id,
    .stall_ex,
    .stall_mem,
    .stall_wb,
    .flush_id,
    .flush_ex,
    .flush_mem,
    .flush_wb,
    .pc_src,
    .interrupt,
    .flush_all,
    .reg_we_ex,
    .mem_rd_en_ex,
    .mem_rd_en_mem,
    .store_id
  );

  ///////////////////////////////////
  ///////// Control Units ///////////
  ///////////////////////////////////
  control_unit #(
    .BYTE_NUM(ByteNum)
  ) controlUnit (
    .*
  );

  hazard_unit hazardUnit (
    .*
  );

  forwarding_unit #(
    .N(5)
  ) bankForwardingUnit (
    .*
  );

  forwarding_unit #(
    .N(12)
  ) csrForwardingUnit (
    .forwarding_type_id(ForwardExecute),
    .forwarding_type_ex(ForwardExecute),
    .forwarding_type_mem(ForwardExecute),
    .reg_we_ex(1'b0),
    .reg_we_mem(csr_we_mem),
    .reg_we_wb(csr_we_wb),
    .rd_ex(12'h0),
    .rd_mem(csr_addr_mem),
    .rd_wb(csr_addr_wb),
    .rs1_id(csr_addr_id),
    .rs2_id(12'h0),
    .rs1_ex(csr_addr_ex),
    .rs2_ex(12'h0),
    .rs2_mem(12'h0),
    .forward_rs1_id(forward_csr_id),
    .forward_rs2_id(),
    .forward_rs1_ex(forward_csr_ex),
    .forward_rs2_ex(),
    .forward_rs2_mem()
  );

  memory_unit #(
    .InstSize(32),
    .DataSize(DATA_SIZE)
  ) memoryUnit (
    .clock,
    .reset,
    .en(mem_unit_en),
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
  assign wish_proc1.tgd = signed_en;
  assign wish_proc1.addr = data_mem_addr;
  assign wish_proc1.sel = byte_en;
  assign wish_proc1.dat_o_p = wr_data;

endmodule
