
`timescale 1ns / 100 ps

module barrel_shifter_r_tb();

    // portas do DUT
    reg  [7:0] A;
    reg  [2:0] shamt;
    reg  arithmetic;
    wire [7:0] Y;
    // auxiliares
    wire signed [7:0] B[7:0]; 
    // variáveis de iteração
    genvar  i;
    integer j;

    // inicializando B
    generate
        for(i = 0; i < 8; i = i + 1)
            assign B[i] = 40*i;
    endgenerate

    // instanciando o DUT
    barrel_shifter_r #(.N(3)) DUT(.A(A), .shamt(shamt), .Y(Y), .arithmetic(arithmetic));

    // initial para testar o DUT
    initial begin
        $display("SOT!");
        $display("0!");
        arithmetic = 1'b0;  // SRL
        for(j = 0; j < 8; j = j + 1) begin
            A = B[j];
            shamt = j;
            #1;
            if(Y !== (B[j] >> j))
                $display("Error: B[%d] = %b, Y = %b", j, B[j], Y);
            #1;
        end 
        arithmetic = 1'b1; // SRA
        $display("1!");
        for(j = 0; j < 8; j = j + 1) begin
            A = B[j];
            shamt = j;
            #1;
            if(Y !== (B[j][7:0] >>> j)) // fazer signed aaaaaaa
                $display("Error: B[%d] = %b, Y = %b", j, B[j], Y);
            #1;
        end 
        $display("EOT!");
    end

endmodule