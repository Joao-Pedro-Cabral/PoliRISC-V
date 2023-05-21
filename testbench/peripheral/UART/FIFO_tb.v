//
//! @file   FIFO.v
//! @brief  Testbench da FIFO (Fila)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br) e Gor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-20
//

module FIFO_tb ();

  localparam integer DataSize = 32;
  localparam integer Depth = 8;
  localparam integer AmntOfTests = 1000;

  // Sinais do DUT
  reg clock;
  reg reset;
  reg wr_en;
  reg rd_en;
  reg [$clog2(Depth)-1:0] watermark_level;
  reg [DataSize-1:0] wr_data;
  wire [DataSize-1:0] rd_data;
  wire empty;
  wire full;

  // Sinais intermediários
  reg [DatSize-1:0] wr_reg_mem;
  reg [DataSize-1:0] rd_reg_mem;
  reg [DataSize-1:0] watermark_reg_mem;
  wire local_empty;
  wire local_full;

  // FIFO local
  reg [DataSize-1:0] local_fifo_memory[Depth-1:0];

  FIFO #(
      .DATA_SIZE(DataSize),
      .DEPTH(Depth)
  ) DUT (
      .clock(clock),
      .reset(reset),
      .wr_en(wr_en),
      .rd_en(rd_en),
      .watermark_level(watermark_level),
      .wr_data(wr_data),
      .rd_data(rd_data),
      .empty(empty),
      .full(full)
  );

  always #10 clock = ~clock;
  assign full_mem = ~(|(watermark_reg_mem ^ watermark_level));
  assign local_empty = (watermark_reg_mem == 0);

  integer i;
  initial begin
    {clock, wr_en, rd_en, wr_data, rd_reg_mem, wr_reg_mem, watermark_reg_mem} = 0;


    // Inicializando a FIFO
    watermark_level = $urandom;
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;

    if ((|(DUT.rd_reg) | (DUT.wr_reg) | (DUT.watermark_reg)) | (~empty) | (full)) $display("SOT!");
    else $fatal("Inicialização falhou");


    @(negedge clock);
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      wr_en   = $urandom;
      rd_en   = $urandom;
      wr_data = $urandom;
      @(negedge clock);

      // leitura de FIFO não vazia
      if (~((rd_en & empty) | (~rd_en))) begin
        rd_reg_mem = rd_reg_mem + 1;  // atualiza ponteiro
        watermark_reg_mem = watermark_reg_mem - 1;
      end

      // Compara ponteiro e dado lido
      if (rd_reg_mem !== DUT.rd_reg || local_fifo_memory[rd_reg_mem] !== rd_data) begin
        $display("Falha na leitura da FIFO (teste: %d) DUT.rd_reg = 0x%h, \
                 rd_reg_mem = 0x%h, rd_data = 0x%h, local_fifo = 0x%h,\
                 fifo = 0x%h, full = 0b%d, empty = 0b%d", i, DUT.rd_reg,
                 rd_reg_mem, rd_data, local_fifo_memory[rd_reg_mem], full, empty);
      end

      // escrita de FIFO não cheia
      if (~((wr_en & full) | (~wr_en))) begin
        local_fifo_memory[wr_reg_mem] = wr_data;  // Primeiro escreve
        wr_reg_mem = wr_reg_mem + 1;  // Depois incrementa
        watermark_reg_mem = watermark_reg_mem + 1;
      end

      // Compara ponteiro e dado escrito
      if (wr_reg_mem !== DUT.wr_reg
          || local_fifo_memory[wr_reg_mem-1] !== DUT.fifo_memory[DUT.wr_reg-1]) begin
        $display("Falha na escrita da FIFO (teste: %d) DUT.wr_reg = 0x%h,\
                 wr_reg_mem = 0x%h, wr_data = 0x%h, local_fifo = 0x%h,\
                 fifo = 0x%h, full = 0b%d, empty = 0b%d", i, DUT.wr_reg,
                 wr_reg_mem, wr_data, local_fifo_memory[wr_reg_mem-1],
                 DUT.fifo_memory[DUT.wr_reg-1], full, empty);
      end

      // Teste do watermark
      if (watermark_reg_mem != DUT.watermark_reg) begin
        $display("Falha no watermark (teste %d) DUT.watermark_reg = 0x%h,\
                 watermark_reg_mem = 0x%h", i, DUT.watermark_reg,
                 watermark_reg_mem);
      end

      // Flags testadas ao fim, com valores locais atualizados
      if (local_empty !== empty || local_full !== full) begin
        $display("Erro nas flags (teste %d) full = 0b%d, empty = 0b%d,\
                  local_full = 0b%d, local_empty = 0b%d", i, full, empty,
                 local_full, local_empty);
      end
    end
    $display("EOT!");
    $stop;
  end

endmodule
