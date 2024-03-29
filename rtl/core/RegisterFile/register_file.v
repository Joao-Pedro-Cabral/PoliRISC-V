
module register_file (
    clock,
    reset,
    write_enable,
    read_address1,
    read_address2,
    write_address,
    write_data,
    read_data1,
    read_data2
);
  parameter integer size = 16;  // número de bits de 1 palavra
  parameter integer N = 4;  // número de bits de endereçamento
  // entradas e saídas
  input wire clock;
  input wire reset;
  input wire write_enable;
  input wire [N - 1:0] read_address1;
  input wire [N - 1:0] read_address2;
  input wire [N - 1:0] write_address;
  input wire [size - 1:0] write_data;
  output wire [size - 1:0] read_data1;
  output wire [size - 1:0] read_data2;
  // sinais e variáveis intermediários
  wire [2**N - 1:0] write_enable_reg;
  wire [size - 1:0] register_array[2**N - 2:0];
  wire [size*(2**N - 1) - 1:0] register_vector;  // linearização, pois array não pode ser entrada
  genvar i, j;

  // decodificador de endereço de escrita
  decoderN #(
      .N(N)
  ) write_reg_decoder (
      .A(write_address),
      .enable(write_enable),
      .Y(write_enable_reg)
  );

  // banco de registradores
  generate
    for (i = 1; i < 2 ** N; i = i + 1) begin : g_register_file
      register_d #(
          .N(size),
          .reset_value(0)
      ) register (
          .clock(clock),
          .reset(reset),
          .enable(write_enable_reg[i]),
          .D(write_data),
          .Q(register_array[i-1])
      );
    end
  endgenerate

  // linearização da saída do banco de registradores
  generate
    for (j = 0; j < 2 ** N - 1; j = j + 1) begin : g_vector_generate
      assign register_vector[size*(j+1)-1:j*size] = register_array[j];
    end
  endgenerate

  // muxes para selecionar a saída de dados -> veja que o x0 = 0 (não é um registrador, apenas fio terra)
  gen_mux #(
      .size(size),
      .N(N)
  ) read_reg_mux1 (
      .A({register_vector, {size{1'b0}}}),
      .S(read_address1),
      .Y(read_data1)
  );
  gen_mux #(
      .size(size),
      .N(N)
  ) read_reg_mux2 (
      .A({register_vector, {size{1'b0}}}),
      .S(read_address2),
      .Y(read_data2)
  );

endmodule
