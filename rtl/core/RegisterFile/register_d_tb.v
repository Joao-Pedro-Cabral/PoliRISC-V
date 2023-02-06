
`timescale 1ns / 100ps

module register_d_tb();
    // Fios do DUT
    reg  clock, reset, enable;
    reg  [3:0] D;
    wire [3:0] Q;
    wire [9:0] tests[7:0]; // array de testes: {Q, D, enable, reset}
    
    integer i; // variável de iteração

    // instanciação do DUT
    register_d #(.N(4), .reset_value(0)) DUT (.clock(clock), .reset(reset), .enable(enable), .D(D), .Q(Q));

    // inicialização do array
    assign tests[0] = 1'b1;
    assign tests[1] = 0;
    assign tests[2] = 6'b110100;
    assign tests[3] = 9'sb101110110;
    assign tests[4] = 6'b011011;
    assign tests[5] = 7'b1000110;
    assign tests[6] = 7'b1111100;
    assign tests[7] = 2'sb10;

    // geração de clock
    always begin
        clock = 0;
        #5;
        clock = 1;
        #5;
    end

    // initial para testar o DUT
    initial begin
        #4;
        $display("SOT!");
        for(i = 0; i < 8; i = i + 1) begin
            reset  = tests[i][0];
            enable = tests[i][1];
            D      = tests[i][5:2];
            #5;
            if(Q !== tests[i][9:6])
                $display("Error: D[%d] = %b, Q = %b", i, D, Q);
            #5;
        end
        $display("EOT!");
    end


endmodule