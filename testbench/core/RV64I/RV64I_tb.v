//
//! @file   RV64I_tb.v
//! @brief  Testbench do RV64I sem FENCE, ECALL e EBREAK
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-04
//

`timescale 1 ns / 100 ps

module RV64I_tb();
    // sinais do DUT
    wire clock,
    wire reset,
        // Data Memory
    wire [63:0] read_data,
    wire [63:0] write_data,
    wire [63:0] data_address,
    wire data_mem_busy,
    wire data_mem_enable,
    wire [7:0] data_mem_byte_write_enable,
        // Instruction Memory
    wire [31:0] instruction,
    wire [63:0] instruction_address,
    wire instruction_mem_busy,
    wire instruction_mem_enable,
        // depuracao
    wire [63:0] db_reg_data;
    // Sinais intermediários de teste
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [63:0] immediate;
    reg  write_register_enable;   // write enable do banco de registradores
    reg  [63:0] reg_data;         // write data do banco de registradores
    wire [63:0] A;                // read data 1 do banco de registradores
    wire [63:0] B;                // read data 2 do banco de registradores
    wire [63:0] pc;
    reg  pc_src;                  // seletor da entrada do registrador PC
    reg  [63:0] pc_imm;           // pc + imediato
    reg  [63:0] pc_4;             // pc + 4
    wire [63:0] read_data_extend; // dado lido após aplicação da extensão de sinal
    // flags da ULA
    wire zero_;
    wire negative_;
    wire carry_out_;
    wire overflow_;
    wire [63:0] xorB;
    wire [63:0] add_sub;
    // variáveis
    integer program_size = 1000; // tamanho do programa que será executado
    integer i;

    // DUT
    RV64I DUT (.clock(clock), .reset(reset), .read_data(read_data), .write_data(write_data), .data_address(data_address), .data_mem_busy(data_mem_busy),
    .data_mem_enable(data_mem_enable), .data_mem_byte_write_enable(data_mem_byte_write_enable), .instruction(instruction), .instruction_address(instruction_address),
    .instruction_mem_busy(instruction_mem_busy), .instruction_mem_enable(instruction_mem_enable), .db_reg_data(db_reg_data));

    // Instruction Memory
    ROM #(.rom_init_file("./MIFs/core/RV64I/power.mif"), .word_size(32), .addr_size(10), .offset(2), .busy_time(12)) Instruction_Memory (.clock(clock), 
                            .enable(instruction_mem_enable), .addr(instruction_address[9:0]), .data(instruction), .busy(instruction_mem_busy));

    // Data Memory
    single_port_ram #(.ADDR_SIZE(8), .BYTE_SIZE(8), .DATA_SIZE(64), .BUSY_TIME(12)) Data_Memory (.clk(clock), .address(data_address[7:0]), .write_data(write_data), 
                .output_enable(1'b1), .chip_select(data_mem_enable), .byte_write_enable(data_mem_byte_write_enable), .read_data(read_data), .busy(data_mem_busy));    

   // Componentes auxiliares para a verificação
    ImmediateExtender extensor_imediato (.immediate(immediate), .instruction(instruction));
    register_file #(.size(64), .N(5)) banco_de_registradores (.clock(clock), .reset(reset), .write_enable(write_register_enable), .read_address1(instruction[19:15] & {5{(~(instruction[4] & instruction[2]))}}),
                                .read_address2(instruction[24:20]), .write_address(instruction[11:7]), .write_data(reg_data), .read_data1(A), .read_data2(B));

    // geração do read_data_extended
    assign read_data_extend[7:0]   = read_data[7:0];
    assign read_data_extend[15:8]  = (read_data_src[1] | read_data_src[0]) ? read_data[15:8] : ({8{read_data[7] & read_data_src[2]}});
    assign read_data_extend[31:16] = read_data_src[1] ? read_data[31:16] : (read_data_src[0]) ? ({16{read_data[15] & read_data_src[2]}}) : ({16{read_data[7] & read_data_src[2]}});
    assign read_data_extend[63:32] = read_data_src[1] ? (read_data_src[0] ? read_data[63:32] : {32{read_data[31] & read_data_src[2]}}) : (read_data_src[0] ? {32{read_data[15] & read_data_src[2]}} : {32{read_data[7] & read_data_src[2]}});
    
    // geração dos sinais da instrução
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // pc
    assign pc = instruction_address;

    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

     function [63:0] ULA_function(input [63:0] A, input [63:0] B, input [3:0] seletor);
            reg   [63:0] xorB;
            reg   [63:0] add_sub;
            reg   overflow;
            reg   carry_out;
            reg   negative;
        begin
            // Funções da ULA
            case (seletor)
                4'b0000:
                    ULA_function = $signed(A) + $signed(B);
                4'b0001:
                    ULA_function = A << (B[5:0]);
                4'b0010: begin
                    xorB     = B ^ 64'sb11;
                    add_sub  = xorB + A + 64'b01;
                    negative = add_sub[63];
                    overflow = (~(A[63] ^ B[63])) & (A[63] ^ add_sub[63]);
                    ULA_function = negative ^ overflow;
                end
                4'b0011: begin
                    xorB                  = B ^ 64'sb11;
                    {carry_out, add_sub}  = xorB + A + 64'b01;
                    ULA_function          = ~ carry_out;
                end
                4'b0100:
                    ULA_function = A ^ B;
                4'b0101:
                    ULA_function = A >> (B[5:0]);
                4'b0110:
                    ULA_function = A | B;
                4'b0111:
                    ULA_function = A & B;
                4'b1000:
                    ULA_function = $signed(A) - $signed(B);
                4'b1101:
                    ULA_function = $signed(A) >>> (B[5:0]);
                default: begin
                    $display("ULA_function error: opcode = %b", opcode);
                    $stop;
                end
            endcase
        end
    endfunction

    // flags da ULA -> B-type
    assign xorB                  = B ^ 64'sb11;
    assign {carry_out_, add_sub} = A + xorB + 64'b01; 
    assign zero_                 = ~(|add_sub);
    assign negative_             = add_sub[63];
    assign overflow_             = (~(A[63] ^ B[63])) & (A[63] ^ add_sub[63]);

    // testar o DUT
    initial begin : Testbench
        $display("SOT!");
        write_register_enable = 1'b0;
        // Idle
        #2;
        reset = 1'b1;
        #6;
        reset = 1'b0;
        #6;
        for(i = 0; i < program_size; i = i + 1) begin
            $display("Test: %d", i);
            // Fetch
            write_register_enable = 1'b0;
            instruction_mem_enable = 1'b1;
            #18;
            instruction_mem_enable = 1'b0;
            // Decode -> Nada a ser testado
            // Execute -> Teste
            case (opcode)
                // Store(S*) e Load(L*)
                7'b0100011, 7'b0000011:
                    #0.5;
                    if(data_address !== A + immediate) begin
                        $display("Error Load/Store: data_address = %b, A = %b, immediate = %b, opcode = %b", data_address, A, immediate, opcode);
                        $stop;
                    end
                    if(opcode[5] === 1'b1 && write_data !== B) begin
                        $display("Error Store: write_data = %b, B = %b", write_data, B);
                        $stop;
                    end
                    #17.5
                    if(opcode[5] === 1'b0 && db_reg_data !== read_data_extend) begin
                        $display("Error Load: db_reg_data = %b, read_data_extend = %b", db_reg_data, read_data_extend);
                        $stop;
                    end
                    #6;
                // Branch(B*)
                7'b1100011:
                    if(funct3[2:1] === 2'b00)
                        pc_src = ~(zero ^ funct3[0]);
                    else if(funct3[2:1] === 2'b10)
                        pc_src = ~(negative ^ overflow ^ funct3[0]);
                    else if(funct3[2:1] === 2'b11)
                        pc_src = carry_out ^ funct3[0];
                    else
                        $display("Error B-type: Invalid funct3! Funct3 : %b", funct3);
                    pc_4                  = pc + 4;
                    pc_imm                = pc + immediate;
                    write_register_enable = 1'b0;
                    #0.5;
                    if(overflow !== overflow_ || carry_out !== carry_out_ || negative !== negative_ || zero !== zero_) begin
                        $display("Error B-type flags: overflow = %b, carry_out = %b, negative = %b, zero = %b, funct3 = %b", overflow, carry_out, negative, zero, funct3);
                        $stop;
                    end
                    #2.5;
                    if((pc_src === 1 && pc_imm !== instruction_address) || (pc_src === 0 && pc_4 !== instruction_address)) begin
                        $display("Error B-type PC: pc_src = %b, pc_imm = %b, pc_4 = %b, pc = %b", pc_src, pc_imm, pc_4, instruction_address);
                        $stop;
                    end
                    #3;
                // LUI e AUIPC
                7'b0110111, 7'b0010111:
                    write_register_enable = 1'b1;
                    if(opcode[5] === 1)
                        reg_data = immediate;
                    else
                        reg_data = instruction_address + immediate;
                    #0.5;
                    if(reg_data !== db_reg_data) begin
                        $display("Error AUIPC/LUI: reg_data = %b, db_reg_data = %b, opcode = %b", reg_data, db_reg_data, opcode);
                        $stop;
                    end
                    #5.5;
                // JAL e JALR
                7'b1101111, 7'b1100111:
                    write_register_enable = 1'b1;
                    if(opcode[3] === 1'b1)
                        pc_imm    = instruction_address + immediate;
                    else
                        pc_imm    = (A + immediate) << 1;
                    reg_data = pc + 4;
                    #0.5;
                    if(db_reg_data !== reg_data) begin
                        $display("Error JAL/JALR: reg_data = %b, reg_data = %b, opcode = %b", db_reg_data, reg_data, opcode);
                        $stop;
                    end
                    #2.5;
                    if(pc_imm !== instruction_address) begin
                        $display("Error JAL/JALR: pc_imm = %b, instruction_address = %b", pc_imm, instruction_address);
                        $stop;    
                    end
                    #3;
                // ULA R/I-type
                7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011: begin
                    write_register_enable = 1'b1;
                    if(opcode[5] === 1'b1)
                        reg_data = ULA_function(A, B, {funct7[5], funct3});
                    else if(funct3 === 3'b101)
                        reg_data = ULA_function(A, immediate, {funct7[5], funct3});
                    else
                        reg_data = ULA_function(A, immediate, {funct7[5], funct3});
                    if(opcode[3] === 1'b1)
                        reg_data = {{32{reg_data[31]}},reg_data[31:0]};
                    #0.5;
                    if(reg_data !== db_reg_data) begin
                        $display("Error ULA R/I-type: reg_data = %b, db_reg_data = %b, funct7 = %b, funct3 = %b", reg_data, db_reg_data, funct7, funct3);
                        $stop;
                    end
                    #5.5;
                end
                default: begin
                    $display("Error opcode case: opcode = %b", opcode);
                    #6;
                end
            endcase
        end
    end
endmodule