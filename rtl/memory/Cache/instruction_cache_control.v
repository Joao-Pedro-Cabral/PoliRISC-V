//
//! @file   instruction_cache_control.v
//! @brief  Implementação de um controlador de cache
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

`timescale 1 ns / 100 ps

module instruction_cache_control (
    /* Sinais do sistema */
    input clock,
    input reset,
    /* //// */

    /* Interface com a memória de instruções */
    input  inst_busy,
    output inst_enable,
    /* //// */

    /* Interface com o controlador de memória */
    input inst_cache_enable,
    output reg inst_cache_busy,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input hit,
    output reg cache_write_enable
    /* //// */

);

  localparam reg [1:0] HitState = 2'b00, MissState = 2'b01, DefaultState = 2'b11;

  reg [1:0] current_state, next_state;

  always @(posedge clock, posedge reset) begin
    if (reset) current_state <= DefaultState;
    else if (clock == 1'b1) current_state <= next_state;
  end

  assign inst_enable = hit ? 1'b0 : inst_cache_enable;

  always @(*) begin
    case (current_state)  // synthesis parallel_case
      default: begin
        inst_cache_busy = 1'b0;
        cache_write_enable = 1'b0;

        if (inst_cache_enable) begin
          if (hit) next_state = HitState;
          else next_state = MissState;
        end else next_state = DefaultState;
      end

      HitState: begin
        inst_cache_busy = 1'b1;
        cache_write_enable = 1'b0;
        next_state = DefaultState;
      end

      MissState: begin
        inst_cache_busy = 1'b1;
        cache_write_enable = ~inst_busy;
        next_state = inst_busy ? MissState : DefaultState;
      end
    endcase
  end

endmodule
