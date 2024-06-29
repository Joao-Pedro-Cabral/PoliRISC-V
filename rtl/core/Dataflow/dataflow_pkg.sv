package dataflow_pkg;
  import extensions_pkg::*;
  import forwarding_unit_pkg::*;
  import instruction_pkg::*;
  import alu_pkg::*;
  import control_unit_pkg::*;
  import csr_pkg::*;

  typedef enum logic [2:0] {
    Fetch,
    Decode,
    Execute,
    Memory,
    WriteBack
  } stages_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [DataSize-1:0] pc_plus_4;
    instruction_t inst;
  } if_id_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [DataSize-1:0] pc_plus_4;
    logic [4:0] rs1;
    logic [DataSize-1:0] read_data_1;
    logic [4:0] rs2;
    logic [DataSize-1:0] read_data_2;
    logic [4:0] rd;
    logic [DataSize-1:0] imm;
    logic [DataSize-1:0] csr_rd_data;
    logic zicsr;
    logic mem_read_enable;
    logic mem_write_enable;
    logic [DataSize/8-1:0] mem_byte_en;
    logic mem_signed;
    logic alua_src;
    logic alub_src;
    logic aluy_src;
    alu_op_t alu_op;
    wr_reg_t wr_reg_src;
    logic wr_reg_en;
    forwarding_type_t forwarding_type;
    csr_op_t csr_op;
    logic csr_imm;
    instruction_t inst;
  } id_ex_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [DataSize-1:0] pc_plus_4;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_rd_data;
    logic zicsr;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] write_data;
    logic mem_read_enable;
    logic mem_write_enable;
    logic [DataSize/8-1:0] mem_byte_en;
    logic mem_signed;
    wr_reg_t wr_reg_src;
    logic wr_reg_en;
    forwarding_type_t forwarding_type;
    csr_op_t csr_op;
    logic csr_imm;
    logic [DataSize-1:0] csr_wr_data;
    instruction_t inst;
  } ex_mem_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [DataSize-1:0] pc_plus_4;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_rd_data;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] read_data;
    wr_reg_t wr_reg_src;
    logic wr_reg_en;
    csr_op_t csr_op;
    logic csr_imm;
    logic [DataSize-1:0] csr_wr_data;
    instruction_t inst;
  } mem_wb_t;

endpackage
