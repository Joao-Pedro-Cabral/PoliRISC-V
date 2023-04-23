//
//! @file   ImmediateExtender_tb.v
//! @brief  Testbench Extensor de Imediato
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-02-20
//

`timescale 1 ns / 100 ps

module ImmediateExtender_tb();
    // portas do DUT
    reg  [31:0] instruction;
    wire [63:0] immediate;
    // possíveis imediatos gerados
    wire [63:0] I_type = {{53{$signed(instruction[31])}}, instruction[30:20]};
    wire [63:0] S_type = {{53{$signed(instruction[31])}}, instruction[30:25], instruction[11:7]};
    wire [63:0] B_type = {{52{$signed(instruction[31])}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [63:0] U_type = {{33{$signed(instruction[31])}}, instruction[30:12], 12'b0};
    wire [63:0] J_type = {{44{$signed(instruction[31])}}, instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], 1'b0};
    // possíveis opcodes de instrução
    wire [6:0] instruction_opcode [8:0];
    // variáveis de iteração
    integer i, j;

    // inicializando os opcodes
    assign instruction_opcode[0] = 7'b1101111;
    assign instruction_opcode[1] = 7'b0010111;
    assign instruction_opcode[2] = 7'b0110111;
    assign instruction_opcode[3] = 7'b1100011;
    assign instruction_opcode[4] = 7'b0100011;
    assign instruction_opcode[5] = 7'b0000011;
    assign instruction_opcode[6] = 7'b1100111;
    assign instruction_opcode[7] = 7'b0010011;
    assign instruction_opcode[8] = 7'b0011011;

    // instanciando o DUT
    ImmediateExtender DUT (.instruction(instruction), .immediate(immediate));

    // initial para testar o DUT
    initial begin
        #2;
        $display("SOT!");
        for(i = 0; i < 1000; i = i + 1) begin
            $display("Opcode: %d", i);
            for(j = 0; j < 10; j = j + 1) begin
                $display("Teste: %d", j);
                instruction[31:7] = $random;
                instruction[6:0]  = instruction_opcode[(i%9)];
                #1;
                case((i%9))
                    0:       if(immediate !== J_type) begin
                        $display("Error: instruction %b, immediate: %b, J_type: %b", instruction, immediate, J_type);
                        $stop;
                        end 
                    1, 2:    if(immediate !== U_type) begin
                        $display("Error: instruction %b, immediate: %b, U_type: %b", instruction, immediate, U_type);
                        $stop;
                        end 
                    3:       if(immediate !== B_type) begin
                        $display("Error: instruction %b, immediate: %b, B_type: %b", instruction, immediate, B_type);
                        $stop;
                        end 
                    4:    if(immediate !== S_type) begin
                        $display("Error: instruction %b, immediate: %b, S_type: %b", instruction, immediate, S_type);
                        $stop;
                        end 
                    5, 6, 7, 8: if(immediate !== I_type) begin
                        $display("Error: instruction %b, immediate: %b, I_type: %b", instruction, immediate, I_type);
                        $stop;
                        end 
                endcase
                #1;
            end
        end
    end

endmodule