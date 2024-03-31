module memory_unit #(
    parameter integer Width = 32
) (
    input logic clock,
    input logic reset,
    input logic rd_data_mem,
    input logic wr_data_mem,
    input logic inst_mem_ack,
    input logic [Width-1:0] inst_mem_rd_dat,
    input logic data_mem_ack,
    input logic [Width-1:0] data_mem_rd_dat,
    output logic inst_mem_en,
    output logic [Width-1:0] inst_mem_dat,
    output logic data_mem_en,
    output logic data_mem_we,
    output logic [Width-1:0] data_mem_dat,
    output logic busy
);
  import memory_unit_pkg::*;

  logic [Width-1:0] inst_mem_buf, data_mem_buf;
  logic inst_mem_bypass, data_mem_bypass;

  // Buffers
  always_ff @(posedge clock iff data_mem_ack or posedge reset) begin
    if (reset) data_mem_buf <= '0;
    else data_mem_buf <= data_mem_rd_dat;
  end

  always_ff @(posedge clock iff inst_mem_ack or posedge reset) begin
    if (reset) inst_mem_buf <= '0;
    else inst_mem_buf <= inst_mem_rd_dat;
  end

  // Data Output
  assign inst_mem_dat = inst_mem_bypass ? inst_mem_rd_dat : inst_mem_buf;
  assign data_mem_dat = data_mem_bypass ? data_mem_rd_dat : data_mem_buf;

  memory_unit_fsm_t present_state, next_state;

  always_ff @(posedge clock, posedge reset) begin : state_ff
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end : state_ff

  always_comb begin : memory_access_proc
    inst_mem_en = 1'b0;
    data_mem_en = 1'b0;
    data_mem_we = 1'b0;
    busy = 1'b0;
    inst_mem_bypass = 1'b0;
    data_mem_bypass = 1'b0;
    unique case (present_state)
      Idle: begin
        busy = 1'b1;
        inst_mem_en = 1'b1;
        data_mem_en = rd_data_mem | wr_data_mem;
        data_mem_we = wr_data_mem;
        if (!rd_data_mem && !wr_data_mem) next_state = WaitInstMem;
        else next_state = WaitAnyMem;
      end
      WaitAnyMem: begin
        busy = ~(inst_mem_ack & data_mem_ack);
        inst_mem_en = 1'b1;
        data_mem_en = 1'b1;
        data_mem_we = wr_data_mem;
        inst_mem_bypass = inst_mem_ack;
        data_mem_bypass = data_mem_ack;
        if (inst_mem_ack & data_mem_ack) next_state = Idle;
        else if (inst_mem_ack) next_state = WaitDataMem;
        else if (data_mem_ack) next_state = WaitInstMem;
        else next_state = WaitAnyMem;
      end
      WaitDataMem: begin
        busy = ~data_mem_ack;
        data_mem_en = 1'b1;
        data_mem_we = wr_data_mem;
        data_mem_bypass = data_mem_ack;
        if (data_mem_ack) begin
          next_state = Idle;
        end else next_state = WaitDataMem;
      end
      default: begin  // WaitInstMem
        busy = ~inst_mem_ack;
        inst_mem_en = 1'b1;
        inst_mem_bypass = inst_mem_ack;
        if (inst_mem_ack) begin
          next_state = Idle;
        end else next_state = WaitInstMem;
      end
    endcase
  end : memory_access_proc

endmodule
