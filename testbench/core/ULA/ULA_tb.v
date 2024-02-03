//
//! @file   ULA_tb.v
//! @brief  Testbench ULA RISC-V RV64I
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

`include "macros.vh"

module ULA_tb ();

  // portas do DUT
  reg  [ 7:0] A;
  reg  [ 7:0] B;
  reg  [ 3:0] seletor;
  reg         sub;
  reg         arith;
  wire [ 7:0] Y;
  wire        zero;
  wire        negative;
  wire        carry_out;
  wire        overflow;

  // auxiliares
  wire [ 7:0] add_sub;
  wire        zero_;
  wire        negative_;
  wire        carry_out_;
  wire        overflow_;
  wire        sub_;
  wire [ 7:0] xorB;
  wire [15:0] mulh_ = $signed(A) * $signed(B);
  wire [15:0] mulhsu_ = $signed(A) * $unsigned(B);
  wire [15:0] mulhu_ = $unsigned(A) * $unsigned(B);

  // variáveis de iteração
  genvar j;
  integer i, k;

  // gerando flags auxiliares
  assign xorB                  = B ^ 8'b11111111;
  assign {carry_out_, add_sub} = (sub_ == 1) ? A + xorB + 8'h01 : A + B;
  assign zero_                 = ~(|add_sub);
  assign sub_                  = sub | (~seletor[2] & seletor[1]);
  assign negative_             = add_sub[7];
  assign overflow_             = (~(A[7] ^ B[7] ^ sub_)) & (A[7] ^ add_sub[7]);

  // instanciando o DUT
  ULA #(
      .N(8)
  ) DUT (
      .A(A),
      .B(B),
      .seletor(seletor),
      .sub(sub),
      .arithmetic(arith),
      .Y(Y),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow)
  );

  task automatic display_fatal(input reg with_flags);
    begin
      if (with_flags) display_fatal_flags();
      $fatal(1, "Error: A = %b, B = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b", A, B,
             sub, arith, seletor, Y);
    end
  endtask

  task automatic display_fatal_flags();
    begin
      $display("Error: zero = %b, negative = %b, carry_out = %b, overflow = %b", zero, negative,
               carry_out, overflow);
    end
  endtask

  // initial para testar o DUT
  initial begin : testbench
    #2;
    $display("SOT!");
    // itero para cada par da tripla (seletor, sub, arithmetic)
    for (i = 0; i < 64; i = i + 1) begin : seletor_for
      $display("Test: %d", i);
      sub   = i/16;  // sub   = 4º bit de i
      arith = i/32; // arithmetic = 5º bit de i
      seletor    = i%16;  // seletor vai de 0 a 15
      for (k = 0; k < 100; k = k + 1) begin : A_B_for
        A = $urandom;
        B = $urandom;
        #1;
        // case para cada uma das possibilidades de seletor
        case ((i % 16))
          // testa as flags
          0:
          if((Y !== add_sub) || (zero !== zero_) || (negative !== negative_) ||
                        (carry_out !== carry_out_) || (overflow !== overflow_))
            display_fatal(1'b1);
          1: if (Y !== (A << B[2:0])) display_fatal(1'b0);
          2: if (Y !== ({7'b0, negative_ ^ overflow_})) display_fatal(1'b0);
          3: if (Y !== ({7'b0, ~carry_out_})) display_fatal(1'b0);
          4: if (Y !== (A ^ B)) display_fatal(1'b0);
          5:
          if ((Y !== A >> B[2:0] && (~arith)) || (Y !== $signed($signed(A) >>> B[2:0]) && arith))
            display_fatal(1'b0);
          6: if (Y !== (A | B)) display_fatal(1'b0);
          7: if (Y !== (A & B)) display_fatal(1'b0);
          8: if (Y !== ($signed(A) * $signed(B))) display_fatal(1'b0);
          9: if (Y !== mulh_[15:8]) display_fatal(1'b0);
          10: if (Y !== mulhsu_[15:8]) display_fatal(1'b0);
          11: if (Y !== mulhu_[15:8]) display_fatal(1'b0);
          12: if (Y !== $signed($signed(A) / $signed(B))) display_fatal(1'b0);
          13: if (Y !== (A / B)) display_fatal(1'b0);
          14: if (Y !== $signed($signed(A) % $signed(B))) display_fatal(1'b0);
          default: if (Y !== ($unsigned(A) % $unsigned(B))) display_fatal(1'b0);
        endcase
        #1;
      end
    end
    $display("EOT!");
  end

endmodule
