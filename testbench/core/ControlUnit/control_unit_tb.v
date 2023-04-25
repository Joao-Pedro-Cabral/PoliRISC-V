
//
//! @file   control_unit_tb.v
//! @brief  Testbench da control_unit
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-03
//

// Ideia do testbench: testar ciclo a ciclo o comportamento da UC 
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, DF estão corretos.
// Com isso, basta testar se a UC consegue enviar os sinais corretos
// a partir dos sinais de entrada provenientes da RAM, ROM e DF.
// Para isso irei verificar as saídas da UC

`timescale 1 ns / 100 ps

module control_unit_tb();
    // sinais do DUT
        // Common
    reg  clock;
    reg  reset;
        // Instruction Memory
    wire instruction_mem_enable;
    wire instruction_mem_busy;
    wire [63:0] instruction_address;
        // Data Memory
    wire data_mem_read_enable;
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
    wire sub;
    wire arithmetic;
    wire alupc_src;
    wire pc_src;
    wire pc_enable;
    wire [2:0] read_data_src;
    wire [1:0] write_register_src;
    wire write_register_enable;
    wire ir_enable;
    // Sinais da Memória de instruções
    wire [31:0] instruction;
    // Sinais da Memória de  Dados
    wire [63:0] data_address;
    wire [63:0] write_data;
    wire [63:0] read_data;
    // Sinais intermediários de teste
    reg  [41:0]   LUT_uc [48:0];    // UC simulada com tabela
    wire [2057:0] LUT_linear;       // Tabela acima linearizada
    reg  [24:0]   df_src;           // Sinais produzidos pelo LUT
    wire [25:0]   db_df_src;        // Sinais produzidos pela UC
    // variáveis
    integer limit = 1000;           // evitar loop infinito
    integer i;
    genvar j;

    // DUT
    control_unit DUT (.clock(clock), .reset(reset), .instruction_mem_enable(instruction_mem_enable), .instruction_mem_busy(instruction_mem_busy), .data_mem_read_enable(data_mem_read_enable),
    .data_mem_byte_write_enable(data_mem_byte_write_enable), .data_mem_busy(data_mem_busy), .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero), .ir_enable(ir_enable),
    .negative(negative), .carry_out(carry_out), .overflow(overflow), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub),
    .arithmetic(arithmetic), .alupc_src(alupc_src), .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src),
    .write_register_enable(write_register_enable));

    // Dataflow
    Dataflow DF (.clock(clock), .reset(reset), .instruction(instruction), .instruction_address(instruction_address), .read_data(read_data), .write_data(write_data), .ir_enable(ir_enable),
     .data_address(data_address), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), .arithmetic(arithmetic), .alupc_src(alupc_src),
     .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src), .write_register_enable(write_register_enable), .opcode(opcode),
     .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow), .db_reg_data());

   // Instruction Memory
    ROM #(.rom_init_file("./control_unit.mif"), .word_size(8), .addr_size(10), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock),
                            .enable(instruction_mem_enable), .addr(instruction_address[9:0]), .data(instruction), .busy(instruction_mem_busy));

    // Data Memory
    single_port_ram #(.RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"), .ADDR_SIZE(6), .BYTE_SIZE(8), .DATA_SIZE(64), .BUSY_TIME(12)) Data_Memory (.clk(clock), .address(data_address), 
        .write_data(write_data), .output_enable(data_mem_read_enable), .chip_select(1'b1), .byte_write_enable(data_mem_byte_write_enable), .read_data(read_data), .busy(data_mem_busy));


    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

    // geração do LUT linear -> função não suporta array
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
                for(i = 0; i < 3; i = i + 1) // Eu coloquei U, J nas linhas 0 a 2 do mif
                    if(opcode == LUT_linear[35+42*i+:7])
                        temp = LUT_linear[42*i+:25];
            end
            // I, S, B: opcode e funct3
            else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 ||
                opcode === 7'b0010011 || opcode === 7'b0011011 || opcode === 7'b1100111) begin
                for(i = 3; i < 34; i = i + 1) begin // Eu coloquei I, S, B nas linhas 3 a 33 do mif
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
               for(i = 34; i < 49; i = i + 1) // Eu coloquei I, S, B nas linhas 34 a 48 do mif
                    if(opcode === LUT_linear[35+42*i+:7] && funct3 === LUT_linear[32+42*i+:3] && funct7 === LUT_linear[25+42*i+:7])
                        temp = LUT_linear[42*i+:25];
            end
            find_instruction = temp;
        end
    endfunction

    // Concatenação dos sinais produzidos pela UC
    assign db_df_src = {ir_enable, alua_src, alub_src, aluy_src, alu_src, sub, arithmetic, alupc_src, pc_src, read_data_src, write_register_src, write_register_enable, data_mem_read_enable, data_mem_byte_write_enable};

    // testar o DUT
    initial begin: Testbench
        $display("Program  size: %d", `program_size);
        $readmemb("./MIFs/core/RV64I/RV64I.mif", LUT_uc);
        $display("SOT!");
        // Idle
        #2;
        reset = 1'b1; // Reseto
        #0.1;
        // Confiro se a UC está em Idle
        if(db_df_src !== 0) begin
            $display("Error Idle: db_df_src = %x", db_df_src);
            $stop;
        end
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        // No ciclo seguinte, abaixo reset e confiro se a UC ainda está em Idle
        reset = 1'b0;
        #0.1;
        if(db_df_src !== 0) begin
            $display("Error Idle: db_df_src = %x", db_df_src);
            $stop;
        end
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        for(i = 0; i < limit; i = i + 1) begin
            $display("Test: %d", i);
            // Fetch -> Apenas instruction mem enable levantado 
            #0.1;
            // Confiro apenas os enables, pois em implementações futuras os demais podem mudar(aqui eles são don't care)
            if(ir_enable !== 1'b0 || pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b1 || data_mem_read_enable !== 1'b0 || data_mem_byte_write_enable !== 8'b00) begin
                $display("Error Fetch: ir_enable = %x, pc_enable = %x, write_register_enable = %x, instruction_mem_enable = %x, data_mem_read_enable = %x, data_mem_byte_write_enable = %x", ir_enable, pc_enable, write_register_enable, instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                $stop;
            end
            wait (instruction_mem_busy == 1'b1);
            wait (instruction_mem_busy == 1'b0);
            #0.1;
            // Após a memória abaixar confiro se o ir_enable levantou e o instruction mem enable desceu
            if(ir_enable !== 1'b1 || instruction_mem_enable !== 1'b0) begin
                $display("Error Fetch: ir_enable = %x", ir_enable);
                $stop;
            end
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            #0.1;
            // Decode
            // No ciclo seguinte, obtenho as saídas da UC de acordo com o sheets
            df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
            #0.1;
            // Verifico se algum enable está erroneamente habilitado
            if(ir_enable !== 1'b0 || pc_enable !== 1'b0 || write_register_enable !== 1'b0 || instruction_mem_enable !== 1'b0 || data_mem_read_enable !== 1'b0 || data_mem_byte_write_enable !== 8'b00) begin
                $display("Error Decode: ir_enable = %x, pc_enable = %x, write_register_enable = %x, instruction_mem_enable = %x, data_mem_read_enable = %x, data_mem_byte_write_enable = %x", ir_enable, pc_enable, write_register_enable, instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                $stop;
            end
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            #0.1;
            // Execute -> Não testo pc_src para instruções do tipo B e write_register_enable para Load (caso opcode = 0 -> deixo passar)
            if(opcode !== 0 && ({1'b0,df_src[24:16], df_src[14:10], df_src[8:0]} !== {db_df_src[25:16], db_df_src[14:10], db_df_src[8:0]} || (df_src[15] !== db_df_src[15] && opcode !== 7'b1100011)
                    || (df_src[9] !== db_df_src[9] && opcode !== 7'b0000011))) begin
                $display("Error Execute: df_src = %x, db_df_src = %x", df_src, db_df_src);
                $display("df_src: %b", {1'b0,df_src[24:16], df_src[14:10], df_src[8:0]});
                $display("db_df_src: %b", {db_df_src[25:16], db_df_src[14:10], db_df_src[8:0]});
                $stop;
            end
            case(opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011: begin
                    wait (data_mem_busy == 1'b1);
                    wait (data_mem_busy == 1'b0);
                    #0.1;
                    // Espero o busy abaixar para verificar os enables
                    if(ir_enable !== 1'b0 || pc_enable !== 1'b1 || write_register_enable !== df_src[9] || data_mem_read_enable !== 1'b0 || data_mem_byte_write_enable !== 8'b00) begin
                        $display("Store/Load Error: pc_enable = %x, write_register_enable = %x, data_mem_read_enable = %x, data_mem_byte_write_enable = %x, opcode = %x, funct3 = %x", pc_enable, write_register_enable, data_mem_read_enable, data_mem_byte_write_enable, opcode, funct3);
                        $stop;
                    end
                    // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    wait (clock == 1'b0);
                end
                // Branch(B*)
                7'b1100011: begin
                    // testo pc_src de acordo com as flags do DF
                    if(funct3[2:1] === 2'b00) begin
                        if(zero ^ funct3[0] === 1'b1) begin
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                    end
                    else if(funct3[2:1] === 2'b10) begin
                        if(negative ^ overflow ^ funct3[0] === 1'b1) begin
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                    end
                    else if(funct3[2:1] === 2'b11) begin
                        if(carry_out ~^ funct3[0] === 1'b1) begin
                            if(pc_src !== 1'b1) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                        else begin
                            if(pc_src !== 1'b0) begin
                                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                                $stop;
                            end
                        end
                    end
                    else
                        $display("Error B-type: Invalid funct3! Funct3 : %x", funct3);
                    // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    wait (clock == 1'b0);
                end
                // JAL e JALR
                7'b1101111, 7'b1100111: begin
                    // Apenas checo se o pc_enable está ativado
                    if(pc_enable !== 1'b1) begin
                        $display("Error J-type: pc_enable = %x, opcode = %x", pc_enable, opcode);
                        $stop;
                    end
                    // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    wait (clock == 1'b0);
                end
                // U-type & ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011, 7'b0110111, 7'b0010111: begin
                    // Apenas checo se o pc_enable está ativado
                    if(pc_enable !== 1'b1) begin
                        $display("Error U/R/I-type: pc_enable = %x, opcode = %x", pc_enable, opcode);
                        $stop;
                    end
                    // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    wait (clock == 1'b0);
                end
                7'b0000000: begin
                    // Fim do programa -> última instrução 0000000
                    if(instruction_address === `program_size - 3)
                        $display("End of program!");
                    else
                        $display("Error opcode case: opcode = %x", opcode);
                    $stop;
                end
                default: begin // Erro: opcode  inexistente
                    $display("Error opcode case: opcode = %x", opcode);
                    $stop;
                end
            endcase
        end
    end
endmodule
