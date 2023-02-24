//
//! @file   Dataflow_tb.v
//! @brief  Testbench do Dataflow
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-23
//

`timescale 1 ns / 100 ps

module Dataflow_tb();
    // sinais do DUT
        // Common
    wire clock;
    wire reset;
        // Instruction Memory
    wire [31:0] instruction;
    wire [63:0] instruction_address;
        // Data Memory
    wire [63:0] read_data;
    wire [63:0] write_data;
    wire [63:0] data_address;
        // From Control Unit
    wire alua_src;
    wire alub_src;
    wire aluy_src;
    wire [2:0] alu_src;
    wire carry_in;
    wire arithmetic;
    wire alupc_src;
    wire pc_src;
    wire pc_enable;
    wire [2:0] read_data_src;
    wire [1:0] write_register_src;
    wire write_register_enable;
        // To Control Unit
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;
    // Sinais da Memória de Instrução
    wire instruction_memory_enable;
    wire instruction_busy;
    // Sinais da Memória de Dados
    // Sinais intermediários de teste
    wire [26:0] LUT_uc [48:0]; // UC simulada com tabela : Consertar o tamanho
    wire [15:0] df_src;
    integer program_size = 50; // tamanho do programa que será executado
    integer i;

    // DUT
    Dataflow DUT (.clock(clock), .reset(reset), .instruction(instruction), .instruction_address(instruction_address), .read_data(read_data), .write_data(write_data),
     .data_address(data_address), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .carry_in(carry_in), .arithmetic(arithmetic), .alupc_src(alupc_src),
     .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src), .write_register_enable(write_register_enable), .opcode(opcode), 
     .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow));

    // Instruction Memory
    ROM #(.rom_init_file("rom_init_file.mif"), .word_size(8), .addr_size(8), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock), .enable(instruction_memory_enable), 
        .addr(instruction_address), .data(instruction), .busy(instruction_busy));

    // Data Memory
    

    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

    // função para determinar os seletores a partir do opcode, funct3 e funct7
    function [15:0] find_instruction;
        input wire [6:0] opcode;
        input wire [2:0] funct3;
        input wire funct7;
        input wire [26:0] LUT_uc [48:0];
        wire [15:0] source;
        integer i;
        // U,J : apenas opcode
        if(opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
            for(i = 0; i < 3; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0])
                    source = LUT_uc[i][26:11];
            end
        end
        // I, S, B: opcode e funct3
        else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 || 
           opcode === 7'b0010011 || opcode === 7'b0011011) begin
            for(i = 3; i < 34; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0] && funct3 === LUT_uc[i][9:7])
                    // SRLI e SRAI: funct7
                    if(funct3 === 3'b101)
                        if(funct7 === LUT_uc[i][10])
                            source = LUT_uc[i][26:11];
                    else
                        source = LUT_uc[i][26:11];
            end
        end
        // R: opcode, funct3 e funct7
        else if(opcode === 7'b0111011 || opcode === 7'b0110011 || opcode === 7'b1100111) begin
            for(i = 34; i < 49; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0] && funct3 === LUT_uc[i][9:7] && funct7 === LUT_uc[i][10])
                    source = LUT_uc[i][26:11];
            end
        end
        else
            $display("Function error: Opcode = %b", opcode);
        find_instruction = source;
    endfunction


    // testar o DUT
    // Adicionar lógica da Data Memory
    initial begin : Testbench
        $readmemb("dataflow_tb_bin.mif", LUT_uc);
        $display("SOT!");
        #2;
        reset = 1'b1;
        #6;
        reset = 1'b0;
        for(i = 0; i < program_size; i = i + 1) begin
            $display("Test: %d", i);
            // Fetch
            pc_enable = 1'b0;
            write_register_enable = 1'b0;
            instruction_memory_enable = 1'b1;
            #6;
            instruction_memory_enable = 1'b0;
            #12;
            // Decode
            df_src = find_instruction(opcode, funct3, funct7, LUT_uc);
            // Execute
            alua_src           = df_src[0];
            alub_src           = df_src[1];
            aluy_src           = df_src[2];
            alu_src            = df_src[5:3];
            carry_in           = df_src[6];
            arithmetic         = df_src[7];
            alupc_src          = df_src[8];
            read_data_src      = df_src[12:10];
            write_register_src = df_src[14:13];
                // Store(S*)
            if(opcode === 7'b0100011) begin
                pc_src = df_src[9];
                // interagir com a memória: realizar o teste
                pc_enable = 1'b1;
                #4;
            end
                // Load(L*)
            else if(opcode === 7'b0000011) begin
                pc_src = df_src[9];
                // interagir com a memória
                pc_enable = 1'b1;
                write_register_enable = 1'b1;
                #4;
            end
                // Branch(B*)
            else if(opcode === 7'b1100011) begin
                if(funct3[2:1] === 2'b00)
                    pc_src = ~(zero ^ funct3[0]);
                else if(funct3[2:1] === 2'b10)
                    pc_src = ~(negative ^ overflow ^ funct3[0]);
                else if(funct3[2:1] === 2'b11)
                    pc_src = carry_out ^ funct3[0];
                else
                    $display("Error: Invalid funct3! Funct3 : %b", funct3);
                pc_enable = 1'b1;
                #6;
            end
                // Others
            else if(opcode === 7'b1101111 || opcode === 7'b1100111 || opcode === 7'b0110111 || 
                    opcode === 7'b0010111 || opcode === 7'b0010011 || opcode === 7'b0110011 || 
                    opcode === 7'b0011011 || opcode === 7'b0111011) begin
                pc_src    = df_src[9];
                pc_enable = 1'b1;
                write_register_enable = df_src[15];
                #6;
            end
            else begin
                $display("Error: Invalid opcode! Opcode : %b", opcode);
                #6;
            end
        end
    end

endmodule