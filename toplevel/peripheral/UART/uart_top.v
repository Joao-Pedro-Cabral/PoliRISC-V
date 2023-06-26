//
//! @file   uart_top.v
//! @brief  Top para testar a UART
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-21
//

module uart_top (
    // Comum
    input wire clock,
    input wire reset,
    // PC
    input wire rxd,
    output wire txd,
    // Depuração
    output wire [3:0] state,
    output wire p_rxwm,
    output wire [2:0] watermark,
    output wire [6:0] hexa
);

  // Sinais para controlar o DUT
  reg rd_en;
  reg wr_en;
  reg [2:0] addr;
  reg [31:0] wr_data;
  wire rxwm_p;
  wire [31:0] rd_data;
  wire busy;
  wire [7:0] data_out;

  localparam reg Nstop = 1'b0;  // Numero de stop bits

  // FSM
  reg [3:0] present_state, next_state;
  localparam reg [3:0]  Idle = 4'h0,
                        ConfReceiveControl = 4'h1,
                        EndConfReceiveControl = 4'h2,
                        ConfTransmitControl = 4'h3,
                        EndConfTransmitControl = 4'h4,
                        ConfInterruptEn = 4'h5,
                        EndConfInterruptEn = 4'h6,
                        WaitReceivePending = 4'h7,
                        ReadingData = 4'h8,
                        InitWritingData = 4'h9,
                        WritingData = 4'hA;

  uart #(
      .CLOCK_FREQ_HZ(100000000)  // 100 MHz
  ) DUT (
      .clock    (clock),
      .reset    (reset),
      .rd_en    (rd_en),
      .wr_en    (wr_en),
      .addr     ({addr, 2'b00}),
      .rxd      (rxd),
      .wr_data  (wr_data),
      .rxwm_e   (),
      .rxwm_p   (rxwm_p),
      .txwm_e   (),
      .txwm_p   (),
      .data_out (data_out),
      .watermark(watermark),
      .txd      (txd),
      .rd_data  (rd_data),
      .busy     (busy)
  );

  // Transição de Estado
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // Lógica de Saída da FSM
  always @(*) begin
    rd_en = 1'b0;
    wr_en = 1'b0;
    addr = 3'b0;
    wr_data = 0;
    case (present_state)
      Idle: begin
        next_state = ConfReceiveControl;
      end
      // Estados de Configuração da UART
      ConfReceiveControl: begin
        wr_en = 1'b1;
        addr = 3'b011;
        wr_data[0] = 1'b1;
        wr_data[18:16] = 3'b101;
        next_state = EndConfReceiveControl;
      end
      EndConfReceiveControl: begin
        wr_en = 1'b1;
        addr = 3'b011;
        wr_data[0] = 1'b1;
        wr_data[18:16] = 3'b101;
        if (busy) next_state = EndConfReceiveControl;
        else next_state = ConfTransmitControl;
      end
      ConfTransmitControl: begin
        wr_en = 1'b1;
        addr = 3'b010;
        wr_data[1:0] = {Nstop, 1'b1};
        wr_data[18:16] = 3'b010;
        next_state = EndConfTransmitControl;
      end
      EndConfTransmitControl: begin
        wr_en = 1'b1;
        addr = 3'b010;
        wr_data[1:0] = {Nstop, 1'b1};
        wr_data[18:16] = 3'b010;
        if (busy) next_state = EndConfTransmitControl;
        else next_state = ConfInterruptEn;
      end
      ConfInterruptEn: begin
        wr_en = 1'b1;
        addr = 3'b100;
        wr_data[1:0] = 2'b11;
        next_state = EndConfInterruptEn;
      end
      EndConfInterruptEn: begin
        wr_en = 1'b1;
        addr = 3'b100;
        wr_data[1:0] = 2'b11;
        if (busy) next_state = EndConfInterruptEn;
        else next_state = WaitReceivePending;
      end
      // Estados de Operação da UART
      // Espera rxwm_p = 1'b1 -> passar rd_data para wr_data
      WaitReceivePending: begin
        addr = 3'b001;
        if (rxwm_p) begin
          rd_en = 1'b1;
          next_state = ReadingData;
        end else next_state = WaitReceivePending;
      end
      // Realizando a leitura
      ReadingData: begin
        rd_en = 1'b1;
        addr  = 3'b001;
        if (busy) next_state = ReadingData;
        else next_state = InitWritingData;
      end
      // Mandar via TX o dado recebido no RX
      InitWritingData: begin
        wr_en = 1'b1;
        addr = 3'b000;
        wr_data = rd_data;
        next_state = WritingData;
      end
      // Continuar a Escrita
      WritingData: begin
        wr_en = 1'b1;
        addr = 3'b000;
        wr_data = rd_data;
        if (busy) next_state = WritingData;
        // Após a Escrita -> Checar rxwm denovo
        else
          next_state = WaitReceivePending;
      end
      default: begin
        next_state = Idle;
      end
    endcase
  end

  // Depuração
  display ascii_segment (
      .ascii(data_out),
      .hexa (hexa)
  );

  assign state  = present_state;

  assign p_rxwm = rxwm_p;

endmodule
