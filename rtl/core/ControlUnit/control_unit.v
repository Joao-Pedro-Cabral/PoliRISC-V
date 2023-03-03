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
    output wire alua_src,
    output wire alub_src,
    output wire aluy_src,
    output wire [2:0] alu_src,
    output wire carry_in,
    output wire arithmetic,
    output wire alupc_src,
    output wire pc_src,
    output wire pc_enable,
    output wire [2:0] read_data_src,
    output wire [1:0] write_register_src,
    output wire write_register_enable
);

    // sinais úteis
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire funct7 = instruction[30];

endmodule
