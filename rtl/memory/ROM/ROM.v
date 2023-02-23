//
//! @file   ROM.v
//! @brief  Memória ROM com 2**addr_size palavras de tamanho word_size, com offset
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-22
//

`timescale 1 ns / 100 ps

module ROM(clock, enable, addr, data, busy);

    parameter rom_init_file = "rom_init_file.mif";
    parameter word_size = 8;
    parameter addr_size = 8;
    parameter offset = 2;
    parameter busy_time = 3; // tempo em que busy = 1
    input  wire clock;
    input  wire enable;
    input  wire [addr_size - 1:0] addr;
    output wire [word_size*(2**offset) - 1 : 0] data;
    output reg  busy;
    
    reg [word_size - 1:0] memory [2**addr_size - 1:0]; // memória ROM
    wire [word_size*(2**addr_size)-1:0] linear_memory; // linearização da memória 

    // variáveis de iteração
    genvar i;

    // inicializando a memória
    initial begin
        $readmemb(rom_init_file, memory);
    end

    // Particionando a memória de acordo com os offsets
    generate
        for(i = 0; i < 2**addr_size; i = i + 1) begin: linear
            assign linear_memory[word_size*(i + 1) - 1: word_size*i] = memory[i];
        end
    endgenerate

    // Leitura da ROM
    gen_mux #(.size(word_size*(2**offset)), .N(addr_size - offset)) addr_mux (.A(linear_memory), .S(addr[addr_size-1:offset]), .Y(data));

    always @ (posedge clock) begin: busy_enable
        if(enable == 1) begin
            busy = 1'b1;
            #(busy_time);
            busy = 1'b0;
        end
        else
            busy = 1'b0;
    end


endmodule