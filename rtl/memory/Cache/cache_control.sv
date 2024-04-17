
module cache_control #(
    parameter integer BYTE_NUM = 8
) (
    /* Sinais do sistema */
    input logic clock,
    input logic reset,
    /* //// */

    /* Interface com a memória de instruções */
    input  logic mem_ack,
    output logic mem_rd_en,
    output logic mem_wr_en,
    output logic [BYTE_NUM-1:0] mem_sel,
    /* //// */

    /* Interface com o controlador de memória */
    input  logic ctrl_rd_en,
    input  logic ctrl_wr_en,
    output logic ctrl_ack,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input  logic hit,
    input  logic dirty,
    input  logic ctrl_wr_en_d,
    output logic sample_ctrl_inputs,
    output logic set_valid,
    output logic set_tag,
    output logic set_data,
    output logic set_dirty
    /* //// */

);

  import cache_pkg::*;

  cache_state_t current_state, next_state;

  always_ff @(posedge clock, posedge reset) begin
    if (reset) current_state <= Idle;
    else current_state <= next_state;
  end

  always_comb begin
    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    ctrl_ack = 1'b0;
    sample_ctrl_inputs = 1'b0;
    set_valid = 1'b0;
    set_tag = 1'b0;
    set_data = 1'b0;
    set_dirty = 1'b0;
    next_state = Idle;
    unique case (current_state)
      CompareTag: begin
        if(hit) begin
          set_valid = 1'b1;
          set_tag = 1'b1;
          set_dirty = ctrl_wr_en_d;
          set_data = ctrl_wr_en_d;
          ctrl_ack = 1'b1;
        end else if(dirty) begin
          next_state = WriteBack;
        end else begin
          next_state = Allocate;
        end
      end
      Allocate: begin
        mem_rd_en = 1'b1;
        set_valid = mem_ack;
        set_tag = mem_ack;
        set_data = mem_ack;
        next_state = mem_ack ? CompareTag : Allocate;
      end
      WriteBack: begin
        mem_wr_en = 1'b1;
        next_state = mem_ack ? Allocate : WriteBack;
      end
      default: begin // Idle
        if(ctrl_rd_en || ctrl_wr_en) begin
          sample_ctrl_inputs = 1'b1;
          next_state = CompareTag;
        end
      end
    endcase
  end

  assign mem_sel = '1;

endmodule
