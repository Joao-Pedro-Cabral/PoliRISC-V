//
//! @file   sdram_test.v
//! @brief  Teste de uma implementação de um controlador de SDRAM
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-06-20
//

module sdram_test (
    input reset,
    input clk,

    // sinais do DUT
    //  entradas do DUT
    output reg [23:0] addr,
    output reg [31:0] data,
    output reg [3:0] bwe,
    output reg we,
    output reg req,
    //  saídas do DUT
    input ack,
    input valid,
    input [31:0] q,
    ////

    // sinais de debug
    output [9:0] dbg_state
);

  /* // armazena saída da RAM */
  /* reg [31:0] q_reg; */
  /* always @(posedge clk) begin */
  /*   if (valid) q_reg <= q; */
  /* end */

  localparam reg [9:0]
    InitTest = 10'h000,
    Write0   = 10'h001,
    Read0    = 10'h002,
    WaitMem0 = 10'h003,
    Cmp0     = 10'h004,
    Fail0    = 10'h005,
    Success0 = 10'h006,
    Write1   = 10'h007,
    Read1    = 10'h008,
    WaitMem1 = 10'h009,
    Cmp1     = 10'h00A,
    Fail1    = 10'h00B,
    Success1 = 10'h00C;
  reg [9:0] state, next_state;

  task reset_signals;
    begin
      addr = 24'h000000;
      data = 32'h00000000;
      bwe  = 4'h0;
      we   = 1'b0;
      req  = 1'b0;
    end
  endtask

  // lógica da mudança de estados
  always @(posedge clk or posedge reset) begin
    if (reset) state <= InitTest;
    else state <= next_state;
  end

  always @(*) begin
    reset_signals;

    case (state)
      InitTest: next_state = Write0;

      Write0: begin
        bwe = 4'hF;
        we  = 1'b1;
        req = 1'b1;
        if (ack) next_state = Read0;
        else next_state = Write0;
      end

      Read0: begin
        bwe = 4'hF;
        req = 1'b1;
        if (ack) next_state = WaitMem0;
        else next_state = Read0;
      end

      WaitMem0: begin
        if (valid) next_state = Cmp0;
        else next_state = WaitMem0;
      end

      Cmp0: begin
        if (q == 32'h00000000) next_state = Success0;
        else next_state = Fail0;
      end

      Success0: next_state = Write1;

      Fail0: next_state = Fail0;

      Write1: begin
        data = 32'hF0F0F0F0;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read1;
        else next_state = Write1;
      end

      Read1: begin
        bwe = 4'hF;
        req = 1'b1;
        if (ack) next_state = WaitMem1;
        else next_state = Read1;
      end

      WaitMem1: begin
        if (valid) next_state = Cmp1;
        else next_state = WaitMem1;
      end

      Cmp1: begin
        if (q == 32'hF0F0F0F0) next_state = Success1;
        else next_state = Fail1;
      end

      Success1: next_state = Success1;

      Fail1: next_state = Fail1;

      default: next_state = Write0;
    endcase
  end

  assign dbg_state = state;

endmodule
