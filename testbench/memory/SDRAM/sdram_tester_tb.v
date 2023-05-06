//
//! @file   sdram_tester_tb.v
//! @brief  Testbench do Testador do Controlador da SDRAM
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//

`timescale 1 ns/ 100 ps

module sdram_tester_tb();

    // Sinais do DUT
        // Processador
    reg         clock;
    reg         reset_n;
    reg         ativar;
    reg  [9:0]  chaves;
    wire [6:0]  lsb;
    wire [6:0]  msb;
    wire        sdram_busy;
        // SDRAM
    wire        dram_clk;
    wire        dram_cke;
    wire [12:0] dram_addr;
    wire [1:0]  dram_ba;
    wire        dram_cs_n;
    wire        dram_ras_n;
    wire        dram_cas_n;
    wire        dram_we_n;
    wire        dram_ldqm;
    wire        dram_udqm;
    wire [15:0] dram_dq;
    reg  [15:0] memory [127:0]; // memória simulada
    wire [3:0]  command = {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n};
    // sinais intermediários
        // Configuração
    reg  [25:0] address;    // endereço usado na operação
    reg  [1:0]  rd_wr_size; // tamanho da operação
    reg  [63:0] op_data;    // dado da operação
        // Controlar leitura na memória
    reg  rd_en;
    reg  ldqm;
    reg  udqm;
    reg  [6:0] rd_addr; 
        // Dado da interface humana
    reg  [63:0] rd_data;  // dado lido na memória
        // Saída dos displays
    wire [6:0] rd_lsb;
    wire [6:0] rd_msb;
    // variáveis de iteração
    integer i, j, k;

    // DUT
    sdram_tester DUT (.clock(clock), .reset_n(reset_n), .ativar(ativar), .chaves(chaves), .lsb(lsb), 
        .msb(msb), .sdram_busy(sdram_busy), .dram_clk(dram_clk), .dram_cke(dram_cke), .dram_addr(dram_addr),
        .dram_ba(dram_ba), .dram_cs_n(dram_cs_n), .dram_ras_n(dram_ras_n), .dram_cas_n(dram_cas_n), 
        .dram_we_n(dram_we_n), .dram_ldqm(dram_ldqm), .dram_udqm(dram_udqm), .dram_dq(dram_dq));

    // displays auxiliares
    hexa7seg display_lsb (.hexa(rd_data[3:0]), .sseg(rd_lsb));
    hexa7seg display_msb (.hexa(rd_data[7:4]), .sseg(rd_msb));
    
    
    // geração do clock
    always begin
        clock = 1'b0;
        #3;
        clock = 1'b1;
        #3;
    end

    assign dram_dq[7:0]  = rd_en & ~ldqm ? memory[rd_addr][7:0]  : {{8'bz}}; // tri-state
    assign dram_dq[15:8] = rd_en & ~udqm ? memory[rd_addr][15:8] : {{8'bz}}; // tri-state

    // leitura
    always @(posedge clock) begin
        rd_en   <= 0;      // alta impedância
        ldqm    <= 1'b1;
        udqm    <= 1'b1;
        rd_addr <= 0;
        if(command == 4'b0101) begin // READ
            ldqm    <= dram_ldqm;
            udqm    <= dram_udqm;
            rd_addr <= dram_addr[6:0];
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            wait (clock == 1'b0);
            wait (clock == 1'b1); // CAS latency = 3
            rd_en <= 1;
        end
    end

    // escrita
    always @(posedge clock) begin
        if(command == 4'b0100) begin // WRITE
            if(dram_ldqm == 1'b0)
                memory[dram_addr[6:0]][7:0]  <= dram_dq[7:0];
            if(dram_udqm == 1'b0)
                memory[dram_addr[6:0]][15:8] <= dram_dq[15:8];
        end
    end

    task ativando;
        begin
            ativar = 1'b0; // ativo baixo
            wait (clock == 1'b1);
            wait (clock == 1'b0);
            wait (clock == 1'b1);
            wait (clock == 1'b0);
            ativar = 1'b1;
            wait (clock == 1'b1);
            wait (clock == 1'b0);
        end
    endtask

    // testbench
    initial begin: testbench
        reset_n = 1; // ativo baixo
        ativar  = 1; // ativo baixo
        chaves  = 0;
        rd_en   = 0;
        $display("SOT!");
        #2;
        reset_n = 0; // reset por 2 ciclos
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        wait (clock == 1'b1);
        wait (clock == 1'b0);
        #1;
        reset_n = 1'b1;     
        #600; // Esperar inicialização acabar
        for(i = 0; i < 8; i = i + 1) begin // 8 pares (rd_wr_size, address[0]) possíveis
            #0.1; // Esperar um pouco
            $display("Test: %d", i);
            // Selecionando os parâmetros da operação
            address[0]    = (i%2);      // oscilar entre endereços pares e ímpares
            rd_wr_size    = i/2;        // testas todos os 4 tamanhos
            address[25:1] = $random;    // resto do endereço: aleatório
            op_data       = {$random, $random};    // escrever dado qualquer
            for(j = 1; j > -1; j = j - 1) begin // 1: escrita, 0 : leitura
                // Idle
                ativando;
                // Address 1
                chaves = address[9:0];
                ativando;
                // Address 2
                chaves = address[19:10];
                ativando;
                // Address 3
                chaves = {4'b0, address[25:20]};
                ativando;
                // Op Size
                chaves = {8'b0, rd_wr_size};
                ativando;
                // Op Mode
                chaves = {9'b0, (j%2)};
                ativando;
                if(j == 1) begin // Escrita
                    // Pre Write
                    // Loop para gerar o write_data 
                    for(k = 2**rd_wr_size - 1; k > -1; k = k - 1) begin
                        chaves  = {2'b0, op_data[8*k+:8]};
                        ativando;
                    end
                    // Write Wait
                    chaves = 0;
                    wait (sdram_busy == 1'b1);
                    // Write Mode
                    wait (sdram_busy == 1'b0);
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                end
                else begin // Leitura
                    // Read Start
                    chaves = 0;
                    wait (sdram_busy == 1'b1);
                    // Read Wait
                    wait (sdram_busy == 1'b0);
                    wait (clock == 1'b0);
                    wait (clock == 1'b1);
                    // Read Mode
                    rd_data = op_data;
                    // Loop para observar o read_data
                    for(k = 0; k < 2**rd_wr_size; k = k + 1) begin
                        #0.1;
                        if(lsb !== rd_lsb || msb !== rd_msb) begin
                            $display("Error read: lsb = %h, rd_lsb = %h, msb = %h, rd_msb = %h", lsb, rd_lsb, msb, rd_msb);
                            $stop;
                        end
                        #0.1;
                        rd_data = rd_data >> 8;
                        ativando;
                    end
                end
            end 
        end
        $display("EOT!");
        $stop;
    end
endmodule