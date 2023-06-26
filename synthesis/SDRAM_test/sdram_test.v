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

  /* // armazena saída da RAM */
  /* reg [31:0] q_reg; */
  /* always @(posedge clk) begin */
  /*   if (valid) q_reg <= q; */
  /* end */

  localparam reg [9:0] InitTest = 10'h000, Write0 = 10'h001,  // escreve 0 no endereço 0
  Read0 = 10'h002,  // lê do endereço 0
  WaitMem0 = 10'h003,  // espera leitura
  Cmp0 = 10'h004,  // compara dado lido com 0
  Fail0 = 10'h005,  // dado diferente de 0
  Success0 = 10'h006,  // dado igual a 0
  Write1 = 10'h007,  // escreve 0xF0F0F0F0 no endereço 0
  Read1 = 10'h008,  // lê do endereço 0
  WaitMem1 = 10'h009,  // espera leitura
  Cmp1 = 10'h00A,  // compara dado lido com 0xF0F0F0F0
  Fail1 = 10'h00B,  // dado diferente de 0xF0F0F0F0
  Success1 = 10'h00C,  // dado igual a 0xF0F0F0F0
  Write2 = 10'h00D,  // escreve 0xFEEDBEEF no endereço 0x40CAFE
  Read2 = 10'h00E,  // lê do endereço 0x40CAFE
  WaitMem2 = 10'h00F,  // espera leitura
  Cmp2 = 10'h010,  // compara dado lido com 0xFEEDBEEF
  Fail2 = 10'h011,  // dado diferente de 0xFEEDBEEF
  Success2 = 10'h012,  // dado igual a 0xFEEDBEEF
  Write3 = 10'h013,  // escreve 0xXXXXFFFF no endereço 0 (bwe = 0x3)
  Write4 = 10'h014,  // escreve 0xFFFFXXXX no endereço 2 (bwe = 0xC)
  Read3 = 10'h015,  // lê endereço 0
  WaitMem3 = 10'h016,  // espera leitura
  Cmp3 = 10'h017,  // compara dado lido com 0xZZZZFFFF
  Fail3 = 10'h018,  // dado diferente de 0xZZZZFFFF
  Success3 = 10'h019,  // dado igual a 0xZZZZFFFF
  Read4 = 10'h01A,  // lê endereço 2
  WaitMem4 = 10'h01B,  // espera memória
  Cmp4 = 10'h01C,  // compara dado lido com 0xFFFFZZZZ
  Fail4 = 10'h01D,  // dado lido é diferente de 0xFFFFZZZZ
  Success4 = 10'h01E,  // dado igual a 0xFFFFZZZZ
  Write5 = 10'h01F,  // escreve 0x01234567 no endereço 0x001000
  Write6 = 10'h020,  // escreve 0x89ABCDEF no endereço 0x001004
  Read5 = 10'h021,  // lê endereço 0x001000
  WaitMem5 = 10'h022,  // espera leitura
  Cmp5 = 10'h023,  // compara dado lido com 0x01234567
  Fail5 = 10'h024,  // dado diferente de 0x01234567
  Success5 = 10'h025,  // dado igual a 0x01234567
  Read6 = 10'h026,  // lê endereço 0x001004
  WaitMem6 = 10'h027,  // espera memória
  Cmp6 = 10'h028,  // compara dado lido com 0x89ABCDEF
  Fail6 = 10'h029,  // dado lido é diferente de 0x89ABCDEF
  Success6 = 10'h02A,  // dado igual a 0x89ABCDEF
  Read7 = 10'h02B,  // lê endereço 0x001001
  WaitMem7 = 10'h02C,  // espera memória
  Cmp7 = 10'h02D,  // compara dado lido com 0xEF012345
  Fail7 = 10'h02E,  // dado lido diferente de 0xEF012345
  Success7 = 10'h02F;  // dado igual a 0xEF012345

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

      Success1: next_state = Write2;

      Fail1: next_state = Fail1;

      Write2: begin
        addr = 25'h40CAFE;
        data = 32'hFEEDBEEF;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read2;
        else next_state = Write2;
      end

      Read2: begin
        addr = 25'h40CAFE;
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
        if (q == 32'hFEEDBEEF) next_state = Success2;
        else next_state = Fail2;
      end

      Success2: next_state = Write3;

      Fail2: next_state = Fail2;

      Write3: begin
        data = 32'hFFFFFFFF;
        bwe  = 4'h3;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Write4;
        else next_state = Write3;
      end

      Write4: begin
        addr = 25'h000004;
        data = 32'hFFFFFFFF;
        bwe  = 4'hC;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read3;
        else next_state = Write4;
      end

      Read3: begin
        bwe = 4'h3;
        req = 1'b1;
        if (ack) next_state = WaitMem3;
        else next_state = Read3;
      end

      WaitMem3: begin
        if (valid) next_state = Cmp3;
        else next_state = WaitMem3;
      end

      Cmp3: begin
        if (q[15:0] == 16'hFFFF) next_state = Success3;
        else next_state = Fail3;
      end

      Success3: next_state = Read4;

      Fail3: next_state = Fail3;

      Read4: begin
        addr = 25'h000004;
        bwe  = 4'hC;
        req  = 1'b1;
        if (ack) next_state = WaitMem4;
        else next_state = Read4;
      end

      WaitMem4: begin
        if (valid) next_state = Cmp4;
        else next_state = WaitMem4;
      end

      Cmp4: begin
        if (q[31:16] == 16'hFFFF) next_state = Success4;
        else next_state = Fail4;
      end

      Success4: next_state = Write5;

      Fail4: next_state = Fail4;

      Write5: begin
        addr = 25'h001000;
        data = 32'h01234567;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Write6;
        else next_state = Write5;
      end

      Write6: begin
        addr = 25'h001004;
        data = 32'h89ABCDEF;
        bwe  = 4'hF;
        we   = 1'b1;
        req  = 1'b1;
        if (ack) next_state = Read5;
        else next_state = Write6;
      end

      Read5: begin
        addr = 25'h001000;
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
        if (q == 32'h01234567) next_state = Success5;
        else next_state = Fail5;
      end

      Success5: next_state = Read6;

      Fail5: next_state = Fail5;

      Read6: begin
        addr = 25'h001004;
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
        if (q == 32'h89ABCDEF) next_state = Success6;
        else next_state = Fail6;
      end

      Success6: next_state = Read7;

      Fail6: next_state = Fail6;

      Read7: begin
        addr = 25'h001001;
        bwe  = 4'hF;
        req  = 1'b1;
        if (ack) next_state = WaitMem7;
        else next_state = Read7;
      end

      WaitMem7: begin
        if (valid) next_state = Cmp7;
        else next_state = WaitMem7;
      end

      Cmp7: begin
        if (q == 32'hEF012345) next_state = Success7;
        else next_state = Fail7;
      end

      Success7: next_state = Success7;

      Fail7: next_state = Fail7;

      default: next_state = InitTest;
    endcase
  end

  assign dbg_state = state;

endmodule
