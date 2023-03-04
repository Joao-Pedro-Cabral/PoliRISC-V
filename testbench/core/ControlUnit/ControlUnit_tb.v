
//
//! @file   ControlUnit_tb.v
//! @brief  Testbench da ControlUnit
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-03
//

`timescale 1 ns / 100 ps

module ControlUnit_tb();
    // sinais do DUT
        // Common
    wire clock;
    wire reset;
        // Instruction Memory
    wire instruction_mem_enable;
    wire instruction_mem_busy;
        // Data Memory
    wire data_mem_enable;
    wire [7:0] data_mem_byte_write_enable;
    wire data_mem_busy;
        // From Dataflow
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;
        // To Dataflow
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
    // Sinais da Memória de instruções
    wire [31:0] instruction;
    // Sinais do PC
    wire [63:0] pc_in;
    wire [63:0] pc;
    // Sinais intermediários de teste
    wire [41:0] LUT_uc [48:0];    // UC simulada com tabela
    wire [24:0] df_src;           // Produzido pelo LUT
    wire [24:0] db_df_src;        // Produzido pela UC
    wire [63:0] immediate;        // imediato 
    // variáveis
    integer program_size = 50;    // tamanho do programa que será executado
    integer i;

    // DUT
    ControlUnit DUT (.clock(clock), .reset(reset), .instruction_mem_enable(instruction_mem_enable), .instruction_mem_busy(instruction_mem_busy), .data_mem_enable(data_mem_enable), 
    .data_mem_byte_write_enable(data_mem_byte_write_enable), .data_mem_busy(data_mem_busy), .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), 
    .negative(negative), .carry_out(carry_out), .overflow(overflow), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .carry_in(carry_in), 
    .arithmetic(arithmetic), .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src),
    .write_register_enable(write_register_enable));

    // Extensor de Imediato
    ImmediateExtender extensor_imediato (.immediate(immediate), .instruction(instruction));

   // Instruction Memory
    ROM #(.rom_init_file("./core/ControlUnit/uc_tb.mif"), .word_size(32), .addr_size(8), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock), 
                            .enable(instruction_mem_enable), .addr(instruction_address[7:0]), .data(instruction), .busy(instruction_mem_busy));
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // PC
    register_d #(.N(64), .reset_value(0)) PC_reg (.clock(clock), .reset(reset), .enable(pc_enable), .D(pc_in), .Q(pc));
    assign instruction_address = pc;


    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

    // função para determinar os seletores a partir do opcode, funct3 e funct7
    function [24:0] find_instruction;
        input wire [6:0] opcode;
        input wire [2:0] funct3;
        input wire [6:0] funct7;
        input wire [41:0] LUT_uc [48:0];
        wire [24:0] source;
        integer i;
        // U,J : apenas opcode
        if(opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
            for(i = 0; i < 3; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0])
                    source = LUT_uc[i][41:17];
            end
        end
        // I, S, B: opcode e funct3
        else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 || 
           opcode === 7'b0010011 || opcode === 7'b0011011) begin
            for(i = 3; i < 34; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0] && funct3 === LUT_uc[i][9:7])
                    // SRLI e SRAI: funct7
                    if(funct3 === 3'b101)
                        if(funct7 === LUT_uc[i][16:10])
                            source = LUT_uc[i][41:17];
                    else
                        source = LUT_uc[i][41:17];
            end
        end
        // R: opcode, funct3 e funct7
        else if(opcode === 7'b0111011 || opcode === 7'b0110011 || opcode === 7'b1100111) begin
            for(i = 34; i < 49; i = i + 1) begin
                if(opcode === LUT_uc[i][6:0] && funct3 === LUT_uc[i][9:7] && funct7 === LUT_uc[i][16:10])
                    source = LUT_uc[i][41:17];
            end
        end
        else
            $display("Function error: opcode = %b", opcode);
        find_instruction = source;
    endfunction

    assign db_df_src = {data_mem_byte_write_enable, data_mem_enable, write_register_enable, write_register_src, read_data_src, pc_src, alupc_src, arithmetic, carry_in, alu_src, aluy_src, alub_src, alua_src};

    // testar o DUT
    initial begin: Testbench
        $readmemb("./core/RV64I/RV64I.mif", LUT_uc);
        $display("SOT!");
        // Idle
        pc_in = 64'b0;
        #2;
        reset = 1'b1;
        #0.5
        if(db_df_src !== 18'b0)
            $display("Error Idle: db_df_src = %b", db_df_src);
        #5.5;
        reset = 1'b0;
        #0.5
        if(db_df_src !== 18'b0)
            $display("Error Idle: db_df_src = %b", db_df_src);
        #5.5;
        for(i = 0; i < program_size; i = i + 1) begin
            $display("Test: %d", i);
            carry_out = $random;
            negative  = $random;
            overflow  = $random;
            zero      = $random;
            // Fetch
            if(pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b1)
                $display("Error Fetch: pc_enable = %b, write_register_enable = %b, instruction_mem_enable = %b", pc_enable, write_register_enable, instruction_mem_enable);
            #17;
            // Decode
            df_src = find_instruction(opcode, funct3, funct7, LUT_uc);
            #1;
            if(pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b0)
                $display("Error End-Fetch: pc_enable = %b, write_register_enable = %b, instruction_mem_enable = %b", pc_enable, write_register_enable, instruction_mem_enable);
            // Execute -> Não testo pc_src para instruções do tipo B 
            if(df_src[17:10] !== db_df_src[17:10] || df_src[8:0] !== db_df_src[8:0] || (df_src[9] !== db_df_src[9] && opcode !== 7'b1100011))
                $display("Error Execute: df_src = %b, db_df_src = %b", df_src, db_df_src);
            // Testar pc_enable e incrementar pc
            case(opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011:
                    pc_in = pc + 4;
                    #14;
                    if(pc_enable !== 1'b1)
                        $display("PC enable error: pc_enable = %b, opcode = %b", pc_enable, opcode);
                    #4;
                // Branch(B*)
                7'b1100011:
                    // testo pc_src de acordo com as flags aleatórias
                    if(funct3[2:1] === 2'b00)
                        if(~(zero ^ funct3[0]) === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                        end
                        else begin
                            if(pc_src !== 1'b0)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                            pc = pc + 4;
                        end
                    else if(funct3[2:1] === 2'b10)
                        if(~(negative ^ overflow ^ funct3[0]) === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                        end
                        else begin
                            pc_in = pc + 4;
                            if(pc_src !== 1'b0)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                        end
                    else if(funct3[2:1] === 2'b11)
                        if(carry_out ^ funct3[0] === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                        end
                        else begin
                            pc_in = pc + 4;
                            if(pc_src !== 1'b0)
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                        end
                    else
                        $display("Error B-type: Invalid funct3! Funct3 : %b", funct3);
                    #6;
                // JAL e JALR
                7'b1101111, 7'b1100111:
                    if(pc_enable !== 1'b1)
                        $display("PC enable error: pc_enable = %b, opcode = %b", pc_enable, opcode);
                    pc_in = pc + immediate;
                    #6;
                // U/R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011, 7'b0110111, 7'b0010111:
                    if(pc_enable !== 1'b1)
                        $display("PC enable error: pc_enable = %b, opcode = %b", pc_enable, opcode);
                    pc_in = pc + 4
                    #6;
                default:
                    $display("Error opcode case: opcode = %b", opcode);
                    #6;
            endcase
        end

endmodule
