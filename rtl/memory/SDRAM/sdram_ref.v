//
//! @file   sdram_ref.v
//! @brief  Circuito para restaurar a SDRAM da DE10-Lite, Clock: 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-26
//

`include "sdram_params.vh"

module sdram_ref (
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,      // 1: habilita o refresh
    output reg         end_ref,     // 1: fim do refresh
    // SDRAM
    output wire [12:0] dram_addr,
    output wire [ 1:0] dram_ba,
    output wire        dram_cs_n,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n
);

  // Sinais intermediários/controle
  reg [3:0] command;

  // Contadores
  reg nop_cnt_rst;
  wire [3:0] nop_cnt;
  wire pall_nop_end = (nop_cnt == `T_RP);  // 2 NOPs: Trp
  wire ref_nop_end = (nop_cnt == `T_RC);  // 9 NOPs: Trc -> O último NOP é o Idle do controller

  // Endereços não importam com exceção de A10(All banks)
  assign dram_addr = {3'b001, 10'b0};  // A10 = 1
  assign dram_ba = 2'b00;

  // Comando a ser executado pela SDRAM
  assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;

  reg [2:0] present_state, next_state;  // Estado da FSM

  // contador
  sync_parallel_counter #(
      .size(4),
      .init_value(0)
  ) contador (
      .clock(clock),
      .reset(nop_cnt_rst),
      .load(1'b0),
      .load_value(4'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(nop_cnt)
  );

  // estados da FSM
  localparam reg [2:0]  Idle = 3'b000,
                        Pall = 3'b001,
                        PallNop = 3'b010,
                        Ref = 3'b011,
                        RefNop = 3'b100;

  // lógica de mudança de estados
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // lógica de saída e de próximo estado
  always @(*) begin
    end_ref     = 1'b0;
    nop_cnt_rst = 1'b0;
    case (present_state)  // synthesis parallel_case
      Idle: begin
        command     = 4'b0111;  // NOP
        nop_cnt_rst = 1'b1;
        if (enable == 1'b1) next_state = Pall;
        else next_state = Idle;
      end
      Pall: begin  // Precharge All Banks(precisa mesmo: bancos em Idle?)
        command     = 4'b0010;  // Precharge
        nop_cnt_rst = 1'b1;
        next_state  = PallNop;
      end
      PallNop: begin
        command = 4'b0111;  // NOP
        if (pall_nop_end == 1'b1) next_state = Ref;  // Após 2 NOPs -> Refresh
        else next_state = PallNop;
      end
      Ref: begin
        command     = 4'b0001;  // Refresh
        nop_cnt_rst = 1'b1;
        next_state  = RefNop;
      end
      RefNop: begin
        command = 4'b0111;  // NOP
        if (ref_nop_end == 1'b1) begin
          end_ref    = 1'b1;
          next_state = Idle;
        end else next_state = RefNop;
      end
      default: begin
        next_state = Idle;
      end
    endcase
  end
endmodule
