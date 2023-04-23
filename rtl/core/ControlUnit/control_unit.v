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
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input instruction_mem_busy,
    output reg instruction_mem_enable,

    // Data Memory
    input data_mem_busy,
    output reg data_mem_read_enable,
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
    output reg sub,
    output reg arithmetic,
    output reg alupc_src,
    output reg pc_src,
    output reg pc_enable,
    output reg [2:0] read_data_src,
    output reg [1:0] write_register_src,
    output reg write_register_enable,
    output reg ir_enable
);

    // sinais úteis

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
        halt = 4'hB,
        idle = 4'hC;

    reg [3:0] estado_atual, proximo_estado;

    task zera_sinais;
    begin
        instruction_mem_enable <= 1'b0;
        data_mem_read_enable <= 1'b0;
        data_mem_byte_write_enable <= 8'b0;
        alua_src <= 1'b0;
        alub_src <= 1'b0;
        aluy_src <= 1'b0;
        alu_src <= 3'b000;
        sub <= 1'b0;
        arithmetic <= 1'b0;
        alupc_src <= 1'b0;
        pc_src <= 1'b0;
        pc_enable <= 1'b0;
        read_data_src <= 3'b000;
        write_register_src <= 2'b00;
        write_register_enable <= 1'b0;
        ir_enable <= 1'b0;
    end
    endtask

    // lógica da mudança de estados
    always @(posedge clock, posedge reset) begin
        if(reset)
            estado_atual <= idle;
        else if(clock == 1'b1)
            estado_atual <= proximo_estado;
    end
    
    // decisores para desvios condicionais baseados nas flags da ULA
    wire beq_bne = zero ^ funct3[0];
    wire blt_bge = (negative ^ overflow) ^ funct3[0];
    wire bltu_bgeu = carry_out ~^ funct3[0];
    wire cond = funct3[1]==0 ? funct3[2]==0 ? beq_bne : blt_bge : bltu_bgeu;
    wire [7:0] byte_enable = funct3[1]==0 ? (funct3[0]==0 ? 8'h01 : 8'h03) : (funct3[0]==0 ? 8'h0F : 8'hFF);

    // TODO: verificar se o uso de non-blocking statements causa problemas em simulação
    task espera_instruction_mem;
    begin
        instruction_mem_enable <= 1'b1;
        @ (posedge instruction_mem_busy);
        @ (negedge instruction_mem_busy);
        instruction_mem_enable <= 1'b0;
    end
    endtask

    task data_mem_read;
    begin
        data_mem_read_enable <= 1'b1;
        @ (posedge data_mem_busy);
        @ (negedge data_mem_busy);
        data_mem_read_enable <= 1'b0;
    end
    endtask

    task data_mem_write;
    begin
        data_mem_byte_write_enable <= byte_enable;
        @ (posedge data_mem_busy);
        @ (negedge data_mem_busy);
        data_mem_byte_write_enable <= 8'b0;
    end
    endtask

    // máquina de estados principal
    always @(estado_atual, reset, cond, byte_enable) begin

        zera_sinais;

        case(estado_atual) // synthesis parallel_case
            idle:
            begin
                if(reset == 1'b1)
                    proximo_estado <= idle;
                else
                    proximo_estado <= fetch;
            end

            fetch:
            begin
                espera_instruction_mem;
                ir_enable <= 1'b1;
                proximo_estado <= decode;
            end

            decode:
            begin
                if(opcode[1:0] != 2'b11)
                    proximo_estado <= halt;
                else if(opcode[4]==1'b1) begin
                    if(opcode[5]==1'b1) begin
                        if(opcode[2]==1'b0)
                            proximo_estado <= registrador_registrador;
                        else if(opcode[3]==1'b0 && opcode[6]==1'b0)
                            proximo_estado <= lui;
                        else
                            proximo_estado <= halt;
                    end
                    else begin
                        if(opcode[2]==1'b0)
                            proximo_estado <= registrador_imediato;
                        else if(opcode[3]==1'b0 && opcode[6]==1'b0)
                            proximo_estado <= auipc;
                        else
                            proximo_estado <= halt;
                    end
                end
                else begin
                    if(opcode[6]==1'b1) begin
                        if(opcode[3]==1'b1)
                            proximo_estado <= jal;
                        else if(opcode[2]==1'b0)
                            proximo_estado <= desvio_condicional;
                        else if(opcode[5]==1'b1)
                            proximo_estado <= jalr;
                        else
                            proximo_estado <= halt;
                    end
                    else begin
                        if(opcode[5]==1'b0)
                            proximo_estado <= load;
                        else if(opcode[2]==1'b0 && opcode[3]==1'b0)
                            proximo_estado <= store;
                        else
                            proximo_estado <= halt;
                    end
                end
            end

            registrador_registrador:
            begin
                aluy_src <= opcode[3];
                alu_src <= funct3;
                sub <= funct7[5];
                arithmetic <= funct7[5];
                pc_enable <= 1'b1;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            lui:
            begin
                alub_src <= 1'b1;
                aluy_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            registrador_imediato:
            begin
                alub_src <= 1'b1;
                aluy_src <= opcode[3];
                alu_src <= funct3;
                arithmetic <= funct7[5] & funct3[2] & (~funct3[1]) & funct3[0];
                pc_enable <= 1'b1;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            auipc:
            begin
                alua_src <= 1'b1;
                alub_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            jal:
            begin
                pc_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b11;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            desvio_condicional:
            begin
                sub <= 1'b1;
                pc_src <= cond;
                pc_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            jalr:
            begin
                alupc_src <= 1'b1;
                pc_src <= 1'b1;
                pc_enable <= 1'b1;
                write_register_src <= 2'b11;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            load:
            begin
                alub_src <= 1'b1;
                read_data_src <= funct3 ^ 3'b100;
                write_register_src <= 2'b10;
                data_mem_read;
                pc_enable <= 1'b1;
                write_register_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            store:
            begin
                alub_src <= 1'b1;
                data_mem_write;
                pc_enable <= 1'b1;

                proximo_estado <= fetch;
            end

            halt:
                proximo_estado <= halt;

            default:
                proximo_estado <= halt;
        endcase

    end

endmodule
