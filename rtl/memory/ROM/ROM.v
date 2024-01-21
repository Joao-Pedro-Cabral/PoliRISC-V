//
//! @file   ROM.v
//! @brief  Memória ROM com 2**ADDR_SIZE palavras de tamanho WORD_SIZE, com OFFSET
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

`include "macros.vh"

module ROM (
    CLK_I,
    CYC_I,
    STB_I,
    ADR_I,
    DAT_O,
    ACK_O
);

  parameter ROM_INIT_FILE = "rom_init_file.mif";
  parameter integer WORD_SIZE = 8;
  parameter integer ADDR_SIZE = 8;
  parameter integer OFFSET = 2;
  parameter integer BUSY_CYCLES = 3;  // numero de ciclos que ACK_O está ativo
  input wire CLK_I;
  input wire CYC_I;
  input wire STB_I;
  input wire [ADDR_SIZE - 1:0] ADR_I;
  output wire [WORD_SIZE*(2**OFFSET) - 1 : 0] DAT_O;
  output reg ACK_O;

  reg busy_flag;
  reg [WORD_SIZE - 1:0] memory[2**ADDR_SIZE - 1:0];  // memória ROM
  wire [WORD_SIZE*(2**ADDR_SIZE)-1:0] linear_memory;  // linearização da memória

  // variáveis de iteração
  genvar i;
  integer j;

  // inicializando a memória
  initial begin
    $readmemb(ROM_INIT_FILE, memory);
    ACK_O = 1'b0;
    busy_flag = 1'b0;
  end

  // Particionando a memória de acordo com os offsets
  generate
    for (i = 0; i < 2 ** ADDR_SIZE; i = i + 1) begin : g_linear
      assign linear_memory[WORD_SIZE*(i+1)-1:WORD_SIZE*i] = memory[i];
    end
  endgenerate

  // Leitura da ROM
  gen_mux #(
      .size(WORD_SIZE * (2 ** OFFSET)),
      .N(ADDR_SIZE - OFFSET)
  ) addr_mux (
      .A(linear_memory),
      .S(ADR_I[ADDR_SIZE-1:OFFSET]),
      .Y(DAT_O)
  );

  always @* begin
    if (CYC_I && STB_I) busy_flag <= 1'b1;
  end

  always @(posedge CLK_I) begin : busy_enable
    ACK_O = 1'b0;
    if (busy_flag === 1'b1) begin
      for (j = 0; j < BUSY_CYCLES; j = j + 1) begin
        wait (CLK_I == 1'b0);
        wait (CLK_I == 1'b1);
      end
      ACK_O = 1'b1;
      busy_flag = 1'b0;
    end
  end


endmodule
