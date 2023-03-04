//
//! @file   control_unit.v
//! @brief  Implementação da unidade de controle de um processador RV64I
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-03
//

module control_unit
(
    // Common
    input clock,
    input reset,

    // Instruction Memory
    input [31:0] intruction,
    input instruction_mem_busy,
    output reg instruction_mem_enable,

    // Data Memory
    input data_mem_busy,
    output data_mem_enable,
    output reg [7:0] data_mem_byte_write_enable,

    // Vindo do Fluxo de Dados
    input zero,
    input negative,
    input carry_out,
    input overflow,

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
        desvio_condicional = 4'h7,
        jalr = 4'h8,
        load = 4'h9,
        store = 4'hA,
        halt = 4'hB;

    reg [3:0] estado_atual, proximo_estado;

    task zera_sinais;
        instruction_mem_enable <= 1'b0;
        data_mem_enable <= 1'b0;
        data_mem_byte_write_enable <= 8'b0;
        alua_src <= 1'b0;
        alub_src <= 1'b0;
        aluy_src <= 1'b0;
        alu_src <= 3'b000;
        carry_in <= 1'b0;
        arithmetic <= 1'b0;
        alupc_src <= 1'b0;
        pc_src <= 1'b0;
        pc_enable <= 1'b0;
        read_data_src <= 3'b000;
        write_register_src <= 2'b00;
        write_register_enable <= 1'b0;
    endtask

    // lógica da mudança de estados
    always @(posedge clock, reset) begin
        if(reset)
            zera_sinais;
            estado_atual <= fetch;
        else if(clock == 1'b1)
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
        data_mem_enable <= 1'b1;
        wait (data_mem_busy == 1'b1);
        wait (data_mem_busy == 1'b0);
        data_mem_byte_write_enable <= 8'b0;
        data_mem_enable <= 1'b0;
    endtask

    // decisores para desvios condicionais baseados nas flags da ULA
    wire beq = zero;
    wire bne = ~zero;
    wire blt = negative ^ overflow;
    wire bge = negative ~^ overflow;
    wire bltu = ~carry_out;
    wire bgeu = carry_out;

    // máquina de estados principal
    always @(posedge clock) begin

        zera_sinais;

        case(estado_atual)
            fetch:
                espera_instruction_mem;
                proximo_estado <= decode;

            decode:
                if(opcode[1:0] != 2'b11)
                    proximo_estado <= halt;
                else if(opcode[4]==1'b1)
                    if(opcode[5]==1'b1)
                        if(opcode[2]==1'b0)
                            proximo_estado <= registrador_registrador;
                        else if(opcode[3]==1'b0 && opcode[6]==1'b0)
                            proximo_estado <= lui;
                        else
                            proximo_estado <= halt;
                    else
                        if(opcode[2]==1'b0)
                            proximo_estado <= registrador_imediato;
                        else if(opcode[3]==1'b0 && opcode[6]==1'b0)
                            proximo_estado <= auipc;
                        else
                            proximo_estado <= halt;
                else
                    if(opcode[6]==1'b1)
                        if(opcode[3]==1'b1)
                            proximo_estado <= jal;
                        else if(opcode[2]==1'b0)
                            proximo_estado <= desvio_condicional;
                        else if(opcode[5]==1'b1)
                            proximo_estado <= jalr;
                        else
                            proximo_estado <= halt;
                    else
                        if(opcode[5]==1'b0)
                            proximo_estado <= load;
                        else if(opcode[2]==1'b0 && opcode[3]==1'b0)
                            proximo_estado <= store;
                        else
                            proximo_estado <= halt;

            registrador_registrador:
                alub_src <= 1'b1;
                aluy_src <= opcode[3];
                alu_src <= funct3;
                carry_in <= funct7;
                arithmetic <= funct7;
                pc_enable <= 1'b1;
                write_register_src <= 2'b1x;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            lui:
                aluy_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b1x;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            registrador_imediato:
                aluy_src <= opcode[3];
                alu_src <= funct3;
                arithmetic <= funct7;
                pc_enable <= 1'b1;
                write_register_src <= 2'b1x;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            auipc:
                alua_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b1x;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            jal:
                pc_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b01;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            branch_condicional:
                alub_src <= 1'b1;
                carry_in <= 1'b1;
                case(funct3)
                    000: pc_src <= beq;
                    001: pc_src <= bne;
                    100: pc_src <= blt;
                    101: pc_src <= bge;
                    110: pc_src <= bltu;
                    111: pc_src <= bgeu;
                endcase
                pc_enable <= 1'b1;

                proximo_estado <= fetch;

            jalr:
                alupc_src <= 1'b1;
                pc_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b01;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            load:
                read_data_src <= {~funct3[2], funct3{1:0]};
                espera_data_mem(data_mem_byte_write_enable);
                pc_enable <= 1'b1;
                write_register_src <= 2'b00;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;

            store:
                case(funct3[1:0])
                    00: data_mem_byte_write_enable <= 8'h01; // SB
                    01: data_mem_byte_write_enable <= 8'h03; // SH
                    10: data_mem_byte_write_enable <= 8'h0F; // SW
                    11: data_mem_byte_write_enable <= 8'hFF; // SD
                endcase;
                espera_data_mem(data_mem_byte_write_enable);
                pc_enable <= 1'b1;

                proximo_estado <= fetch;

            halt:
                proximo_estado <= halt;

            default:
                proximo_estado <= halt;
        endcase

    end

endmodule
