
import alu_pkg::*;

module alu #(
    parameter integer N = 16
) (
    input  logic [N-1:0] A,
    input  logic [N-1:0] B,
    input alu_op_t alu_op,
    output logic [N-1:0] Y,
    output logic zero,
    output logic negative,
    output logic carry_out,
    output logic overflow
);

  // sinais para as 8 operações da ALU
  wire [N-1:0] add_sub;
  wire [N-1:0] sll;
  wire [N-1:0] slt;
  wire [N-1:0] sltu;
  wire [N-1:0] _xor;
  wire [N-1:0] sr;  // SRL ou SRA
  wire [N-1:0] _or;
  wire [N-1:0] _and;
  wire [N-1:0] _mul;
  wire [N-1:0] _mulh, _mulh_aux;
  wire [N-1:0] _mulhsu, _mulhsu_aux;
  wire [N-1:0] _mulhu;
  wire [N-1:0] _div;
  wire [N-1:0] _divu;
  wire [N-1:0] _rem;
  wire [N-1:0] _remu;

  // sinais intermediários das flags
  wire negative_;
  wire carry_out_;
  wire overflow_;

  wire sub_ = alu_op inside {SetLessThan, SetLessThanUnsigned, Sub};
  wire arithmetic_ = alu_op === ShiftRightArithmetic;

  // operações da ALU
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
      .arithmetic(arithmetic_),
      .Y(sr)
  );

  // operações lógicas
  assign _xor = A ^ B;
  assign _or = A | B;
  assign _and = A & B;

  // operações da extensão M
  assign {_mulhu, _mul} = A * B;
  assign {_mulhsu, _mulhsu_aux} = $signed(A) * B;
  assign {_mulh, _mulh_aux} = $signed(A) * $signed(B);
  assign _div = $signed(A) / $signed(B);
  assign _divu = A / B;
  assign _rem = $signed(A) % $signed(B);
  assign _remu = A % B;

  // multiplexador de saída da ALU
  gen_mux #(
      .size(N),
      .N(4)
  ) mux (
      .A({
        _remu,
        _rem,
        _divu,
        _div,
        _mulhu,
        _mulhsu,
        _mulh,
        _mul,
        _and,
        _or,
        sr,
        _xor,
        sltu,
        slt,
        sll,
        add_sub
      }),
      .S(alu_op[3:0]),
      .Y(Y)
  );

  // flags da ALU
  assign negative_ = add_sub[N-1];
  assign overflow_ = (~(A[N-1] ^ B[N-1] ^ sub_)) & (A[N-1] ^ add_sub[N-1]);
  assign zero      = ~(|add_sub);
  assign negative  = negative_;
  assign carry_out = carry_out_;
  assign overflow  = overflow_;

endmodule
