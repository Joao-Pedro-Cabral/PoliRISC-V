
module sdram_controller_tb;

  import macros_pkg::*;

  // Sinais do DUT
  // Processador
  reg clock;
  reg reset;
  reg rd_enable;  // 1: habilita a leitura
  reg wr_enable;  // 1: habilita a escrita
  reg [25:0] address;  // endereço da operação
  reg [1:0] rd_wr_size;  // 00: Byte; 01: Half Word; 10: Word; 11: Double Word
  reg [63:0] write_data;  // dado a ser escrito na SDRAM
  wire busy;
  wire [63:0] read_data;  // dado lido da SDRAM
  // SDRAM
  wire dram_clk;
  wire dram_cke;
  wire [12:0] dram_addr;
  wire [1:0] dram_ba;
  wire dram_cs_n;
  wire dram_ras_n;
  wire dram_cas_n;
  wire dram_we_n;
  wire dram_ldqm;
  wire dram_udqm;
  wire [15:0] dram_dq;
  reg [15:0] memory[127:0];  // memória simulada
  wire [3:0] command = {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n};
  // sinais intermediários
  reg rd_en;
  reg [25:0] wr_addr;  // endereço usado na escrita
  reg [63:0] wr_data;  // dado escrito na memória
  reg ldqm;
  reg udqm;
  reg [6:0] rd_addr;
  // variáveis de iteração
  integer i;

  // DUT
  sdram_controller DUT (
      .clock(clock),
      .reset(reset),
      .rd_enable(rd_enable),
      .wr_enable(wr_enable),
      .address(address),
      .rd_wr_size(rd_wr_size),
      .write_data(write_data),
      .busy(busy),
      .read_data(read_data),
      .dram_clk(dram_clk),
      .dram_cke(dram_cke),
      .dram_addr(dram_addr),
      .dram_ba(dram_ba),
      .dram_cs_n(dram_cs_n),
      .dram_ras_n(dram_ras_n),
      .dram_cas_n(dram_cas_n),
      .dram_we_n(dram_we_n),
      .dram_ldqm(dram_ldqm),
      .dram_udqm(dram_udqm),
      .dram_dq(dram_dq)
  );

  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  // "Memória"
  assign dram_dq[7:0]  = rd_en & ~ldqm ? memory[rd_addr][7:0] : {{'bz}};  // tri-state
  assign dram_dq[15:8] = rd_en & ~udqm ? memory[rd_addr][15:8] : {{'bz}};  // tri-state

  // leitura
  always @(posedge dram_clk) begin
    rd_en   <= 0;  // alta impedância
    ldqm    <= 1'b1;
    udqm    <= 1'b1;
    rd_addr <= 0;
    if (command == 4'b0101) begin  // READ
      ldqm    <= dram_ldqm;
      udqm    <= dram_udqm;
      rd_addr <= dram_addr[6:0];
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);
      wait (dram_clk == 1'b0);
      wait (dram_clk == 1'b1);  // CAS latency = 3
      rd_en <= 1;
    end
  end

  // escrita
  always @(posedge dram_clk) begin
    if (command == 4'b0100) begin  // WRITE
      if (dram_ldqm == 1'b0) memory[dram_addr[6:0]][7:0] <= dram_dq[7:0];
      if (dram_udqm == 1'b0) memory[dram_addr[6:0]][15:8] <= dram_dq[15:8];
    end
  end

  initial begin : testbench
    // zerando os sinais inicialmente
    rd_enable  = 0;
    wr_enable  = 0;
    address    = 0;
    rd_wr_size = 0;
    write_data = 0;
    reset      = 0;
    $display("SOT!");
    #2;
    reset = 1'b1;  // reset por 2 ciclos
    wait (clock == 1'b1);
    wait (clock == 1'b0);
    wait (clock == 1'b1);
    wait (clock == 1'b0);
    #1;
    reset = 1'b0;
    #600;  // Esperar inicialização acabar
    for (i = 0; i < 8; i = i + 1) begin
      $display("Test: %d", i);
      // Escrita
      address[0]    = (i % 2);  // oscilar entre endereços pares e ímpares
      rd_wr_size    = i / 2;  // testas todos os 4 tamanhos
      address[25:1] = $urandom;  // resto do endereço: aleatório
      wr_addr       = address;  // guardando endereço de escrita
      write_data    = {$urandom, $urandom};  // escrever dado qualquer
      wr_data       = write_data;  // guardando dado escrito
      wr_enable     = 1'b1;  // habilitar escrita
      wait (busy == 1'b1);
      wait (busy == 1'b0);  // Esperar fim da operação
      address    = 0;  // zerando sinais de controle
      rd_wr_size = 0;
      wr_enable  = 0;
      write_data = 0;
      wait (clock == 1'b0);  // Borda de descida: nova operação
      // Leitura(mesmo endereço da escrita)
      address    = wr_addr;
      rd_wr_size = i / 2;
      rd_enable  = 1'b1;
      wait (busy == 1'b1);
      wait (busy == 1'b0);  // Esperar fim da operação
      wait (clock == 1'b0);
      // case para determinar qual deve ser a saída devido as máscaras
      unique case (rd_wr_size)
        2'b00:
        if (read_data !== {56'b0, wr_data[7:0]}) begin  // byte
          $display("Error: read_data = %x, wr_data = %x, rd_wr_size = %b, address[0] = %b",
                   read_data, wr_data, rd_wr_size, address[0]);
          $stop;
        end
        2'b01:
        if (read_data !== {48'b0, wr_data[15:0]}) begin  // half word
          $display("Error: read_data = %x, wr_data = %x, rd_wr_size = %b, address[0] = %b",
                   read_data, wr_data, rd_wr_size, address[0]);
          $stop;
        end
        2'b10:
        if (read_data !== {32'b0, wr_data[31:0]}) begin  // word
          $display("Error: read_data = %x, wr_data = %x, rd_wr_size = %b, address[0] = %b",
                   read_data, wr_data, rd_wr_size, address[0]);
          $stop;
        end
        2'b11:
        if (read_data !== wr_data) begin  // double word
          $display("Error: read_data = %x, wr_data = %x, rd_wr_size = %b, address[0] = %b",
                   read_data, wr_data, rd_wr_size, address[0]);
          $stop;
        end
      endcase
      address    = 0;  // zerando sinais de controle
      rd_wr_size = 0;
      rd_enable  = 0;
      wait (clock == 1'b0);  // Borda de descida: nova operação
    end
    $display("EOT!");
    $stop;
  end
endmodule
