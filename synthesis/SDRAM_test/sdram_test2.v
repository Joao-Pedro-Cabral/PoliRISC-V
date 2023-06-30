//
//! @file   sdram_test2.v
//! @brief  Teste de uma implementação de um controlador de SDRAM
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-06-27
//

module sdram_test2 (
    input reset,
    input clk,

    // sinais do DUT
    //  entradas do DUT
    output reg [25:0] addr,
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

  localparam reg [9:0] InitTest = 10'h000, Write0 = 10'h001,
  Read0 = 10'h002,
  WaitMem0 = 10'h003,
  Cmp0 = 10'h004,
  Fail0 = 10'h005,
  Success0 = 10'h006,
  Write1 = 10'h007,
  Read1 = 10'h008,
  WaitMem1 = 10'h009,
  Cmp1 = 10'h00A,
  Fail1 = 10'h00B,
  Success1 = 10'h00C,
  Write2 = 10'h00D,
  Read2 = 10'h00E,
  WaitMem2 = 10'h00F,
  Cmp2 = 10'h010,
  Fail2 = 10'h011,
  Success2 = 10'h012,
  Write3 = 10'h013,
  Write4 = 10'h014,
  Read3 = 10'h015,
  WaitMem3 = 10'h016,
  Cmp3 = 10'h017,
  Fail3 = 10'h018,
  Success3 = 10'h019,
  Read4 = 10'h01A,
  WaitMem4 = 10'h01B,
  Cmp4 = 10'h01C,
  Fail4 = 10'h01D,
  Success4 = 10'h01E,
  Write5 = 10'h01F,
  Write6 = 10'h020,
  Read5 = 10'h021,
  WaitMem5 = 10'h022,
  Cmp5 = 10'h023,
  Fail5 = 10'h024,
  Success5 = 10'h025,
  Read6 = 10'h026,
  WaitMem6 = 10'h027,
  Cmp6 = 10'h028,
  Fail6 = 10'h029,
  Success6 = 10'h02A,
  Read7 = 10'h02B,
  WaitMem7 = 10'h02C,
  Cmp7 = 10'h02D,
  Fail7 = 10'h02E,
  Success7 = 10'h02F;

  reg [9:0] state, next_state;

  task reset_signals;
    begin
      addr = 25'h000000;
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
        data = 32'h1;
        bwe  = 4'h1;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read0;
        else next_state = Write0;
      end

      Read0: begin
        bwe = 4'h1;
        req = 1'b1;
        if (ack) next_state = WaitMem0;
        else next_state = Read0;
      end

      WaitMem0: begin
        if (valid) next_state = Cmp0;
        else next_state = WaitMem0;
      end

      Cmp0: begin
        if (q[7:0] == 8'h01) next_state = Success0;
        else next_state = Fail0;
      end

      Success0: next_state = Write1;

      Fail0: next_state = Fail0;

      Write1: begin
        addr = 25'h000007;
        data = 32'hF0F0F0F0;
        bwe  = 4'h8;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read1;
        else next_state = Write1;
      end

      Read1: begin
        bwe = 4'h1;
        req = 1'b1;
        if (ack) next_state = WaitMem1;
        else next_state = Read1;
      end

      WaitMem1: begin
        if (valid) next_state = Cmp1;
        else next_state = WaitMem1;
      end

      Cmp1: begin
        if (q[7:0] == 8'h01) next_state = Success1;
        else next_state = Fail1;
      end

      Success1: next_state = Write2;

      Fail1: next_state = Fail1;

      Write2: begin
        addr = 25'h140BEEF;
        data = 32'hBEBACAFE;
        bwe  = 4'h3;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read2;
        else next_state = Write2;
      end

      Read2: begin
        addr = 25'h140BEEF;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem2;
        else next_state = Read2;
      end

      WaitMem2: begin
        if (valid) next_state = Cmp2;
        else next_state = WaitMem2;
      end

      Cmp2: begin
        if (q[31:16] != 16'hBEBA && q[15:0] == 16'hCAFE) next_state = Success2;
        else next_state = Fail2;
      end

      Success2: next_state = Write3;

      Fail2: next_state = Fail2;

      Write3: begin
        addr = 25'h40CAFE;
        data = 32'hFEEDBADE;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Write4;
        else next_state = Write3;
      end

      Write4: begin
        addr = 25'h40CAFE;
        data = 32'hFFFFBEEF;
        bwe  = 4'h3;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read3;
        else next_state = Write4;
      end

      Read3: begin
        addr = 25'h40CAFE;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem3;
        else next_state = Read3;
      end

      WaitMem3: begin
        if (valid) next_state = Cmp3;
        else next_state = WaitMem3;
      end

      Cmp3: begin
        if (q == 32'hFEEDBEEF) next_state = Success3;
        else next_state = Fail3;
      end

      Success3: next_state = Read4;

      Fail3: next_state = Fail3;

      Read4: begin
        addr = 25'h40CAF8;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem4;
        else next_state = Read4;
      end

      WaitMem4: begin
        if (valid) next_state = Cmp4;
        else next_state = WaitMem4;
      end

      Cmp4: begin
        if (q[15:0] != 32'hFEED) next_state = Success4;
        else next_state = Fail4;
      end

      Success4: next_state = Write5;

      Fail4: next_state = Fail4;

      Write5: begin
        addr = 25'h001005;
        data = 32'h01234567;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Write6;
        else next_state = Write5;
      end

      Write6: begin
        addr = 25'h001009;
        data = 32'h89ABCDEF;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read5;
        else next_state = Write6;
      end

      Read5: begin
        addr = 25'h001008;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem5;
        else next_state = Read5;
      end

      WaitMem5: begin
        if (valid) next_state = Cmp5;
        else next_state = WaitMem5;
      end

      Cmp5: begin
        if (q == 32'hABCDEF01) next_state = Success5;
        else next_state = Fail5;
      end

      Success5: next_state = Read6;

      Fail5: next_state = Fail5;

      Read6: begin
        addr = 25'h001007;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem6;
        else next_state = Read6;
      end

      WaitMem6: begin
        if (valid) next_state = Cmp6;
        else next_state = WaitMem6;
      end

      Cmp6: begin
        if (q == 32'hCDEF0123) next_state = Success6;
        else next_state = Fail6;
      end

      Success6: next_state = Read7;

      Fail6: next_state = Fail6;

      Read7: begin
        bwe = 4'h1;
        req = 1'b1;
        if (ack) next_state = WaitMem7;
        else next_state = Read7;
      end

      WaitMem7: begin
        if (valid) next_state = Cmp7;
        else next_state = WaitMem7;
      end

      Cmp7: begin
        if (q[7:0] == 8'h01) next_state = Success7;
        else next_state = Fail7;
      end

      Success7: next_state = Success7;

      Fail7: next_state = Fail7;

      default: next_state = InitTest;
    endcase
  end

  assign dbg_state = state;

endmodule
