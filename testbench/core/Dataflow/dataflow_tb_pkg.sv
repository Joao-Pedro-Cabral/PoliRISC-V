
package dataflow_tb_pkg;

  import instruction_pkg::*;
  import extensions_pkg::*;

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
    logic [DataSize-1:0] csr_rd_data;
    instruction_t inst;
  } id_ex_tb_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_rd_data;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] write_data;
    logic [DataSize-1:0] csr_wr_data;
    instruction_t inst;
  } ex_mem_tb_t;

  typedef struct packed {
    logic [DataSize-1:0] pc;
    logic [4:0] rd;
    logic [DataSize-1:0] csr_rd_data;
    logic [DataSize-1:0] alu_y;
    logic [DataSize-1:0] read_data;
    logic [DataSize-1:0] csr_wr_data;
    instruction_t inst;
  } mem_wb_tb_t;

endpackage