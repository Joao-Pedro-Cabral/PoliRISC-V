
module fifo_tb ();

  import macros_pkg::*;

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
  wire less_than_watermark;
  wire greater_than_watermark;
  wire empty;
  wire full;

  // Sinais intermediários
  reg [$clog2(Depth)-1:0] wr_reg_mem;
  reg [$clog2(Depth)-1:0] rd_reg_mem;
  reg [$clog2(Depth)-1:0] watermark_reg_mem;
  wire local_less;
  wire local_greater;
  wire local_empty;
  wire local_full;

  // fifo local
  reg [DataSize-1:0] local_fifo_memory[Depth-1:0];

  fifo #(
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
      .less_than_watermark(less_than_watermark),
      .greater_than_watermark(greater_than_watermark),
      .empty(empty),
      .full(full),
      .watermark_reg_db()
  );

  always #10 clock = ~clock;
  assign local_less = (watermark_reg_mem < watermark_level);
  assign local_greater = (watermark_reg_mem > watermark_level);
  assign local_full = (watermark_reg_mem == 7);
  assign local_empty = (watermark_reg_mem == 0);

  integer i;
  initial begin
    {clock, wr_en, rd_en, wr_data, wr_reg_mem, watermark_reg_mem} = 0;
    rd_reg_mem = -1'b1;

    // Inicializando a fifo
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

      // leitura de fifo não vazia
      if (~((rd_en & empty) | ~rd_en)) begin
        rd_reg_mem = rd_reg_mem + 1;  // atualiza ponteiro
        watermark_reg_mem = watermark_reg_mem - 1;
      end

      // escrita de fifo não cheia
      if (~((wr_en & full) | ~wr_en)) begin
        local_fifo_memory[wr_reg_mem] = wr_data;  // Primeiro escreve
        wr_reg_mem = wr_reg_mem + 1;  // Depois incrementa
        watermark_reg_mem = watermark_reg_mem + 1;
      end

      @(negedge clock);

      // Compara ponteiro e dado lido
      if (rd_reg_mem !== DUT.rd_reg || local_fifo_memory[rd_reg_mem] !== rd_data) begin
        $display("Falha na leitura da fifo (teste: %d) DUT.rd_reg = 0x%h, \
                 rd_reg_mem = 0x%h, rd_data = 0x%h, local_fifo = 0x%h,\
                 fifo = 0x%h, full = 0b%d, empty = 0b%d", i, DUT.rd_reg,
                 rd_reg_mem, rd_data, local_fifo_memory[rd_reg_mem], DUT.fifo_memory[DUT.rd_reg],
                 full, empty);
        $stop;
      end

      // Compara ponteiro e dado escrito
      if (wr_reg_mem !== DUT.wr_reg
          || local_fifo_memory[wr_reg_mem-1] !== DUT.fifo_memory[DUT.wr_reg-1]) begin
        $display("Falha na escrita da fifo (teste: %d) DUT.wr_reg = 0x%h,\
                 wr_reg_mem = 0x%h, wr_data = 0x%h, local_fifo = 0x%h,\
                 fifo = 0x%h, full = 0b%d, empty = 0b%d", i, DUT.wr_reg,
                 wr_reg_mem, wr_data, local_fifo_memory[wr_reg_mem-1],
                 DUT.fifo_memory[DUT.wr_reg-1], full, empty);
        $stop;
      end

      // Teste do watermark
      if (watermark_reg_mem != DUT.watermark_reg) begin
        $display("Falha no watermark (teste %d) DUT.watermark_reg = 0x%h,\
                 watermark_reg_mem = 0x%h", i, DUT.watermark_reg,
                 watermark_reg_mem);
        $stop;
      end

      // Flags testadas ao fim, com valores locais atualizados
      if (local_empty !== empty || local_full !== full || local_less !== less_than_watermark
      || local_greater !== greater_than_watermark) begin
        $display(
            "Erro nas flags (teste %d) less = 0b%d, greater = 0b%d, full = 0b%d, empty = 0b%d,\
                local_less = 0b%d, local_greater = 0b%d, local_full = 0b%d, local_empty = 0b%d", i,
            less_than_watermark, greater_than_watermark, full, empty, local_less, local_greater,
            local_full, local_empty);
        $stop;
      end
    end
    $display("EOT!");
    $stop;
  end

endmodule
