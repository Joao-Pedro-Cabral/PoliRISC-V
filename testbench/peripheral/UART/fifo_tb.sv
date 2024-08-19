
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

    CHK_INIT: assert((|(DUT.rd_reg) | (DUT.wr_reg) | (DUT.watermark_reg))
                        | (~empty) | (full)) $display("SOT");

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
      CHk_RD_POINTER: assert(rd_reg_mem === DUT.rd_reg);
      CHK_RD_DATA: assert(local_fifo_memory[rd_reg_mem] === rd_data);

      // Compara ponteiro e dado escrito
      CHK_WR_POINTER: assert(wr_reg_mem === DUT.wr_reg);
      CHK_WR_DATA: assert(local_fifo_memory[wr_reg_mem-1] === DUT.fifo_memory[DUT.wr_reg-1]);

      // Teste do watermark
      CHK_WATERMARK: assert(watermark_reg_mem === DUT.watermark_reg);

      // Flags testadas ao fim, com valores locais atualizados
      CHK_FLAG_EMPTY: assert(local_empty === empty);
      CHK_FLAG_FULL: assert(local_full === full);
      CHK_FLAG_LESS: assert(local_less === less_than_watermark);
      CHK_FLAG_GREATER: assert(local_greater === greater_than_watermark);
    end
    $display("EOT!");
    $stop;
  end

endmodule
