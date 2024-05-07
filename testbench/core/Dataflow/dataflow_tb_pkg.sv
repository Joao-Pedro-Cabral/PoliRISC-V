
package dataflow_tb_pkg;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    instruction_t inst;
  } if_id_tb_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [4:0] rs1;
    logic [DataSize-1:0] read_data_1;
    logic [4:0] rs2;
    logic [DataSize-1:0] read_data_2;
    logic [4:0] rd;
    logic [DataSize-1:0] imm;
    logic [DataSize-1:0] csr_read_data;
    instruction_t inst;
  } id_ex_tb_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_read_data;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] write_data;
    instruction_t inst;
  } ex_mem_t;

  typedef struct packed {
    logic [DataSize-1:0] pc_plus_4;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_read_data;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] read_data;
    logic [1:0] wr_reg_src;
    logic wr_reg_en;
  } mem_wb_t;

endpackage
