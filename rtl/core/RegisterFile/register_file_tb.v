
`timescale 1ns / 1ns

module register_file_tb();
    // portas do DUT
    reg        clock;
    reg        reset;
    reg        write_enable;
    reg  [2:0] read_address1;
    reg  [2:0] read_address2;
    reg  [2:0] write_address;
    reg  [7:0] write_data;
    wire [7:0] read_data1;
    wire [7:0] read_data2;
    // sinais intermediários para realizar o teste
    integer i;

    // instanciação do DUT
    register_file #(.N(3), .size(8)) DUT (.clock(clock), .reset(reset), .write_enable(write_enable), 
                    .read_address1(read_address1), .read_address2(read_address2), .write_address(write_address),
                    .write_data(write_data), .read_data1(read_data1), .read_data2(read_data2));

    // geração de clock
    always begin
        clock = 0; 
        #3;
        clock = 1;
        #3;
    end

    // initial para testar o DUT
    initial begin
        $display("SOT!");
        reset = 1; // reset inicial
        #2;
        $display("Test: reset_mode"); // testar se todas os registradores foram resetados
        reset = 0;
        write_enable = 0; // apenas leitura
        for(i = 1; i < 8; i = i + 1) begin
            read_address1 = i;
            read_address2 = i - 1;
            #2;
            if(read_data1 !== 0 && read_data2 !== 0)
                $display("Error: read_address1 = %b, read_address2 = %b, read_data1 = %b, read_data2 = %b",
                        read_address1, read_address2, read_data1, read_data2);
            #4;
        end
        #6;
        $display("Test: write_mode"); // escrever em todos os registradores
        write_enable = 1; // escrita
        for(i = 0; i < 8; i = i + 1) begin
            write_address = i;
            write_data    = i + 1;
            #6;
        end
        write_enable = 0;
        #6;
        $display("Test: read_mode"); // ler todos os registradores
        for(i = 0; i < 7; i = i + 1) begin
            read_address1 = i;
            read_address2 = i + 1;
            #2;
            if(read_data1 !== i + 1 && read_data2 !== i + 2)
                $display("Error: read_address1 = %b, read_address2 = %b, read_data1 = %b, read_data2 = %b",
                        read_address1, read_address2, read_data1, read_data2);
            #4;
        end
        $display("EOT!");
    end


endmodule
