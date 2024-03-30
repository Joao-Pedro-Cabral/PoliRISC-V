
module alu_tb ();
  import macros_pkg::*;
  import alu_pkg::*;

  localparam integer NumberOfTests = 100;

  // portas do DUT
  reg  [ 7:0] A;
  reg  [ 7:0] B;
  alu_op_t alu_op;
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
  wire        sub_ = (alu_op == 5'h02 || alu_op == 5'h03 || alu_op == 5'h10);
  wire [ 7:0] xorB;
  wire [15:0] mulh_ = $signed(A) * $signed(B);
  wire [15:0] mulhsu_ = $signed(A) * $unsigned(B);
  wire [15:0] mulhu_ = $unsigned(A) * $unsigned(B);
  wire arith_ = (alu_op == ShiftRightArithmetic);

  // gerando flags auxiliares
  assign xorB                  = B ^ '1;
  assign {carry_out_, add_sub} = (sub_ == 1) ? A + xorB + 8'h01 : A + B;
  assign zero_                 = ~(|add_sub);
  assign negative_             = add_sub[7];
  assign overflow_             = (~(A[7] ^ B[7] ^ sub_)) & (A[7] ^ add_sub[7]);

  // instanciando o DUT
  alu #(
      .N(8)
  ) DUT (
      .A(A),
      .B(B),
      .alu_op(alu_op),
      .Y(Y),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow)
  );

  task automatic display_fatal(input reg with_flags);
    begin
      if (with_flags) display_fatal_flags();
      $fatal(1, "Error: A = %b, B = %b, alu_op = %b, Y = %b", A, B, alu_op, Y);
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
    alu_op = Add;
    repeat (alu_op.num()) begin : alu_op_for
      repeat (NumberOfTests) begin : A_B_for
        A = $urandom;
        B = $urandom;
        #1;
        case (alu_op)
          // testa as flags
          Add, Sub:
          if((Y !== add_sub) || (zero !== zero_) || (negative !== negative_) ||
                        (carry_out !== carry_out_) || (overflow !== overflow_))
            display_fatal(1'b1);
          ShiftLeftLogic: if (Y !== (A << B[2:0])) display_fatal(1'b0);
          SetLessThan: if (Y !== ({7'b0, negative_ ^ overflow_})) display_fatal(1'b0);
          SetLessThanUnsigned: if (Y !== ({7'b0, ~carry_out_})) display_fatal(1'b0);
          Xor: if (Y !== (A ^ B)) display_fatal(1'b0);
          ShiftRightLogic, ShiftRightArithmetic:
          if ((Y !== A >> B[2:0] && (~arith_)) || (Y !== $signed($signed(A) >>> B[2:0]) && arith_))
            display_fatal(1'b0);
          Or: if (Y !== (A | B)) display_fatal(1'b0);
          And: if (Y !== (A & B)) display_fatal(1'b0);
          Mul: if (Y !== ($signed(A) * $signed(B))) display_fatal(1'b0);
          MulHigh: if (Y !== mulh_[15:8]) display_fatal(1'b0);
          MulHighSignedUnsigned: if (Y !== mulhsu_[15:8]) display_fatal(1'b0);
          MulHighUnsigned: if (Y !== mulhu_[15:8]) display_fatal(1'b0);
          Div: if (Y !== $signed($signed(A) / $signed(B))) display_fatal(1'b0);
          DivUnsigned: if (Y !== (A / B)) display_fatal(1'b0);
          Rem: if (Y !== $signed($signed(A) % $signed(B))) display_fatal(1'b0);
          RemUnsigned: if (Y !== ($unsigned(A) % $unsigned(B))) display_fatal(1'b0);
          default: $fatal(1, "Invalid alu_op: %b", alu_op);
        endcase
        #1;
      end
      alu_op = alu_op.next();
    end
    $display("EOT!");
  end

endmodule
