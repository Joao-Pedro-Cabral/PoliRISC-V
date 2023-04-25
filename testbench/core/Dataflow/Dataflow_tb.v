//
//! @file   Dataflow_tb.v
//! @brief  Testbench do Dataflow
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-23
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do Dataflow 
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato e Banco de Registradores estão corretos.
// Com isso, basta testar se o Dataflow consegue interligar os componentes 
// e se os componentes funcionam corretamente.
// Para isso irei verificar as saídas do DF (principalmente pc e db_reg_data,
// pois elas determinam o contexto)
// Veja que db_reg_data é usada apenas para depuração (dado a ser escrito no banco)

`timescale 1 ns / 100 ps

module Dataflow_tb();
    // sinais do DUT
        // Common
    reg clock;
    reg reset;
        // Instruction Memory
    wire [31:0] instruction;
    wire [63:0] instruction_address;
        // Data Memory
    wire [63:0] read_data;
    wire [63:0] write_data;
    wire [63:0] data_address;
        // From Control Unit (LUT_uc)
    reg alua_src;
    reg alub_src;
    reg aluy_src;
    reg [2:0] alu_src;
    reg sub;
    reg arithmetic;
    reg alupc_src;
    reg pc_src;
    reg pc_enable;
    reg [2:0] read_data_src;
    reg [1:0] write_register_src;
    reg write_register_enable;
    reg ir_enable;
        // To Control Unit
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire zero;
    wire negative;
    wire carry_out;
    wire overflow;
    wire [63:0] db_reg_data;
    // Sinais da Memória de Instrução
    reg  instruction_mem_enable;
    wire instruction_mem_busy;
    // Sinais da Memória de Dados
    reg  data_mem_read_enable;
    reg  [7:0] data_mem_byte_write_enable;
    wire data_mem_busy;
    // Sinais intermediários de teste
    reg  [41:0]   LUT_uc [48:0];    // UC simulada com tabela(google sheets)
    wire [2057:0] LUT_linear;       // Tabela acima linearizada
    reg  [24:0]   df_src;           // sinais da UC para o df
    wire [63:0]   immediate;        // Saída do Extensor de Imediato do TB
    wire [63:0]   A_immediate;      // A + imediato
    reg  [63:0]   reg_data;         // write data do banco de registradores
    wire [63:0]   A;                // read data 1 do banco de registradores
    wire [63:0]   B;                // read data 2 do banco de registradores
    reg  [63:0]   pc = 0;           // pc -> Uso esse pc para acessar a memória de instrução(para tentar achar mais erros)
    reg  [63:0]   pc_imm;           // pc + (imediato << 1) OU {A + immediate[63:1], 0} -> JALR
    reg  [63:0]   pc_4;             // pc + 4
    wire [63:0]   read_data_extend; // dado lido após aplicação da extensão de sinal
    // flags da ULA ->  geradas de forma simulada
    wire zero_;
    wire negative_;
    wire carry_out_;
    wire overflow_;
    wire [63:0] xorB;
    wire [63:0] add_sub;
    // variáveis
    integer limit = 10000; // número máximo de iterações a serem feitas(evitar loop infinito)
    integer i;
    genvar  j;

    // DUT
    Dataflow DUT (.clock(clock), .reset(reset), .instruction(instruction), .instruction_address(instruction_address), .read_data(read_data), .write_data(write_data), .ir_enable(ir_enable),
     .data_address(data_address), .alua_src(alua_src), .alub_src(alub_src), .aluy_src(aluy_src), .alu_src(alu_src), .sub(sub), .arithmetic(arithmetic), .alupc_src(alupc_src),
     .pc_src(pc_src), .pc_enable(pc_enable), .read_data_src(read_data_src), .write_register_src(write_register_src), .write_register_enable(write_register_enable), .opcode(opcode),
     .funct3(funct3), .funct7(funct7), .zero(zero), .negative(negative), .carry_out(carry_out), .overflow(overflow), .db_reg_data(db_reg_data));

    // Instruction Memory
    ROM #(.rom_init_file("./Dataflow.mif"), .word_size(8), .addr_size(10), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock),
                            .enable(instruction_mem_enable), .addr(pc[9:0]), .data(instruction), .busy(instruction_mem_busy));

    // Data Memory
    single_port_ram #(.RAM_INIT_FILE("./MIFs/memory/RAM/ram_init_file.mif"), .ADDR_SIZE(6), .BYTE_SIZE(8), .DATA_SIZE(64), .BUSY_TIME(12)) Data_Memory (.clk(clock), .address(data_address), .write_data(write_data),
                        .output_enable(data_mem_read_enable), .chip_select(1'b1), .byte_write_enable(data_mem_byte_write_enable), .read_data(read_data), .busy(data_mem_busy));

    // Componentes auxiliares para a verificação -> Supostamente corretos
    ImmediateExtender extensor_imediato (.immediate(immediate), .instruction(instruction));
    register_file #(.size(64), .N(5)) banco_de_registradores (.clock(clock), .reset(reset), .write_enable(write_register_enable), .read_address1(instruction[19:15]),
                                .read_address2(instruction[24:20]), .write_address(instruction[11:7]), .write_data(reg_data), .read_data1(A), .read_data2(B));

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

    // função para determinar os seletores(sinais provenientes da UC) a partir do opcode, funct3 e funct7
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

    // função que simula o comportamento da ULA
    function [63:0] ULA_function(input [63:0] A, input [63:0] B, input [3:0] seletor);
            reg   [63:0] xorB;
            reg   [63:0] add_sub;
            reg   overflow;
            reg   carry_out;
            reg   negative;
        begin
            // Funções da ULA
            case (seletor)
                4'b0000: // ADD
                    ULA_function = $signed(A) + $signed(B);
                4'b0001: // SLL
                    ULA_function = A << (B[5:0]);
                4'b0010: begin // SLT
                    xorB     = B ^ 64'sb11;
                    add_sub  = xorB + A + 64'b01;
                    negative = add_sub[63];
                    overflow = (~(A[63] ^ B[63])) & (A[63] ^ add_sub[63]);
                    ULA_function = negative ^ overflow;
                end
                4'b0011: begin // SLTU
                    xorB                  = B ^ 64'sb11;
                    {carry_out, add_sub}  = xorB + A + 64'b01;
                    ULA_function          = ~ carry_out;
                end
                4'b0100: // XOR
                    ULA_function = A ^ B;
                4'b0101: // SRL
                    ULA_function = A >> (B[5:0]);
                4'b0110: // OR
                    ULA_function = A | B;
                4'b0111: // AND
                    ULA_function = A & B;
                4'b1000: // SUB
                    ULA_function = $signed(A) - $signed(B);
                4'b1101: // SRA
                    ULA_function = $signed(A) >>> (B[5:0]);
            endcase
        end
    endfunction

    // flags da ULA -> Apenas conferidas para B-type
    assign xorB                  = B ^ {64{1'b1}};
    assign {carry_out_, add_sub} = A + xorB + 64'b01;
    assign zero_                 = ~(|add_sub);
    assign negative_             = add_sub[63];
    assign overflow_             = (~(A[63] ^ B[63])) & (A[63] ^ add_sub[63]);

    // geração do A_immediate
    assign A_immediate = A + immediate;

    // geração do read_data_extended -> Leitura de memória após aplicar as máscaras(LD, LH, LW, LD)
    assign read_data_extend[7:0]   = read_data[7:0];
    assign read_data_extend[15:8]  = (read_data_src[1] | read_data_src[0]) ? read_data[15:8] : ({8{read_data[7] & read_data_src[2]}});
    assign read_data_extend[31:16] = read_data_src[1] ? read_data[31:16] : (read_data_src[0]) ? ({16{read_data[15] & read_data_src[2]}}) : ({16{read_data[7] & read_data_src[2]}});
    assign read_data_extend[63:32] = read_data_src[1] ? (read_data_src[0] ? read_data[63:32] : {32{read_data[31] & read_data_src[2]}}) : (read_data_src[0] ? {32{read_data[15] & read_data_src[2]}} : {32{read_data[7] & read_data_src[2]}});

    // testar o DUT
    initial begin
        $display("Program  size: %d", `program_size); // program size -> tamanho do programa a ser rodado
        $readmemb("./MIFs/core/RV64I/RV64I.mif", LUT_uc); // mif com os valores da LUT_uc(google sheets)
        $display("SOT!");
        // desabilito os enables no começo
        pc_enable = 1'b0;
        write_register_enable = 1'b0;
        instruction_mem_enable = 1'b0;
        ir_enable = 1'b0;
        // Idle
        #2; // espero 2ns e reseto
        reset = 1'b1;
        #6; // 6ns = 1 ciclo de clock
        reset = 1'b0;
        #6; 
        // fim do reset
        for(i = 0; i < limit; i = i + 1) begin
            $display("Test: %d", i);
            // Fetch -> reseto sinais de enable
            // Nota: ao final de todos os executes espero até a borda de descida
            // Não é necessário essa espera, apenas fiz isso para que as atribuições
            // fiquem mais espaçadas na forma de onda e facilitem a depuração
            pc_enable = 1'b0;
            write_register_enable = 1'b0;
            ir_enable = 1'b0;
            #0.1; // espero um pouco
            // Testo o endereço de acesso a Memória de Instrução
            if(pc !== instruction_address) begin
                $display("Error Fetch PC: pc = %x, instruction_address = %x", pc, instruction_address);
                $stop;
            end
            instruction_mem_enable = 1'b1; // habilito a memória
            wait (instruction_mem_busy == 1'b1);
            wait (instruction_mem_busy == 1'b0);
            instruction_mem_enable = 1'b0; // desabilito, após descida do busy
            ir_enable = 1'b1; // habilito IR
            wait (clock == 1'b0);
            wait (clock == 1'b1); // espero o clock subir
            #0.1;
            // Decode (testo se a saída do IR está correta: opcode, funct3, funct7)
            if(opcode !== instruction[6:0] || funct3 !== instruction[14:12] || funct7 !== instruction[31:25]) begin
                $display("Error Decode: opcode = %x, funct3 = %x, funct7 = %x", opcode, funct3, funct7);
                $stop;
            end
            // Obtenho os sinais da UC
            df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
            ir_enable = 1'b0;
            wait (clock == 1'b0); // Espero a borda de descida
            // Execute(atribuo aos sinais de controle do DF os valores do sheets)
            alua_src                    = df_src[24];
            alub_src                    = df_src[23];
            aluy_src                    = df_src[22];
            alu_src                     = df_src[21:19];
            sub                         = df_src[18];
            arithmetic                  = df_src[17];
            alupc_src                   = df_src[16];
            read_data_src               = df_src[14:12];
            write_register_src          = df_src[11:10];
            data_mem_read_enable        = df_src[8];
            data_mem_byte_write_enable  = df_src[7:0];
            // Executa e Testa: sempre que houver um erro a simulação parará
            case (opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011: begin
                    pc_src = df_src[15];
                    #0.1;
                    // Confiro o endereço de acesso
                    if(data_address !== A + immediate) begin
                        $display("Error Load/Store: data_address = %x, A = %x, immediate = %x, opcode = %x", data_address, A, immediate, opcode);
                        $stop;
                    end
                    // Caso seja store -> confiro a palavra a ser escrita
                    if(opcode[5] === 1'b1 && write_data !== B) begin
                        $display("Error Store: write_data = %x, B = %x", write_data, B);
                        $stop;
                    end
                    wait (data_mem_busy == 1'b1);
                    wait (data_mem_busy == 1'b0); // espero o busy descer
                    data_mem_read_enable = 1'b0;  // desabilito a memória
                    write_register_enable = df_src[9]; // caso necessário habilito a escrita no banco
                    reg_data = read_data_extend; // escrevo no banco
                    #0.1;
                    // Caso L* -> confiro a leitura
                    if(opcode[5] === 1'b0 && db_reg_data !== reg_data) begin
                        $display("Error Load: db_reg_data = %x, reg_data = %x", db_reg_data, reg_data);
                        $stop;
                    end
                    // Incremento PC
                    pc_enable = 1'b1;
                    pc_4 = pc + 4;
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    #0.1;
                    // Ciclo seguinte: Confiro novo valor de PC
                    if(pc_4 !== instruction_address) begin
                        $display("Error AUIPC/LUI PC: pc_4 = %x, pc = %x", pc_4, instruction_address);
                        $stop;
                    end
                    pc = pc_4;
                    wait (clock == 1'b0);
                end
                // Branch(B*)
                7'b1100011: begin
                    // Decido o valor de pc_src com base em funct3 e no valor das flags simuladas
                    if(funct3[2:1] === 2'b00)
                        pc_src = zero_ ^ funct3[0];
                    else if(funct3[2:1] === 2'b10)
                        pc_src = negative_ ^ overflow ^ funct3[0];
                    else if(funct3[2:1] === 2'b11)
                        pc_src = carry_out_ ~^ funct3[0];
                    else begin
                        $display("Error B-type: Invalid funct3! funct3 : %x", funct3);
                        $stop;
                    end
                    // Habilito o pc
                    pc_4                  = pc + 4;
                    pc_imm                = pc + (immediate << 1);
                    pc_enable             = 1'b1;
                    write_register_enable = 1'b0;
                    #0.1;
                    // Confiro as flags da ULA
                    if(overflow !== overflow_ || carry_out !== carry_out_ || negative !== negative_ || zero !== zero_) begin
                        $display("Error B-type flags: overflow = %x, carry_out = %x, negative = %x, zero = %x, funct3 = %x", overflow, carry_out, negative, zero, funct3);
                        $stop;
                    end
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o novo valor do pc está correto
                    if((pc_src === 1'b1 && pc_imm !== instruction_address) || (pc_src === 1'b0 && pc_4 !== instruction_address)) begin
                        $display("Error B-type PC: pc_src = %x, pc_imm = %x, pc_4 = %x, pc = %x", pc_src, pc_imm, pc_4, instruction_address);
                        $stop;
                    end
                    // Incremento pc
                    if(pc_src === 1'b1) 
                        pc = pc_imm;
                    else
                        pc = pc_4;
                    wait (clock == 1'b0);
                end
                // LUI e AUIPC
                7'b0110111, 7'b0010111: begin
                    // Habilito o pc e o banco
                    pc_src    = df_src[15];
                    pc_enable = 1'b1;
                    write_register_enable = 1'b1;
                    if(opcode[5] === 1)
                        reg_data = immediate; // LUI
                    else
                        reg_data = pc + immediate; // AUIPC
                    #0.1;
                    // Confiro se db_reg_data está correto
                    if(reg_data !== db_reg_data) begin
                        $display("Error AUIPC/LUI: reg_data = %x, db_reg_data = %x, opcode = %x", reg_data, db_reg_data, opcode);
                        $stop;
                    end
                    pc_4 = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(pc_4 !== instruction_address) begin
                        $display("Error AUIPC/LUI PC: pc_4 = %x, pc = %x", pc_4, instruction_address);
                        $stop;
                    end
                    // Incremento pc
                    pc = pc_4;
                    wait (clock == 1'b0);
                end
                // JAL e JALR
                7'b1101111, 7'b1100111: begin
                    // Habilito pc e o banco
                    pc_src    = df_src[15];
                    pc_enable = 1'b1;
                    write_register_enable = 1'b1;
                    if(opcode[3] === 1'b1)
                        pc_imm    = pc + (immediate << 1); // JAL
                    else
                        pc_imm    = {A_immediate[63:1],1'b0}; // JALR
                    reg_data = pc + 4; // escrever pc + 4 no banco -> Link
                    #0.1;
                    // Confiro a escrita no banco
                    if(db_reg_data !== reg_data) begin
                        $display("Error JAL/JALR: reg_data = %x, reg_data = %x, opcode = %x", db_reg_data, reg_data, opcode);
                        $stop;
                    end
                    wait (clock == 1'b1);
                    #0.1;
                    // No ciclo seguinte, confiro o salto
                    if(pc_imm !== instruction_address) begin
                        $display("Error JAL/JALR: pc_imm = %x, instruction_address = %x", pc_imm, instruction_address);
                        $stop;
                    end
                    // Atualizo pc
                    pc = pc_imm;
                    wait(clock == 1'b0);
                end
                // ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
                    // Habilito pc e o banco
                    pc_src    = df_src[15];
                    pc_enable = 1'b1;
                    write_register_enable = 1'b1;
                    #0.1;
                    // Uso ULA_function para calcular o reg_data
                    if(opcode[5] === 1'b1)
                        reg_data = ULA_function(A, B, {funct7[5], funct3});
                    else if(funct3 === 3'b101)
                        reg_data = ULA_function(A, immediate, {funct7[5], funct3});
                    else
                        reg_data = ULA_function(A, immediate, {1'b0, funct3});
                    if(opcode[3] === 1'b1)
                        reg_data = {{32{reg_data[31]}},reg_data[31:0]};
                    #0.1;
                    // Verifico db_reg_data
                    if(reg_data !== db_reg_data) begin
                        $display("Error ULA R/I-type: reg_data = %x, db_reg_data = %x, opcode = %x, funct3 = %x, funct7 = %x", reg_data, db_reg_data, opcode, funct3, funct7);
                        $stop;
                    end
                    pc_4 = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a borda de subida, confiro se o pc foi incrementado corretamente
                    if(pc_4 !== instruction_address) begin
                        $display("Error ULA R-type PC: pc_4 = %x, pc = %x", pc_4, instruction_address);
                        $stop;
                    end
                    pc = pc_4;
                    wait(clock == 1'b0);
                end
                7'b0000000: begin
                    // Fim do programa -> última instrução 0000000
                    if(pc === `program_size - 3)
                        $display("End of program!");
                    else
                        $display("Error opcode case: opcode = %x", opcode);
                    $stop;
                end
                default: begin // Erro: opcode inexistente
                    $display("Error opcode case: opcode = %x", opcode);
                    $stop;
                end
            endcase
        end
        $stop;
    end
endmodule