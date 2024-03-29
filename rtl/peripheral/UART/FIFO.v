//
//! @file   FIFO.v
//! @brief  FIFO (Fila)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-20
//

`include "macros.vh"
`include "extensions.vh"

module FIFO #(
    parameter integer DATA_SIZE = 32,
    parameter integer DEPTH = 8
) (
    input wire clock,
    input wire reset,
    input wire wr_en,
    input wire rd_en,
    input wire [$clog2(DEPTH)-1:0] watermark_level,
    input wire [DATA_SIZE-1:0] wr_data,
`ifdef DEBUG
    output wire [$clog2(DEPTH)-1:0] watermark_reg_,
`endif
    output wire [DATA_SIZE-1:0] rd_data,
    output wire less_than_watermark,
    output wire greater_than_watermark,
    output wire empty,
    output wire full
);

  // Registradores de Operação
  wire [$clog2(DEPTH)-1:0] rd_reg;  // aponta para a posição da FIFO a ser lida
  wire [$clog2(DEPTH)-1:0] wr_reg;  // aponta para a posição da FIFO a ser escrita
  wire [$clog2(DEPTH)-1:0] watermark_reg;

  // FIFO
  reg [DATA_SIZE-1:0] fifo_memory[DEPTH-1:0];

  // Sinais intermediários
  wire _full;
  wire _empty;

  wire [$clog2(DEPTH)-1:0] cte_0 = 0;

  // Contadores
  // Leitura não é permitido quando estiver vazio
  sync_parallel_counter #(
      .size($clog2(DEPTH)),
      .init_value(-1'b1)
  ) rd_pointer (
      .clock(clock),
      .reset(reset),
      .load(1'b0),
      .load_value(cte_0),
      .inc_enable(rd_en & (~_empty)),
      .dec_enable(1'b0),
      .value(rd_reg)
  );
  // Escrita não é permitido quando estiver cheio
  sync_parallel_counter #(
      .size($clog2(DEPTH)),
      .init_value(0)
  ) wr_pointer (
      .clock(clock),
      .reset(reset),
      .load(1'b0),
      .load_value(cte_0),
      .inc_enable(wr_en & (~_full)),
      .dec_enable(1'b0),
      .value(wr_reg)
  );
  // watermark_reg: indica quantos elementos estão válidos na FIFO
  // wr_en: +1 elemento; rd_en: -1 elemento
  sync_parallel_counter #(
      .size($clog2(DEPTH)),
      .init_value(0)
  ) watermark_counter (
      .clock(clock),
      .reset(reset),
      .load(1'b0),
      .load_value(cte_0),
      .inc_enable(wr_en & (~_full)),
      .dec_enable(rd_en & (~_empty)),
      .value(watermark_reg)
  );

  // Escrita na FIFO
  always @(posedge clock) begin
    if (wr_en == 1'b1 && _full == 1'b0) fifo_memory[wr_reg] <= wr_data;
  end

  // Leitura da FIFO
  assign rd_data = fifo_memory[rd_reg];

  // Saídas de Controle
  assign _empty = (watermark_reg == 0);  // vazio, caso watermark_reg = 0
  assign _full = (watermark_reg == DEPTH - 1);  // cheio
  // Quero conferir se isso é sintetizável bonitinho com o Bruno
  assign greater_than_watermark = (watermark_reg > watermark_level);
  assign less_than_watermark = (watermark_reg < watermark_level);
  assign empty = _empty;
  assign full = _full;

`ifdef DEBUG
  assign watermark_reg_ = watermark_reg;
`endif

endmodule
