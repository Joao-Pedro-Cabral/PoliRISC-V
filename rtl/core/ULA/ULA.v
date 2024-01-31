//
//! @file   ULA.v
//! @brief  ULA RISC-V RV64I
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

`include "macros.vh"

module ULA (
    A,
    B,
    seletor,
    sub,
    arithmetic,
    Y,
    zero,
    negative,
    carry_out,
    overflow
);
  parameter integer N = 16;
  input wire [N-1:0] A;
  input wire [N-1:0] B;
  input wire [3:0] seletor;
  input wire sub;
  input wire arithmetic;  // 1: SRA, 0 : SRL
  output wire [N-1:0] Y;
  output wire zero;
  output wire negative;
  output wire carry_out;
  output wire overflow;

  // sinais para as 8 operações da ULA
  wire [N-1:0] add_sub;
  wire [N-1:0] sll;
  wire [N-1:0] slt;
  wire [N-1:0] sltu;
  wire [N-1:0] _xor;
  wire [N-1:0] sr;  // SRL ou SRA
  wire [N-1:0] _or;
  wire [N-1:0] _and;
  wire [N-1:0] _mul;
  wire [N-1:0] _mulh;
  wire [N-1:0] _mulhsu;
  wire [N-1:0] _mulhu;
  wire [N-1:0] _div;
  wire [N-1:0] _divu;
  wire [N-1:0] _rem;
  wire [N-1:0] _remu;

  // sinais intermediários das flags
  wire negative_;
  wire carry_out_;
  wire overflow_;


  wire sub_ = sub | (~seletor[2] & seletor[1]);

  // operações da ULA
  // operações aritméticas
  sklansky_adder #(
      .INPUT_SIZE(N)
  ) adder (
      .A(A),
      .B(B ^ {N{sub_}}),
      .c_in(sub_),
      .c_out(carry_out_),
      .S(add_sub)
  );
  left_barrel_shifter #(
      .XLEN(N)
  ) shifter_left (
      .in_data(A),
      .shamt(B[$clog2(N)-1:0]),
      .out_data(sll)
  );
  assign slt  = {{63{1'b0}}, negative_ ^ overflow_};
  assign sltu = {{63{1'b0}}, ~carry_out_};
  barrel_shifter_r #(
      .N($clog2(N))
  ) shifter_right (
      .A(A),
      .shamt(B[$clog2(N)-1:0]),
      .arithmetic(arithmetic),
      .Y(sr)
  );

  // operações lógicas
  assign _xor = A ^ B;
  assign _or  = A | B;
  assign _and = A & B;

  // multiplexador de saída da ULA
  gen_mux #(
      .size(N),
      .N(4)
  ) mux (
      .A({_mul, _and, _or, sr, _xor, sltu, slt, sll, add_sub}),
      .S(seletor),
      .Y(Y)
  );

  // flags da ULA
  assign negative_ = add_sub[N-1];
  assign overflow_ = (~(A[N-1] ^ B[N-1] ^ sub_)) & (A[N-1] ^ add_sub[N-1]);
  assign zero      = ~(|add_sub);
  assign negative  = negative_;
  assign carry_out = carry_out_;
  assign overflow  = overflow_;


endmodule
