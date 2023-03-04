//
//! @file   control_unit.v
//! @brief  Implementação da unidade de controle de um processador RV64I
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-03
//

module control_unit
(
    input clock,
    input reset,

    // Vindo da Memória
    input [31:0] intruction,
    input rom_busy,
    input ram_busy,

    // Indo para a memória
    output rom_enable,
    output ram_output_enable,
    output ram_chip_select,
    input [7:0] ram_byte_write_enable,


    // Vindo do Fluxo de Dados
    input zero,
    input negative,
    input carry_out,

    // Sinais de Controle
    input overflow,
    output reg alua_src,
    output reg alub_src,
    output reg aluy_src,
    output reg [2:0] alu_src,
    output reg carry_in,
    output reg arithmetic,
    output reg alupc_src,
    output reg pc_src,
    output reg pc_enable,
    output reg [2:0] read_data_src,
    output reg [1:0] write_register_src,
    output reg write_register_enable
);

    // sinais úteis
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire funct7 = instruction[30];

    localparam [3:0]
        fetch = 4'h0,
        decode = 4'h1,
        registrador_registrador = 4'h2,
        lui = 4'h3,
        registrador_imediato = 4'h4,
        auipc = 4'h5,
        jal = 4'h6,
        branch_condicional = 4'h7,
        jalr = 4'h8,
        load = 4'h9,
        store = 4'hA,
        halt = 4'hB;

    reg [3:0] estado_atual, proximo_estado;

    // lógica da mudança de estados
    always @(posedge clock, posedge reset) begin
        if(reset)
            estado_atual <= fetch;
        else
            estado_atual <= proximo_estado;
    end

    // TODO: verificar se o uso de non-blocking statements causa problemas em simulação
    task espera_rom;
        rom_enable <= 1'b1;
        wait (rom_busy == 1'b1);
        wait (rom_busy == 1'b0);
        rom_enable <= 1'b0;
    endtask

    task espera_ram(input [7:0] byte_write_enable);
        ram_output_enable <= 1'b1;
        ram_byte_write_enable <= byte_write_enable;
        ram_chip_select <= 1'b1;
        wait (ram_busy == 1'b1);
        wait (ram_busy == 1'b0);
        ram_output_enable <= 1'b0;
        ram_byte_write_enable <= 8'b0;
        ram_chip_select <= 1'b0;
    endtask

    // máquina de estados principal
    always @(posedge clock) begin

        case(estado_atual)
            fetch:
            decode:
            registrador_registrador:
            lui:
            registrador_imediato:
            auipc:
            jal:
            branch_condicional:
            jalr:
            load:
            store:
            halt:
                proximo_estado <= halt;
            default:
                proximo_estado <= halt;
        endcase

    end

endmodule
