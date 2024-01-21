
`include "macros.vh"

module sklansky_adder_tb ();
  parameter integer N = 64;

  // Tamanho dos operandos
  parameter integer SEED = 1;  // Mude para uma sequência aleatória diferente

  reg [N-1:0] A, B;
  reg c_in;

  wire [N-1:0] S;
  wire c_out;

  integer i, errors, msb;

  reg xpectc_out;
  reg [N-1:0] xpectS;

  sklansky_adder #(
      .INPUT_SIZE(N)
  ) DUT (
      .A(A),
      .B(B),
      .c_in(c_in),
      .S(S),
      .c_out(c_out)
  );

  task automatic checkadd;
    begin
      xpectS = A + B + c_in;
      xpectc_out = ((A + B + c_in) >= {1'b1, {N{1'b0}}});
      if ((xpectc_out !== c_out) || (xpectS !== S)) begin
        errors = errors + 1;
        $display("ERRO: c_in, A, B = %1b,%8b,%8b, c_out, S = %1b,%8b, deveria ser %1b,%8b", c_in,
                 A, B, c_out, S, xpectc_out, xpectS);
      end
    end
  endtask

  initial begin
    errors = 0;
    A = $urandom(SEED);
    // Configurar padrão baseado no parâmetro semente
    for (i = 0; i < 10000; i = i + 1) begin
      B = ~A;
      c_in = 0;  // Aplica o teste, espera e checa
      #10;
      checkadd;

      c_in = 1;  // Checando ambos os valores de c_in
      #10;
      checkadd;

      msb = 31;
      A[31:0] = $urandom;  // Número aleatório

      while (msb < N - 1) begin
        A = A << 32;
        A[31:0] = $urandom;
        msb = msb + 32;
      end

      c_in = 0;
      #10;
      checkadd;  // checa de novo
      c_in = 1;
      #10;
      checkadd;  // para ambos os valores de c_in
    end
    $display("Errors: %0d", errors);
    $stop(1);
  end
endmodule
