//
//! @file   ULA_tb.v
//! @brief  Testbench ULA RISC-V RV64I
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

`include "macros.vh"

module ULA_tb ();

  // portas do DUT
  reg  [7:0] A;
  reg  [7:0] B;
  reg  [2:0] seletor;
  reg        sub;
  reg        arithmetic;
  wire [7:0] Y;
  wire       zero;
  wire       negative;
  wire       carry_out;
  wire       overflow;

  // auxiliares
  wire [7:0] A_         [7:0];
  wire [7:0] B_         [7:0];
  wire [7:0] add_sub;
  wire       zero_;
  wire       negative_;
  wire       carry_out_;
  wire       overflow_;
  wire       sub_;
  wire [7:0] xorB;

  // variáveis de iteração
  genvar j;
  integer i, k;

  // inicializando A_ e B_
  generate
    for (j = 0; j < 8; j = j + 1) begin : gen_intermediarios
      assign A_[j] = 40 * j;
      assign B_[j] = 33 * j + 100;
    end
  endgenerate

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
      .arithmetic(arithmetic),
      .Y(Y),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow)
  );

  // initial para testar o DUT
  initial begin : testbench
    #2;
    $display("SOT!");
    // itero para cada par da tripla (seletor, sub, arithmetic)
    for (i = 0; i < 32; i = i + 1) begin : seletor_for
      $display("Test: %d", i);
      sub   = i/8;  // sub   = 4º bit de i
      arithmetic = i/16; // arithmetic = 5º bit de i
      seletor    = i%8;  // seletor vai de 0 a 7
      for (k = 0; k < 8; k = k + 1) begin : A_B_for
        $display("Subtest: %d", k);
        A = A_[k];
        B = B_[k];
        #1;
        // case para cada uma das possibilidades de seletor
        case ((i % 8))
          1:
          if (Y !== (A << B[2:0]))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          2:
          if (Y !== ({7'b0, negative_ ^ overflow_}))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          3:
          if (Y !== ({7'b0, ~carry_out_}))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          4:
          if (Y !== (A ^ B))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          5:
          if (((Y !== A >> B[2:0]) && (~arithmetic)) || (($signed(
                  Y
              ) !== $signed(
                  A
              ) >>> B[2:0]) && arithmetic))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          6:
          if (Y !== (A | B))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          7:
          if (Y !== (A & B))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y
            );
          // testa as flags
          default:
          if((Y !== add_sub) || (zero !== zero_) || (negative !== negative_) ||
                        (carry_out !== carry_out_) || (overflow !== overflow_))
            $fatal(
                "Error: A[%d] = %b, B[%d] = %b, sub = %b, arithmetic = %b, seletor = %b, Y = %b" +
                "zero = %b, negative = %b, carry_out = %b, overflow = %b",
                k,
                A,
                k,
                B,
                sub,
                arithmetic,
                seletor,
                Y,
                zero,
                negative,
                carry_out,
                overflow
            );
        endcase
        #1;
      end
    end
    $display("EOT!");
  end

endmodule
