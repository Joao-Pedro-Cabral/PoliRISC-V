//
//! @file   instruction_cache_control.v
//! @brief  Implementação de um controlador de cache
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

module instruction_cache_control (
    /* Sinais do sistema */
    input CLK_I,
    input RST_I,
    /* //// */

    /* Interface com a memória de instruções */
    input  inst_ACK_I,
    output inst_CYC_O,
    /* //// */

    /* Interface com o controlador de memória */
    input inst_cache_CYC_I,
    output reg inst_cache_ACK_O,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input TGC_I,
    output reg cache_WE_O
    /* //// */

);

  localparam reg [1:0] HitState = 2'b00, MissState = 2'b01, DefaultState = 2'b11;

  reg [1:0] current_state, next_state;

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) current_state <= DefaultState;
    else if (CLK_I == 1'b1) current_state <= next_state;
  end

  assign inst_CYC_O = TGC_I ? 1'b0 : inst_cache_CYC_I;

  always @(*) begin
    case (current_state)  // synthesis parallel_case
      default: begin
        inst_cache_ACK_O = 1'b1;
        cache_WE_O = 1'b0;

        if (inst_cache_CYC_I) begin
          if (TGC_I) next_state = HitState;
          else next_state = MissState;
        end else next_state = DefaultState;
      end

      HitState: begin
        inst_cache_ACK_O = 1'b0;
        cache_WE_O = 1'b0;
        next_state = DefaultState;
      end

      MissState: begin
        inst_cache_ACK_O = 1'b0;
        cache_WE_O = inst_ACK_I;
        next_state = (~inst_ACK_I) ? MissState : DefaultState;
      end
    endcase
  end

endmodule
