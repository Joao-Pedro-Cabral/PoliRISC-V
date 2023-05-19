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
    wire [63:0] rd_data;
    wire [63:0] wr_data;
    wire [63:0] mem_addr;
    wire mem_busy;
    wire mem_rd_en;
    wire mem_wr_en;
    wire [7:0] mem_byte_en;
        // depuracao
    wire [63:0] db_reg_data;
    // Sinais intermediários de teste
    wire [6:0]  opcode;                         // opcode simulado pelo TB            
    wire [2:0]  funct3;                         // funct3 simulado pelo TB            
    wire [6:0]  funct7;                         // funct7 simulado pelo TB     
    reg  [31:0] instruction;                    // Instrução executada pelo DUT       
    wire [63:0] immediate;                      // Saída do Extensor de Imediato do TB
    wire [63:0] A_immediate;                    // A + imediato
    reg  wr_reg_en;                             // write enable do banco de registradores
    wire [7:0] mem_byte_en_;                    // data mem byte write enable simulado pelo TB
    wire mem_rd_en_;                            // data mem read enable simulado pelo TB
    wire mem_wr_en_;                            // data mem write enable simulado pelo TB
    reg  [63:0] reg_data;                       // write data do banco de registradores
    wire [63:0] A;                              // read data 1 do banco de registradores
    wire [63:0] B;                              // read data 2 do banco de registradores
    reg  [63:0] pc = 0;                         // pc -> Uso esse pc para acessar a memória de instrução(para tentar achar mais erros)
    reg  pc_src;                                // seletor da entrada do registrador PC
    reg  [63:0] pc_imm;                         // pc + imediato
    reg  [63:0] pc_4;                           // pc + 4
    wire mem_op;                                // 1, caso esteja sendo executado um S* ou L*
    // Sinais do Barramento
        // Instruction Memory
    wire [63:0] rom_data;
    wire [63:0] rom_addr;
    wire rom_enable;
    wire rom_busy;
        // Data Memory
    wire [63:0] ram_address;
    wire [63:0] ram_write_data;
    wire [63:0] ram_read_data;
    wire ram_output_enable;
    wire ram_write_enable;
    wire ram_chip_select;
    wire [7:0] ram_byte_enable;
    wire ram_busy;
    // flags da ULA (simuladas)
    wire zero_;
    wire negative_;
    wire carry_out_;
    wire overflow_;
    wire [63:0] xorB;
    wire [63:0] add_sub;
    // Sinais da Cache
    wire    [  63:0] inst_data;
    wire             inst_busy;
    wire             inst_enable;
    wire    [  63:0] inst_addr;
    // variáveis
    integer limit = 1000;                       // tamanho do programa que será executado
    integer i;
    integer estado = 0;                         // sinal de depuração -> 0: Idle, 1: Fetch, 2: Decode, 3: Execute  

    // DUT
    RV64I DUT (
        .clock(clock),
        .reset(reset),
        .rd_data(rd_data),
        .wr_data(wr_data),
        .mem_addr(mem_addr),
        .mem_busy(mem_busy),
        .mem_rd_en(mem_rd_en),
        .mem_byte_en(mem_byte_en),
        .mem_wr_en(mem_wr_en),
        .db_reg_data(db_reg_data)
    );

    // Instanciação do barramento
    memory_controller BUS (
        .mem_rd_en(mem_rd_en),
        .mem_wr_en(mem_wr_en),
        .mem_byte_en(mem_byte_en),
        .wr_data(wr_data),
        .mem_addr(mem_addr),
        .rd_data(rd_data),
        .mem_busy(mem_busy),
        .inst_cache_data(rom_data),
        .inst_cache_busy(rom_busy),
        .inst_cache_enable(rom_enable),
        .inst_cache_addr(rom_addr),
        .ram_read_data(ram_read_data),
        .ram_busy(ram_busy),
        .ram_address(ram_address),
        .ram_write_data(ram_write_data),
        .ram_output_enable(ram_output_enable),
        .ram_write_enable(ram_write_enable),
        .ram_chip_select(ram_chip_select),
        .ram_byte_enable(ram_byte_enable)
    );

  instruction_cache #(
      .L2_CACHE_SIZE(3),
      .L2_BLOCK_SIZE(2)
  ) cache (
      .clock(clock),
      .reset(reset),
      .inst_data(inst_data),
      .inst_busy(inst_busy),
      .inst_enable(inst_enable),
      .inst_addr(inst_addr),
      .inst_cache_enable(rom_enable),
      .inst_cache_addr(rom_addr),
      .inst_cache_data(rom_data),
      .inst_cache_busy(rom_busy)
  );


    // Instruction Memory
    ROM #(
        .rom_init_file("./MIFs/memory/ROM/power.mif"),
        .word_size(8),
        .addr_size(10),
        .offset(3),
        .busy_cycles(2)
    ) Instruction_Memory (
        .clock(clock),
        .enable(inst_enable),
        .addr(inst_addr[9:0]),
        .data(inst_data),
        .busy(inst_busy)
    );

    // Data Memory
    single_port_ram #(.RAM_INIT_FILE("./MIFs/memory/RAM/power.mif"), .ADDR_SIZE(12), .BYTE_SIZE(8), .DATA_SIZE(64), .BUSY_CYCLES(2)) Data_Memory (.clk(clock), .address(ram_address), .write_data(ram_write_data),
                        .output_enable(ram_output_enable), .write_enable(ram_write_enable), .chip_select(ram_chip_select), .byte_enable(ram_byte_enable), .read_data(ram_read_data), .busy(ram_busy));

    // Componentes auxiliares para a verificação
    ImmediateExtender extensor_imediato (.immediate(immediate), .instruction(instruction));
    register_file #(.size(64), .N(5)) banco_de_registradores (.clock(clock), .reset(reset), .write_enable(wr_reg_en), .read_address1(instruction[19:15]),
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
                    xorB     = B ^ -64'b1;
                    add_sub  = xorB + A + 64'b01;
                    negative = add_sub[63];
                    overflow = (~(A[63] ^ B[63] ^ 1'b1)) & (A[63] ^ add_sub[63]);
                    ULA_function = {{63{1'b0}}, negative ^ overflow};
                end
                4'b0011: begin // SLTU
                    xorB                  = B ^ -64'b1;
                    {carry_out, add_sub}  = xorB + A + 64'b01;
                    ULA_function          = {{63{1'b0}}, ~carry_out};
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
    assign overflow_             = (~(A[63] ^ B[63] ^ DUT.sub)) & (A[63] ^ add_sub[63]);
    
    // geração dos sinais da instrução
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // geração dos sinais de controle do barramento
    assign mem_op = (opcode === 7'b0100011 || opcode === 7'b0000011) ? 1'b1 : 1'b0;
    assign mem_byte_en_ = funct3[1] ? (funct3[0] ? (8'hFF & {8{mem_op}}) : (8'h0F & {8{mem_op}})) : (funct3[0] ? (8'h03 & {8{mem_op}}) : (8'h01 & {8{mem_op}}));
    assign mem_rd_en_   = (opcode === 7'b0000011) ? 1'b1 : 1'b0;
    assign mem_wr_en_   = (opcode === 7'b0100011) ? 1'b1 : 1'b0;

    // geração do A_immediate
    assign A_immediate = A + immediate;

    // testar o DUT
    initial begin : Testbench
        $display("Program  size: %d", `program_size);
        $display("SOT!");
        // desabilito a escrita no banco simulado
        wr_reg_en = 1'b0;
        // Idle
        estado = 0;
        #2;
        reset = 1'b1;
        #0.1;
        // Confiro se os enables estão em baixo no Idle
        if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
            $display("Error Idle: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
            $stop;
        end
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        reset = 1'b0;
        #0.1;
        // Ciclo após reset -> Ainda estamos em Idle
        // Confiro se os enables estão em baixo
        if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
            $display("Error Idle: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
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
            wr_reg_en  = 1'b0;
            #0.1;
            // Confiro se há acesso a memória de instrução
            if(mem_wr_en !== 0 || mem_rd_en !== 1'b1 || mem_byte_en !== 8'h0F) begin
                $display("Error Fetch: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                $stop;
            end
            wait (mem_busy == 1'b1);
            wait (mem_busy == 1'b0);
            #0.1;
            instruction = rd_data; // leitura da ROM -> instrução
            // Busy abaixado -> instruction mem enable abaixado
            if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 8'h0F) begin
                $display("Error Fetch: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                $stop;
            end
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            #0.1;
            // Decode 
            estado = 2; // Decode
            // Enables abaixados
            if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
                $display("Error Decode: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
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
                    if(mem_addr !== A + immediate) begin
                        $display("Error Load/Store: mem_addr = %b, A = %b, immediate = %b, opcode = %b, funct3 = %b", mem_addr, A, immediate, opcode, funct3);
                        $stop;
                    end
                    // Caso seja store -> confiro a palavra a ser escrita
                    if(opcode[5] === 1'b1 && wr_data !== B) begin
                        $display("Error Store: wr_data = %b, B = %b, funct3 = %b", wr_data, B, funct3);
                        $stop;
                    end
                    // Confiro se o acesso a memória de dados está correto
                    if(mem_byte_en !== mem_byte_en_ || mem_rd_en !== mem_rd_en_ || mem_wr_en !== mem_wr_en_) begin
                        $display("Error mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                        $stop;
                    end
                    wait (mem_busy == 1'b1);
                    wait (mem_busy == 1'b0);
                    #0.1;
                    // Após o busy abaixar escrevo no banco simulado (caso seja Load)
                    if(opcode[5] === 1'b0) begin
                        wr_reg_en = 1'b1;
                        reg_data = rd_data;
                    end
                    wait (clock == 1'b0);
                    #0.1;
                    // Na borda de descida, confiro se os sinais de controle abaixaram
                    if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== mem_byte_en_) begin
                        $display("Error Load/Store: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
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
                    if(mem_addr !== pc) begin
                        $display("Error Load/Store: pc = %x, mem_addr = %x", pc, mem_addr);
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
                    wr_reg_en = 1'b0;
                    #0.1;
                    // Confiro as flags da ULA
                    if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
                        $display("Error B-type: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o novo valor do pc está correto
                    if((pc_src === 1 && pc_imm !== mem_addr) || (pc_src === 0 && pc_4 !== mem_addr)) begin
                        $display("Error B-type PC: pc_src = %b, pc_imm = %b, pc_4 = %b, mem_addr = %b", pc_src, pc_imm, pc_4, mem_addr);
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
                    wr_reg_en = 1'b1;
                    if(opcode[5] === 1)
                        reg_data = immediate; // LUI
                    else
                        reg_data = mem_addr + immediate; // AUIPC
                    #0.1;
                    // Confiro se db_reg_data está correto
                    if(reg_data !== db_reg_data) begin
                        $display("Error AUIPC/LUI: reg_data = %b, db_reg_data = %b, opcode = %b", reg_data, db_reg_data, opcode);
                        $stop;
                    end
                    // Verifico se os enables estão desligados
                    if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
                        $display("Error LUI/AUIPC: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(mem_addr !== pc) begin
                        $display("Error Load/Store: pc = %x, mem_addr = %x", pc, mem_addr);
                        $stop;
                    end
                    wait (clock == 1'b0);
                end
                // JAL e JALR
                7'b1101111, 7'b1100111: begin
                    // Habilito o banco simulado
                    wr_reg_en = 1'b1;
                    // Decido o novo valor de pc a partir do opcode da instrução (salto incondicional)
                    if(opcode[3] === 1'b1)
                        pc_imm    = mem_addr + (immediate << 1); // JAL
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
                    if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
                        $display("Error JAL/JALR: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc_imm;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(pc !== mem_addr) begin
                        $display("Error JAL/JALR: pc = %b, mem_addr = %b", pc, mem_addr);
                        $stop;    
                    end
                    wait (clock == 1'b0);
                end
                // ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
                    // Habilito o banco simulado
                    wr_reg_en = 1'b1;
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
                    if(mem_wr_en !== 0 || mem_rd_en !== 0 || mem_byte_en !== 0) begin
                        $display("Error ULA R/I-type: mem_wr_en = %b, mem_rd_en = %b, mem_byte_en = %x", mem_wr_en, mem_rd_en, mem_byte_en);
                        $stop;
                    end
                    wait (clock == 1'b0);
                    pc = pc + 4;
                    wait (clock == 1'b1);
                    #0.1;
                    // Após a subida do clock, confiro se o pc foi incrementado corretamente
                    if(mem_addr !== pc) begin
                        $display("Error Load/Store: pc = %x, mem_addr = %x", pc, mem_addr);
                        $stop;
                    end
                    wait (clock == 1'b0);
                end
                7'b0000000: begin
                    // Fim do programa -> último opcode: 0000000
                    if(pc === `program_size - 4)
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
