//
//! @file   single_port_ram_tb.v
//! @brief  Testbench da ram de porta única com byte enable write
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-01
//

module single_port_ram_tb;

    reg  clk;
    reg  [31:0] address;
    wire [31:0] write_data;
    reg  [31:0] tb_data;
    reg  [31:0] tb_mem [3:0];
    reg  output_enable;
    reg  chip_select;
    reg  [3:0] byte_write_enable;
    wire [31:0] read_data;
    wire busy;


    single_port_ram
    #(
        .ADDR_SIZE(4),
        .BYTE_SIZE(8),
        .DATA_SIZE(32),
        .BUSY_TIME(3)
    )
    DUT
    (
        .clk(clk),
        .address(address),
        .write_data(write_data),
        .output_enable(output_enable),
        .chip_select(chip_select),
        .byte_write_enable(byte_write_enable),
        .read_data(read_data),
        .busy(busy)
    );

    always #10 clk = ~clk;
    assign write_data = tb_data;

    integer i;
    initial begin
        {clk, address, tb_data, output_enable, chip_select, byte_write_enable} = 0;

        // gerando valores aleatórios
        for(i = 0; i < 4; i = i + 1) begin
            tb_mem[i] = $random;
            $display("dado %d: 0x%h", i, tb_mem[i]);
        end

        // aciona memória
        chip_select = 1'b1;

        // escreve e testa leitura
        for(i = 0; i < 4; i = i + 1) begin
            address = 4*i;
            tb_data = tb_mem[i];
            chip_select = 1'b1;
            byte_write_enable = 4'b1111;
            @(negedge busy);
            byte_write_enable = 4'b0000;
            output_enable = 1'b1;
            @(negedge busy);
            if(read_data != tb_data) begin
                $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", read_data, tb_data);
            end
            else begin
                $display("teste %d correto: 0x%h", i, read_data);
            end
            output_enable = 1'b0;
        end

        // testa byte enables: limpa byte mais significativo
        tb_data = 0;
        for(i = 0; i < 4; i = i + 1) begin
            address = 4*i;
            byte_write_enable = 4'b1000;
            @(negedge busy);
            byte_write_enable = 4'b0000;
            output_enable = 1'b1;
            @(negedge busy);
            if(read_data != {8'b0, tb_mem[i][23:0]}) begin
                $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", read_data, {8'b0, tb_mem[i][23:0]});
            end
            else begin
                $display("teste %d correto: 0x%h", i+4, read_data);
            end
            output_enable = 1'b0;
        end

        // testa leitura e escrita desalinhada
        tb_data = 0;
        address = 4*3 + 2;
        byte_write_enable = 4'b1111;
        @(negedge busy);
        byte_write_enable = 4'b0000;
        output_enable = 1'b1;
        @(negedge busy);
        if(read_data != tb_data) begin
            $display("ERRO NA LEITURA: recebeu: 0x%h --- esperava: 0x%h", read_data, tb_mem[4*3 + 2]);
        end
        else begin
            $display("teste %d correto: 0x%h", 8, read_data);
        end
        output_enable = 1'b0;

        // desativa memória
        chip_select = 1'b0;
        $display("EOT!");
        $finish;
    end

endmodule
