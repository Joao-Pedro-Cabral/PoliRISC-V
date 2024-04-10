
module cache_control (
    /* Sinais do sistema */
    input logic clock,
    input logic reset,
    /* //// */

    /* Interface com a memória de instruções */
    input  logic mem_ack,
    output logic mem_rd_en,
    output logic mem_wr_en,
    /* //// */

    /* Interface com o controlador de memória */
    input  logic crtl_rd_en,
    input  logic crtl_wr_en,
    output logic crtl_ack,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input  logic hit,
    input  logic dirty,
    output logic sample_crtl_inputs,
    output logic set_valid_tag,
    output logic set_dirty
    /* //// */

);

  import csr_pkg::*;

  cache_state_t current_state, next_state;

  always_ff @(posedge clock, posedge reset) begin
    if (reset) current_state <= DefaultState;
    else current_state <= next_state;
  end

  always_comb begin
    crtl_ack = 1'b0;
    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    set_valid_tag = 1'b0;
    set_dirty = 1'b0;
    next_state = Idle;
    unique case (current_state)
      CompareTag: begin
        if(hit) begin
          set_valid_tag = 1'b1;
          set_dirty = wr_en;
          crtl_ack = 1'b1;
          next_state = Idle;
        end else if(dirty) begin
          next_state = WriteBack;
        end else begin
          next_state = Allocate;
        end
      end
      Allocate: begin
        mem_rd_en = 1'b1;
        next_state = mem_ack ? Allocate : CompareTag;
      end
      WriteBack: begin
        mem_wr_en = 1'b1;
        next_state = mem_ack ? WriteBack : Allocate;
      end
      default: begin // Idle
        if(mem_rd_en || mem_wr_en) begin
          sample_crtl_inputs = 1'b1;
          next_state = CompareTag;
        end
      end
    endcase
  end

endmodule
