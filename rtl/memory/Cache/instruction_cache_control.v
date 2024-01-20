//
//! @file   instruction_cache_control.v
//! @brief  Implementação de um controlador de cache
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-16
//

module instruction_cache_control (
    /* Sinais do sistema */
    input wire CLK_I,
    input wire RST_I,
    /* //// */

    /* Interface com a memória de instruções */
    input  wire inst_ACK_I,
    output reg inst_CYC_O,
    output wire inst_STB_O,
    /* //// */

    /* Interface com o controlador de memória */
    input wire inst_cache_CYC_I,
    input wire inst_cache_STB_I,
    output reg inst_cache_ACK_O,
    /* //// */

    /* Interface com o Fluxo de Dados */
    input wire TGC_I,
    output reg cache_WE_O
    /* //// */

);

  localparam reg [1:0] HitState = 2'b00, MissState = 2'b01, DefaultState = 2'b11;

  reg [1:0] current_state, next_state;

  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) current_state <= DefaultState;
    else if (CLK_I == 1'b1) current_state <= next_state;
  end

  assign inst_STB_O = inst_CYC_O;

  always @(*) begin
    inst_cache_ACK_O = 1'b0;
    inst_CYC_O = 1'b0;
    cache_WE_O = 1'b0;
    case (current_state)  // synthesis parallel_case
      default: begin

        if (inst_cache_CYC_I && inst_cache_STB_I) begin // read-only
          if (TGC_I) next_state = HitState;
          else begin
            inst_CYC_O = 1'b1;
            next_state = MissState;
          end
        end else next_state = DefaultState;
      end

      HitState: begin
        inst_cache_ACK_O = 1'b1;
        next_state = DefaultState;
      end

      MissState: begin
        inst_CYC_O = ~inst_ACK_I;
        cache_WE_O = inst_ACK_I;
        next_state = inst_ACK_I ? HitState : MissState;
      end
    endcase
  end

endmodule
