
`include "macros.vh"

module uart_fsm #(
    parameter reg LITEX_MODE = 0
) (
    // COMMON
    input wire clock,
    input wire reset,
    input wire rd_en,
    input wire wr_en,
    input wire [2:0] addr,
    output reg op,
    output reg ack,
    // BANK
    output wire bank_rd_en,
    output wire bank_wr_en,
    output wire rxdata_wr_en,
    // DEBUG
`ifdef DEBUG
    output wire [1:0] present_state_,
`endif
    // PHY
    output wire tx_fifo_wr_en,
    output wire rx_fifo_rd_en
);

  reg _rd_en, _wr_en;
  reg end_wr, end_rd;

  // FSM
  reg [2:0] present_state, next_state;  // Estado da transmissão

  // Estados possíveis
  localparam reg [2:0] Idle = 3'b000, Read = 3'b001, Write = 3'b010, EndOp = 3'b011, Final = 3'b100;

  function automatic is_txdata_addr(input integer mode, input reg [2:0] addr);
    begin
      is_txdata_addr = (addr == 3'b000);
    end
  endfunction

  function automatic is_rxdata_addr(input integer mode, input reg [2:0] addr);
    begin
      is_rxdata_addr = mode ? (addr == 3'b000) : (addr == 3'b001);
    end
  endfunction

  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Transição de Estado
  always @(*) begin
    next_state = Idle;
    case (present_state)
      Idle: begin
        if (rd_en) next_state = Read;
        else if (wr_en) next_state = Write;
      end
      Read: begin
        if (is_rxdata_addr(LITEX_MODE, addr)) next_state = EndOp;
        else next_state = Final;
      end
      Write: begin
        if (is_txdata_addr(LITEX_MODE, addr)) next_state = EndOp;
        else next_state = Final;
      end
      EndOp:   next_state = Final;
      default: next_state = Idle;  // Final
    endcase
  end

  // Lógica de saída
  always @(posedge clock, posedge reset) begin
    ack    <= 1'b0;
    op     <= 1'b0;
    _rd_en <= 1'b0;
    _wr_en <= 1'b0;
    end_rd <= 1'b0;
    end_wr <= 1'b0;
    if (reset) begin
    end else begin
      case (next_state)
        Read: begin
          op     <= 1'b1;
          _rd_en <= 1'b1;
        end
        Write: begin
          op     <= 1'b1;
          _wr_en <= 1'b1;
        end
        EndOp: begin
          op     <= 1'b1;
          end_rd <= _rd_en & is_rxdata_addr(LITEX_MODE, addr);
          end_wr <= _wr_en & is_txdata_addr(LITEX_MODE, addr);
        end
        Final: begin
          ack <= 1'b1;
        end
        default: begin  // Nothing to do (Idle)
        end
      endcase
    end
  end

  assign bank_rd_en = _rd_en;
  assign bank_wr_en = _wr_en;
  assign rxdata_wr_en = end_rd;
  assign tx_fifo_wr_en = end_wr;
  assign rx_fifo_rd_en = _rd_en & is_rxdata_addr(LITEX_MODE, addr);

  // DEBUG
`ifdef DEBUG
  assign present_state_ = present_state;
`endif

endmodule
