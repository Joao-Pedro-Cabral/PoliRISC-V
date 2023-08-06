//
//! @file   ROM.v
//! @brief  Memória ROM com 2**addr_size palavras de tamanho word_size, com offset
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

module ROM (
    clock,
    enable,
    addr,
    data,
    busy
);

  parameter rom_init_file = "rom_init_file.mif";
  parameter word_size = 8;
  parameter addr_size = 8;
  parameter offset = 2;
  parameter busy_cycles = 3;  // numero de ciclos que busy está ativo
  input wire clock;
  input wire enable;
  input wire [addr_size - 1:0] addr;
  output wire [word_size*(2**offset) - 1 : 0] data;
  output reg busy;

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
    busy = 1'b0;
  end

  // Particionando a memória de acordo com os offsets
  generate
    for (i = 0; i < 2 ** addr_size; i = i + 1) begin : linear
      assign linear_memory[word_size*(i+1)-1:word_size*i] = memory[i];
    end
  endgenerate

  always @(posedge clock) begin : leitura_sincrona
    if (busy === 1'b1) synch_addr <= addr;
  end

  // Leitura da ROM
  gen_mux #(
      .size(word_size * (2 ** offset)),
      .N(addr_size - offset)
  ) addr_mux (
      .A(linear_memory),
      .S(synch_addr[addr_size-1:offset]),
      .Y(data)
  );

  always @* begin
    if (enable === 1'b1) busy_flag <= 1'b1;
  end

  always @(posedge clock) begin : busy_enable
    if (busy_flag === 1'b1) begin
      busy = 1'b1;
      for (j = 0; j < busy_cycles; j = j + 1) begin
        wait (clock == 1'b0);
        wait (clock == 1'b1);
      end
      busy = 1'b0;
      busy_flag = 1'b0;
    end
  end


endmodule
