//
//! @file   ULA.v
//! @brief  ULA RISC-V RV64I
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-12
//

module ULA(A, B, seletor, carry_in, arithmetic, Y, zero, negative, carry_out, overflow);
    parameter N = 16;
    input  wire [N-1:0] A;
    input  wire [N-1:0] B;
    input  wire [2:0]   seletor;
    input  wire         carry_in;
    input  wire         arithmetic; // 1: SRA, 0 : SRL
    output wire [N-1:0] Y;
    output wire         zero;
    output wire         negative;
    output wire         carry_out;
    output wire         overflow;

    // sinais para as 8 operações da ULA
    wire [N-1:0] add_sub;
    wire [N-1:0] sll;
    wire [N-1:0] slt;
    wire [N-1:0] sltu;
    wire [N-1:0] xor_;
    wire [N-1:0] sr; // SRL ou SRA
    wire [N-1:0] or_;
    wire [N-1:0] and_;

    // sinais intermediários das flags
    wire negative_;
    wire carry_out_;
    wire overflow_;

    // operações da ULA
        // operações aritméticas
    sklansky_adder       #(.INPUT_SIZE(N)) adder (.A(A), .B(B ^ {N{carry_in}}), .c_in(carry_in), .c_out(carry_out_), .S(add_sub));
    //left_barrel_shifter  #(.XLEN(N))       shifter_left (.in_data(A), .shamt(B[$clog2(N) - 1:0]), .out_data(sll));
    assign sll     = A << (B[$clog2(N)-1:0]);
    assign slt     = negative_ ^ overflow_;
    assign sltu    = ~ carry_out_;
    barrel_shifter_r #(.N($clog2(N)))      shifter_right (.A(A), .shamt(B[$clog2(N) - 1:0]), .arithmetic(arithmetic), .Y(sr));

        // operações lógicas
    assign xor_ = A ^ B;
    assign or_  = A | B;
    assign and_ = A & B;

    // multiplexador de saída da ULA
    gen_mux #(.size(N), .N(3)) mux (.A({and_, or_, sr, xor_, sltu, slt, sll, add_sub}), .S(seletor), .Y(Y));

    // flags da ULA
    assign negative_  = add_sub[N-1];
    assign overflow_  = (~(A[N-1] ^ B[N-1])) & (A[N-1] ^ add_sub[N-1]);
    assign zero       = ~(|add_sub);
    assign negative   = negative_;
    assign carry_out  = carry_out_;
    assign overflow   = overflow_;


endmodule