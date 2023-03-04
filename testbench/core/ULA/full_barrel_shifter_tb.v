//! @file   full_barrel_shifter_tb.v
//! @brief  Testbench para o Barrel Shifter completo e unificado (shift lógico para esquerda e lógico e aritmético para a direita)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-01
//

module full_barrel_shifter_tb;

    parameter QNTD_TESTES = 96;


    // sinais do DUT
    reg [31:0] in_data;
    reg [4:0] shamt;
    reg left_or_right_shift;
    reg arithmetic_right_shift;
    wire [31:0] out_data;

    // Instanciação do DUT
    full_barrel_shifter
    #(
        .XLEN(32)
    )
    DUT
    (
        .in_data(in_data),
        .shamt(shamt),
        .left_or_right_shift(left_or_right_shift),
        .arithmetic_right_shift(arithmetic_right_shift),
        .out_data(out_data)
    );

    // tabela com sinais de entrada e saídas esperadas
    reg [70:0] casos_de_teste [QNTD_TESTES-1:0];

    // campos das linhas da tabela
    // e sinais correspondentes
    `define IN_DATA [31:0]
    `define SHAMT [36:32]
    `define L_OR_R [37]
    `define A_OR_L [38]
    `define OUTPUT [70:39]

    integer i;
    initial begin
        $readmemb("./MIFs/core/ULA/casos_de_teste.mif", casos_de_teste);
        {in_data, shamt, left_or_right_shift, arithmetic_right_shift}=0;

        $display("SOT!");
        for(i=0; i<QNTD_TESTES; i=i+1) begin
            in_data = casos_de_teste[i] `IN_DATA;
            shamt = casos_de_teste[i] `SHAMT;
            left_or_right_shift = casos_de_teste[i] `L_OR_R;
            arithmetic_right_shift = casos_de_teste[i] `A_OR_L;
            #10;
            if(out_data != casos_de_teste[i] `OUTPUT)
                $display("Caso %d: ERRO --- recebeu: %b esperava: %b", i, out_data, casos_de_teste[i] `OUTPUT);
            else
                $display("Caso %d: ACERTO", i);
        end

    end

endmodule
