
//
//! @file   control_unit_tb.v
//! @brief  Testbench da control_unit
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-03
//

`timescale 1 ns / 100 ps

module control_unit_tb();
    // sinais do DUT
        // Common
    reg  clock;
    reg  reset;
        // Instruction Memory
    wire instruction_mem_enable;
    wire instruction_mem_busy;
        // Data Memory
    wire data_mem_enable;
    wire [7:0] data_mem_byte_write_enable;
    reg  data_mem_busy;
        // From Dataflow
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    reg  zero;
    reg  negative;
    reg  carry_out;
    reg  overflow;
        // To Dataflow
    wire alua_src;
    wire alub_src;
    wire aluy_src;
    wire [2:0] alu_src;
    wire sub;
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
    reg  [63:0] pc_in;
    wire [63:0] pc;
    // Sinais intermediários de teste
    reg  [41:0]   LUT_uc [48:0];    // UC simulada com tabela
    wire [2057:0] LUT_linear;       // Tabela acima linearizada
    reg  [24:0]   df_src;           // Produzido pelo LUT
    wire [24:0]   db_df_src;        // Produzido pela UC
    wire [63:0]   immediate;        // imediato
    // variáveis
    integer program_size = 1000;  // tamanho do programa que será executado
    integer i;
    genvar j;

    // DUT
    control_unit DUT (.clock(clock), .reset(reset), .instruction_mem_enable(instruction_mem_enable), .instruction_mem_busy(instruction_mem_busy), .data_mem_enable(data_mem_enable),
    .data_mem_byte_write_enable(data_mem_byte_write_enable), .data_mem_busy(data_mem_busy), .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero),
    .negative(negative), .carry_out(carry_out), .overflow(overflow), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub),
    .arithmetic(arithmetic), .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src),
    .write_register_enable(write_register_enable));

    // Extensor de Imediato
    ImmediateExtender extensor_imediato (.immediate(immediate), .instruction(instruction));

   // Instruction Memory
    ROM #(.rom_init_file("./control_unit.mif"), .word_size(8), .addr_size(10), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock),
                            .enable(instruction_mem_enable), .addr(pc[9:0]), .data(instruction), .busy(instruction_mem_busy));
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // PC
    register_d #(.N(64), .reset_value(0)) PC_reg (.clock(clock), .reset(reset), .enable(pc_enable), .D(pc_in), .Q(pc));


    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

    // geração do LUT linear
    generate
        for(j = 0; j < 49; j = j + 1)
            assign LUT_linear[42*(j+1)-1:42*j] = LUT_uc[j];
    endgenerate

    // função para determinar os seletores a partir do opcode, funct3 e funct7
    function [24:0] find_instruction(input [6:0] opcode, input [2:0] funct3, input [6:0] funct7, input [2057:0] LUT_linear);
            integer i;
            reg [24:0] temp;
        begin
            // U,J : apenas opcode
            if(opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
                for(i = 0; i < 3; i = i + 1)
                    if(opcode == LUT_linear[35+42*i+:7])
                        temp = LUT_linear[42*i+:25];
            end
            // I, S, B: opcode e funct3
            else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 ||
                opcode === 7'b0010011 || opcode === 7'b0011011 || opcode === 7'b1100111) begin
                for(i = 3; i < 34; i = i + 1) begin
                    if(opcode === LUT_linear[35+42*i+:7] && funct3 === LUT_linear[32+42*i+:3]) begin
                        // SRLI e SRAI: funct7
                        if(funct3 === 3'b101 && opcode[4] == 1'b1) begin
                            if(funct7[6:1] === LUT_linear[26+42*i+:6])
                                temp = LUT_linear[42*i+:25];
                        end
                        else
                            temp = LUT_linear[42*i+:25];
                    end
                end
            end
            // R: opcode, funct3 e funct7
            else if(opcode === 7'b0111011 || opcode === 7'b0110011) begin
               for(i = 34; i < 49; i = i + 1)
                    if(opcode === LUT_linear[35+42*i+:7] && funct3 === LUT_linear[32+42*i+:3] && funct7 === LUT_linear[25+42*i+:7])
                        temp = LUT_linear[42*i+:25];
            end
            else begin
                $display("Function error: opcode = %b", opcode);
                $stop;
            end
            //$display("temp: %b", temp);
            find_instruction = temp;
        end
    endfunction

    assign db_df_src = {alua_src, alub_src, aluy_src, alu_src, sub, arithmetic, alupc_src, pc_src, read_data_src, write_register_src, write_register_enable, data_mem_enable, data_mem_byte_write_enable};

    // testar o DUT
    initial begin: Testbench
        $readmemb("./MIFs/core/RV64I/RV64I.mif", LUT_uc);
        $display("SOT!");
        // Idle
        pc_in = 64'b0;
        #2;
        reset = 1'b1;
        #0.5;
        if(db_df_src !== 18'b0) begin
            $display("Error Idle: db_df_src = %b", db_df_src);
            $stop;
        end
        #5.5;
        reset = 1'b0;
        #0.5;
        if(db_df_src !== 18'b0) begin
            $display("Error Idle: db_df_src = %b", db_df_src);
            $stop;
        end
        #5.5;
        for(i = 0; i < program_size; i = i + 1) begin
            $display("Test: %d", i);
            carry_out = $random;
            negative  = $random;
            overflow  = $random;
            zero      = $random;
            // Fetch
            if(pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b1) begin
                $display("Error Fetch: pc_enable = %b, write_register_enable = %b, instruction_mem_enable = %b", pc_enable, write_register_enable, instruction_mem_enable);
                $stop;
            end
            wait (instruction_mem_busy == 1'b1);
            wait (instruction_mem_busy == 1'b0);
            #9;
            // Decode
            df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
            #1;
            if(pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b0) begin
                $display("Error Decode: pc_enable = %b, write_register_enable = %b, instruction_mem_enable = %b", pc_enable, write_register_enable, instruction_mem_enable);
                $stop;
            end
            #6;
            // Execute -> Não testo pc_src para instruções do tipo B e write_register_enable para Load
            if({df_src[24:16], df_src[14:10], df_src[8:0]} !== {db_df_src[24:16], db_df_src[14:10], db_df_src[8:0]} || (df_src[15] !== db_df_src[15] && opcode !== 7'b1100011)
                    || (df_src[9] !== db_df_src[9] && opcode !== 7'b0000011)) begin
                $display("Error Execute: df_src = %b, db_df_src = %b", df_src, db_df_src);
                $stop;
            end
            // Testar pc_enable e incrementar pc
            case(opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011: begin
                    pc_in = pc + 4;
                    #2;
                    data_mem_busy = 1'b1;
                    #12;
                    data_mem_busy = 1'b0;
                    #4;
                    if(pc_enable !== 1'b1 || write_register_enable !== df_src[9] || data_mem_enable !== 1'b0 || data_mem_byte_write_enable !== 0) begin
                        $display("Store/Load Error: pc_enable = %b, write_register_enable = %b, data_mem_enable = %b, data_mem_byte_write_enable = %b, opcode = %b, funct3 = %b", pc_enable, write_register_enable, data_mem_enable, data_mem_byte_write_enable, opcode, funct3);
                        $stop;
                    end
                    #6;
                end
                // Branch(B*)
                7'b1100011: begin
                    // testo pc_src de acordo com as flags aleatórias
                    if(funct3[2:1] === 2'b00) begin
                        if(zero ^ funct3[0] === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                            pc_in = pc + 4;
                        end
                    end
                    else if(funct3[2:1] === 2'b10) begin
                        if(negative ^ overflow ^ funct3[0] === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            pc_in = pc + 4;
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                        end
                    end
                    else if(funct3[2:1] === 2'b11) begin
                        if(carry_out ~^ funct3[0] === 1'b1) begin
                            pc_in = pc + immediate;
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            pc_in = pc + 4;
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %b, funct3 = %b", pc_src, funct3);
                                $stop;
                            end
                        end
                    end
                    else
                        $display("Error B-type: Invalid funct3! Funct3 : %b", funct3);
                    #6;
                end
                // JAL e JALR
                7'b1101111, 7'b1100111: begin
                    if(pc_enable !== 1'b1) begin
                        $display("Error J-type: pc_enable = %b, opcode = %b", pc_enable, opcode);
                        $stop;
                    end
                    pc_in = pc + immediate;
                    #6;
                end
                // U-type & ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011, 7'b0110111, 7'b0010111: begin
                    if(pc_enable !== 1'b1) begin
                        $display("Error U/R/I-type: pc_enable = %b, opcode = %b", pc_enable, opcode);
                        $stop;
                    end
                    pc_in = pc + 4;
                    #6;
                end
                default: begin
                    $display("Error opcode case: opcode = %b", opcode);
                    $stop;
                end
            endcase
        end
    end
endmodule
