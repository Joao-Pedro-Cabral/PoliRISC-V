//
//! @file   ControlUnit.v
//! @brief  Implementação da unidade de controle de um processador RV64I
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-03
//

module ControlUnit
(
    // Common
    input wire clock,
    input wire reset,

    // Instruction Memory
    input  wire instruction_mem_busy,
    output reg  instruction_mem_enable,

    // Data Memory 
    input  wire data_mem_busy,
    output wire data_mem_enable,
    output wire [7:0] data_mem_byte_write_enable,

    // Vindo do Fluxo de Dados
    input wire opcode,
    input wire funct3,
    input wire funct7,
    input wire zero,
    input wire negative,
    input wire carry_out,
    input wire overflow,

    // Sinais de Controle do Fluxo de Dados
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
    task espera_instruction_mem;
        instruction_mem_enable <= 1'b1;
        wait (instruction_mem_busy == 1'b1);
        wait (instruction_mem_busy == 1'b0);
        instruction_mem_enable <= 1'b0;
    endtask

    task espera_data_mem(input [7:0] byte_write_enable);
        data_mem_byte_write_enable <= byte_write_enable;
        data_mem_chip_select <= 1'b1;
        wait (data_mem_busy == 1'b1);
        wait (data_mem_busy == 1'b0);
        data_mem_byte_write_enable <= 8'b0;
        data_mem_chip_select <= 1'b0;
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