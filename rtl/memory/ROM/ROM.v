//
//! @file   ROM.v
//! @brief  Memória ROM com 2**addr_size palavras de tamanho word_size, com offset
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

module ROM (
    CLK_I,
    CYC_I,
    ADR_I,
    DAT_O,
    ACK_O
);

  parameter rom_init_file = "rom_init_file.mif";
  parameter word_size = 8;
  parameter addr_size = 8;
  parameter offset = 2;
  parameter busy_cycles = 3;  // numero de ciclos que ACK_O está ativo
  input wire CLK_I;
  input wire CYC_I;
  input wire [addr_size - 1:0] ADR_I;
  output wire [word_size*(2**offset) - 1 : 0] DAT_O;
  output reg ACK_O;

  reg [addr_size - 1:0] synch_addr;
  reg busy_flag;
  reg [word_size - 1:0] memory[2**addr_size - 1:0];  // memória ROM
  wire [word_size*(2**addr_size)-1:0] linear_memory;  // linearização da memória

  // variáveis de iteração
  genvar i;
  integer j;

  // inicializando a memória
  initial begin
    $readmemb(rom_init_file, memory);
    ACK_O = 1'b1;
  end

  // Particionando a memória de acordo com os offsets
  generate
    for (i = 0; i < 2 ** addr_size; i = i + 1) begin : linear
      assign linear_memory[word_size*(i+1)-1:word_size*i] = memory[i];
    end
  endgenerate

  always @(posedge CLK_I) begin : leitura_sincrona
    if (ACK_O === 1'b0) synch_addr <= ADR_I;
  end

  // Leitura da ROM
  gen_mux #(
      .size(word_size * (2 ** offset)),
      .N(addr_size - offset)
  ) addr_mux (
      .A(linear_memory),
      .S(synch_addr[addr_size-1:offset]),
      .Y(DAT_O)
  );

  always @* begin
    if (CYC_I === 1'b1) busy_flag <= 1'b1;
  end

  always @(posedge CLK_I) begin : busy_enable
    if (busy_flag === 1'b1) begin
      ACK_O = 1'b0;
      for (j = 0; j < busy_cycles; j = j + 1) begin
        wait (CLK_I == 1'b0);
        wait (CLK_I == 1'b1);
      end
      ACK_O = 1'b1;
      busy_flag = 1'b0;
    end
  end


endmodule
