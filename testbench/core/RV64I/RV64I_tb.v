//
//! @file   RV64I_tb.v
//! @brief  Testbench do RV64I sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

// Ideia do testbench: testar ciclo a ciclo o comportamento do toplevel
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, Extensor de Imediato e Banco de Registradores estão corretos.
// Com isso, basta testar se o toplevel consegue interligar a UC e o DF
// corretamente e se o comportamento desses componentes está sincronizado
// Para isso irei verificar as saídas do toplevel 
// Veja que db_reg_data é usada apenas para depuração (dado a ser escrito no banco)

`timescale 1 ns / 100 ps

module RV64I_tb();
    // sinais do DUT
    reg  clock;
    reg  reset;
        // Data Memory
    wire [63:0] read_data;
    wire [63:0] write_data;
    wire [63:0] data_address;
    wire data_mem_busy;
    wire data_mem_read_enable;
    wire [7:0] data_mem_byte_write_enable;
        // Instruction Memory
    wire [31:0] instruction;
    wire [63:0] instruction_address;
    wire instruction_mem_busy;
    wire instruction_mem_enable;
        // depuracao
    wire [63:0] db_reg_data;
    // Sinais intermediários de teste
    wire [6:0]  opcode;                         // opcode simulado pelo TB            
    wire [2:0]  funct3;                         // funct3 simulado pelo TB            
    wire [6:0]  funct7;                         // funct7 simulado pelo TB            
    wire [63:0] immediate;                      // Saída do Extensor de Imediato do TB
    wire [63:0] A_immediate;                    // A + imediato
    reg  write_register_enable;                 // write enable do banco de registradores
    wire [7:0] data_mem_byte_write_enable_;     // data mem byte write enable simulado pelo TB
    wire data_mem_read_enable_;                 // data mem read enable simulado pelo TB
    reg  [63:0] reg_data;                       // write data do banco de registradores
    wire [63:0] A;                              // read data 1 do banco de registradores
    wire [63:0] B;                              // read data 2 do banco de registradores
    reg  [63:0] pc = 0;                         // pc -> Uso esse pc para acessar a memória de instrução(para tentar achar mais erros)
    reg  pc_src;                                // seletor da entrada do registrador PC
    reg  [63:0] pc_imm;                         // pc + imediato
    reg  [63:0] pc_4;                           // pc + 4
    wire [63:0] read_data_extend;               // dado lido após aplicação da extensão de sinal
    wire [2:0]  read_data_src;                  // read_data_src simulado pelo TB -> realiza máscara do read_data_extend
    wire store;                                 // 1, caso esteja sendo executado um S*
    // flags da ULA (simuladas)
    wire zero_;
    wire negative_;
    wire carry_out_;
    wire overflow_;
    wire [63:0] xorB;
    wire [63:0] add_sub;
    // variáveis
    integer limit = 1000;                       // tamanho do programa que será executado
    integer i;
    integer estado = 0;                         // sinal de depuração -> 0: Idle, 1: Fetch, 2: Decode, 3: Execute  

    // DUT
    RV64I DUT (.clock(clock), .reset(reset), .read_data(read_data), .write_data(write_data), .data_address(data_address), .data_mem_busy(data_mem_busy),
    .data_mem_read_enable(data_mem_read_enable), .data_mem_byte_write_enable(data_mem_byte_write_enable), .instruction(instruction), .instruction_address(instruction_address),
    .instruction_mem_busy(instruction_mem_busy), .instruction_mem_enable(instruction_mem_enable), .db_reg_data(db_reg_data));

    // Instruction Memory
    ROM #(.rom_init_file("./MIFs/memory/ROM/power.mif"), .word_size(8), .addr_size(10), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock), 
                            .enable(instruction_mem_enable), .addr(pc[9:0]), .data(instruction), .busy(instruction_mem_busy));

    // Data Memory
    single_port_ram #(.RAM_INIT_FILE("./MIFs/memory/RAM/power.mif"), .ADDR_SIZE(8), .BYTE_SIZE(8), .DATA_SIZE(64), .BUSY_TIME(12)) Data_Memory (.clk(clock), .address(data_address), .write_data(write_data), 
                .output_enable(data_mem_read_enable), .chip_select(1'b1), .byte_write_enable(data_mem_byte_write_enable), .read_data(read_data), .busy(data_mem_busy));    

    // Componentes auxiliares para a verificação
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

    // flags da ULA -> B-type
    assign xorB                  = B ^ {64{1'b1}};
    assign {carry_out_, add_sub} = A + xorB + 64'b01;
    assign zero_                 = ~(|add_sub);
    assign negative_             = add_sub[63];
    assign overflow_             = (~(A[63] ^ B[63])) & (A[63] ^ add_sub[63]);

    // geração do read_data_extended
    assign read_data_src           = {~funct3[2], funct3[1:0]};
    assign read_data_extend[7:0]   = read_data[7:0];
    assign read_data_extend[15:8]  = (read_data_src[1] | read_data_src[0]) ? read_data[15:8] : ({8{read_data[7] & read_data_src[2]}});
    assign read_data_extend[31:16] = read_data_src[1] ? read_data[31:16] : (read_data_src[0]) ? ({16{read_data[15] & read_data_src[2]}}) : ({16{read_data[7] & read_data_src[2]}});
    assign read_data_extend[63:32] = read_data_src[1] ? (read_data_src[0] ? read_data[63:32] : {32{read_data[31] & read_data_src[2]}}) : (read_data_src[0] ? {32{read_data[15] & read_data_src[2]}} : {32{read_data[7] & read_data_src[2]}});
    
    // geração dos sinais da instrução
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // geração data mem byte write enable
    assign data_mem_byte_write_enable_ = funct3[1] ? (funct3[0] ? (8'hFF & {8{store}}) : (8'h0F & {8{store}})) : (funct3[0] ? (8'h03 & {8{store}}) : (8'h01 & {8{store}}));
    assign data_mem_read_enable_ = (opcode === 7'b0000011) ? 1'b1 : 1'b0;

    // geração store
    assign store = (opcode === 7'b0100011) ? 1'b1 : 1'b0;

    // geração do A_immediate
    assign A_immediate = A + immediate;

    // testar o DUT
    initial begin : Testbench
        $display("Program  size: %d", `program_size);
        $display("SOT!");
        // desabilito a escrita no banco simulado
        write_register_enable = 1'b0;
        // Idle
        estado = 0;
        #2;
        reset = 1'b1;
        #0.1;
        // Confiro se os enables estão em baixo no Idle
        if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
            $display("Error Idle: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
            $stop;
        end
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        reset = 1'b0;
        #0.1;
        // Ciclo após reset -> Ainda estamos em Idle
        // Confiro se os enables estão em baixo
        if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
            $display("Error Idle: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
            $stop;
        end
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        for(i = 0; i < limit; i = i + 1) begin
            $display("Test: %d", i);
            // Fetch
            // Nota: ao final de todos os executes espero até a borda de descida
            // Não é necessário essa espera, apenas fiz isso para que as atribuições
            // fiquem mais espaçadas na forma de onda e facilitem a depuração
            estado = 1; // Fetch
            write_register_enable  = 1'b0;
            #0.1;
            // Confiro se há acesso a memória de instrução
            if(instruction_mem_enable !== 1 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                $display("Error Fetch: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                $stop;
            end
            wait (instruction_mem_busy == 1'b1);
            wait (instruction_mem_busy == 1'b0);
            #0.1;
            // Busy abaixado -> instruction mem enable abaixado
            if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                $display("Error Fetch: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                $stop;
            end
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            #0.1;
            // Decode 
            estado = 2; // Decode
            // Enables abaixados
            if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                $display("Error Decode: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                $stop;
            end
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            // Execute -> Teste
            estado = 3; // Execute
            case (opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011: begin
                    #0.1;
                    // Confiro o endereço de acesso
                    if(data_address !== A + immediate) begin
                        $display("Error Load/Store: data_address = %b, A = %b, immediate = %b, opcode = %b, funct3 = %b", data_address, A, immediate, opcode, funct3);
                        $stop;
                    end
                    // Caso seja store -> confiro a palavra a ser escrita
                    if(opcode[5] === 1'b1 && write_data !== B) begin
                        $display("Error Store: write_data = %b, B = %b, funct3 = %b", write_data, B, funct3);
                        $stop;
                    end
                    // Confiro se o acesso a memória de dados está correto
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== data_mem_read_enable_ || data_mem_byte_write_enable !== data_mem_byte_write_enable_) begin
                        $display("Error Load/Store: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    wait (data_mem_busy == 1'b1);
                    wait (data_mem_busy == 1'b0);
                    #0.1;
                    // Após o busy abaixar escrevo no banco simulado (caso seja Load)
                    if(opcode[5] === 1'b0) begin
                        write_register_enable = 1'b1;
                        reg_data = read_data_extend;
                    end
                    wait (clock == 1'b0);
                    #0.1;
                    // Na borda de descida, confiro se os sinais de controle abaixaram
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                        $display("Error Load/Store: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    // Caso L* -> confiro a leitura
                    if(opcode[5] === 1'b0 && db_reg_data !== reg_data) begin
                        $display("Error Load: db_reg_data = %b, reg_data = %b, funct3 = %b", db_reg_data, reg_data, funct3);
                        $stop;
                    end
                    pc = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Ciclo seguinte: Confiro se o instruction address
                    if(instruction_address !== pc) begin
                        $display("Error Load/Store: pc = %x, instruction address = %x", pc, instruction_address);
                        $stop;
                    end
                    wait (clock == 1'b0);
                end
                // Branch(B*)
                7'b1100011: begin
                    #0.1;
                    // Decido o valor de pc_src com base em funct3 e no valor das flags simuladas
                    if(funct3[2:1] === 2'b00)
                        pc_src = zero_ ^ funct3[0];
                    else if(funct3[2:1] === 2'b10)
                        pc_src = negative_ ^ overflow_ ^ funct3[0];
                    else if(funct3[2:1] === 2'b11)
                        pc_src = carry_out_ ~^ funct3[0];
                    else
                        $display("Error B-type: Invalid funct3! Funct3 : %b", funct3);
                    // Habilito o pc
                    pc_4                  = pc + 4;
                    pc_imm                = pc + (immediate << 1);
                    write_register_enable = 1'b0;
                    #0.1;
                    // Confiro as flags da ULA
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                        $display("Error B-type: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o novo valor do pc está correto
                    if((pc_src === 1 && pc_imm !== instruction_address) || (pc_src === 0 && pc_4 !== instruction_address)) begin
                        $display("Error B-type PC: pc_src = %b, pc_imm = %b, pc_4 = %b, pc = %b", pc_src, pc_imm, pc_4, instruction_address);
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
                    // Habilito o banco simulado
                    write_register_enable = 1'b1;
                    if(opcode[5] === 1)
                        reg_data = immediate; // LUI
                    else
                        reg_data = instruction_address + immediate; // AUIPC
                    #0.1;
                    // Confiro se db_reg_data está correto
                    if(reg_data !== db_reg_data) begin
                        $display("Error AUIPC/LUI: reg_data = %b, db_reg_data = %b, opcode = %b", reg_data, db_reg_data, opcode);
                        $stop;
                    end
                    // Verifico se os enables estão desligados
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                        $display("Error LUI/AUIPC: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(instruction_address !== pc) begin
                        $display("Error Load/Store: pc = %x, instruction address = %x", pc, instruction_address);
                        $stop;
                    end
                    wait (clock == 1'b0);
                end
                // JAL e JALR
                7'b1101111, 7'b1100111: begin
                    // Habilito o banco simulado
                    write_register_enable = 1'b1;
                    // Decido o novo valor de pc a partir do opcode da instrução (salto incondicional)
                    if(opcode[3] === 1'b1)
                        pc_imm    = instruction_address + (immediate << 1); // JAL
                    else
                        pc_imm    = {A_immediate[63:1],1'b0}; // JALR 
                    reg_data = pc + 4; // escrever pc + 4 no banco -> Link
                    #0.1;
                    // Confiro a escrita no banco
                    if(db_reg_data !== reg_data) begin
                        $display("Error JAL/JALR: reg_data = %b, reg_data = %b, opcode = %b", db_reg_data, reg_data, opcode);
                        $stop;
                    end
                    // Verifico se os enables estão desligados
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                        $display("Error JAL/JALR: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc_imm;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(pc !== instruction_address) begin
                        $display("Error JAL/JALR: pc = %b, instruction_address = %b", pc, instruction_address);
                        $stop;    
                    end
                    wait (clock == 1'b0);
                end
                // ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
                    // Habilito o banco simulado
                    write_register_enable = 1'b1;
                    // A partir do opcode, do funct3 e do funct7 descubro o resultado da operação da ULA com a máscara aplicada
                    if(opcode[5] === 1'b1)
                        reg_data = ULA_function(A, B, {funct7[5], funct3});
                    else if(funct3 === 3'b101)
                        reg_data = ULA_function(A, immediate, {funct7[5], funct3});
                    else
                        reg_data = ULA_function(A, immediate, {1'b0, funct3});
                    if(opcode[3] === 1'b1)
                        reg_data = {{32{reg_data[31]}},reg_data[31:0]};
                    #0.1;
                    // Confiro a escrita no banco
                    if(reg_data !== db_reg_data) begin
                        $display("Error ULA R/I-type: reg_data = %b, db_reg_data = %b, funct7 = %b, funct3 = %b", reg_data, db_reg_data, funct7, funct3);
                        $stop;
                    end
                    // Verifico se os enables estão desligados
                    if(instruction_mem_enable !== 0 || data_mem_read_enable !== 0 || data_mem_byte_write_enable !== 0) begin
                        $display("Error ULA R/I-type: instruction_mem_enable = %b, data_mem_read_enable = %b, data_mem_byte_write_enable = %b", instruction_mem_enable, data_mem_read_enable, data_mem_byte_write_enable);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(instruction_address !== pc) begin
                        $display("Error Load/Store: pc = %x, instruction address = %x", pc, instruction_address);
                        $stop;
                    end
                    wait (clock == 1'b0);
                end
                7'b0000000: begin
                    // Fim do programa -> último opcode: 0000000
                    if(pc === `program_size - 3)
                        $display("End  of program!");
                    else
                        $display("Error opcode case: opcode = %b", opcode);
                    $stop;
                end
                default: begin // Erro: opcode inexistente
                    $display("Error opcode case: opcode = %b", opcode);
                    $stop;
                end
            endcase
        end
    end
endmodule
