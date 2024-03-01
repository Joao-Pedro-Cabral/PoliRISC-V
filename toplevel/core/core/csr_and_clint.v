`include "macros.vh"

module csr_and_clint (
    // core interface
    input wire CLK_I,
    input wire RST_I,
    input wire [31:0] ADR_I,
    input wire [31:0] DAT_I,
    input wire CYC_I,
    input wire STB_I,
    input wire WE_I,
    input wire [3:0] SEL_I,
    output reg [31:0] DAT_O,
    output wire ACK_O,

    // uart interface
    input  wire rxd,
    output wire txd,
    output wire uart_interrupt
);

  function automatic reg adr_i_is_base(input reg [31:0] base);
    begin
      adr_i_is_base = base[31:11] == ADR_I[31:11];
    end
  endfunction

  function automatic reg adr_i_reg_sel(input reg [31:0] reg_adr);
    begin
      adr_i_reg_sel = reg_adr[10:0] == ADR_I[10:0];
    end
  endfunction

  wire _we;

  // ctrl block
  localparam reg [31:0] CtrlBase = 32'hf0000000;
  localparam integer CtrlSize = 3;

  reg [7:0] ctrl_out[CtrlSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ctrl_out <= {CtrlSize{32'b0}};
    end else if (_we && adr_i_is_base(CtrlBase)) begin
      ctrl_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // ctrl block end

  // uart block
  localparam reg [31:0] UartBase = 32'hF0001000;

  wire [31:0] _uart_DAT_O;
  wire _uart_ACK_O;

  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .ADR_I(ADR_I[4:2]),
      .DAT_I(DAT_I),
      .CYC_I(CYC_I),
      .STB_I(STB_I & adr_i_is_base(UartBase)),
      .WE_I(WE_I & adr_i_is_base(UartBase)),
      .DAT_O(_uart_DAT_O),
      .ACK_O(_uart_ACK_O),
      .rxd(rxd),
      .txd(txd),
      .interrupt(uart_interrupt)
  );
  // uart block end

  // ethmac block
  localparam reg [31:0] EthmacBase = 32'hf0002000;
  localparam integer EthmacSize = 17;

  reg [31:0] ethmac_out[EthmacSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ethmac_out <= {EthmacSize{32'b0}};
    end else if (_we && adr_i_is_base(EthmacBase)) begin
      ethmac_out[ADR_I[6:2]] <= DAT_I;
    end
  end
  // ethmac block end

  // ethphy block
  localparam reg [31:0] EthphyBase = 32'hf0002800;
  localparam integer EthphySize = 3;

  reg [31:0] ethphy_out[EthphySize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ethphy_out <= {{EthphySize{32'b0}}};
    end else if (_we && adr_i_is_base(EthphyBase)) begin
      ethphy_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // ethphy block end

  // leds block
  localparam reg [31:0] LedsBase = 32'hf0003800;
  localparam reg [31:0] LedsOut = 32'hf0003800;

  reg [7:0] leds_out;

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      leds_out <= 8'b0;
    end else if (_we && adr_i_is_base(LedsBase)) begin
      case (1'b1)
        adr_i_reg_sel(
            LedsOut
        ): begin
          leds_out <= DAT_I[7:0];
        end
        default: begin
        end
      endcase
    end
  end
  // leds block end

  // sdcard_block2mem block
  localparam reg [31:0] SdCardBlock2MemBase = 32'hf0004000;
  localparam reg [2:0] SdCardBlock2MemSize = 7;

  reg [31:0] sdcard_block2mem_out[SdCardBlock2MemSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_block2mem_out <= {SdCardBlock2MemSize{0}};
    end else if (_we && adr_i_is_base(SdCardBlock2MemBase)) begin
      sdcard_block2mem_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // sdcard_block2mem block end

  // sdcard_core block
  localparam reg [31:0] SdCardCoreBase = 32'hf0004800;
  localparam reg [3:0] SdCardCoreSize = 11;

  reg [31:0] sdcard_core_out[SdCardCoreSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_core_out <= {SdCardCoreSize{0}};
    end else if (_we && adr_i_is_base(SdCardCoreBase)) begin
      sdcard_core_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // sdcard_core block end

  // sdcard_irq block
  localparam reg [31:0] SdCardIrqBase = 32'hf0005000;
  localparam reg [1:0] SdCardIrqSize = 3;

  reg [31:0] sdcard_irq_out[SdCardIrqSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_irq_out <= {SdCardIrqSize{0}};
    end else if (_we && adr_i_is_base(SdCardIrqBase)) begin
      sdcard_irq_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // sdcard_irq block end

  // sdcard_mem2block block
  localparam reg [31:0] SdCardMem2BlockBase = 32'hf0005800;
  localparam reg [2:0] SdCardMem2BlockSize = 7;

  reg [31:0] sdcard_mem2block_out[SdCardMem2BlockSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_mem2block_out <= {SdCardMem2BlockSize{0}};
    end else if (_we && adr_i_is_base(SdCardMem2BlockBase)) begin
      sdcard_mem2block_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // sdcard_mem2block block end

  // sdcard_phy block
  localparam reg [31:0] SdCardPhyBase = 32'hf0006000;
  localparam reg [1:0] SdCardPhySize = 4;

  reg [31:0] sdcard_phy_out[SdCardPhySize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_phy_out <= {SdCardPhySize{0}};
    end else if (_we && adr_i_is_base(SdCardPhyBase)) begin
      sdcard_phy_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // sdcard_phy block end

  // sdram_dfii block
  localparam reg [31:0] SdRamDfiiBase = 32'hf0006800;
  localparam reg [3:0] SdRamDfiiSize = 13;

  reg [31:0] sdram_dfii_out[SdRamDfiiSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdram_dfii_out <= {SdRamDfiiSize{0}};
    end else if (_we && adr_i_is_base(SdRamDfiiBase)) begin
      sdram_dfii_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // sdram_dfii block end

  // video_dma block
  localparam reg [31:0] SdVideoDmaBase = 32'hf0006800;
  localparam reg [2:0] SdVideoDmaSize = 6;

  reg [31:0] video_dma_out[SdVideoDmaSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      video_dma_out <= {SdVideoDmaSize{0}};
    end else if (_we && adr_i_is_base(SdVideoDmaBase)) begin
      video_dma_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // video_dma block end

  // video_vtg block
  localparam reg [31:0] SdVideoVtgBase = 32'hf0006800;
  localparam reg [3:0] SdVideoVtgSize = 9;

  reg [31:0] video_vtg_out[SdVideoVtgSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      video_vtg_out <= {SdVideoVtgSize{0}};
    end else if (_we && adr_i_is_base(SdVideoVtgBase)) begin
      video_vtg_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // video_vtg block end

  localparam reg AckIdle = 1'b0, AckAsserted = 1'b1;
  reg ack_state, ack_next_state;
  reg _ACK_O;
  always @(posedge CLK_I, posedge RST_I) begin
    if (RST_I) begin
      ack_state <= AckIdle;
    end else begin
      ack_state <= ack_next_state;
    end
  end

  always @(*) begin
    _ACK_O = 1'b0;
    ack_next_state = AckIdle;

    case (ack_state)
      AckIdle: begin
        if (STB_I && CYC_I && !adr_i_is_base(UartBase)) begin
          ack_next_state = AckAsserted;
        end
      end

      AckAsserted: begin
        _ACK_O = 1'b1;
      end

      default: begin
      end
    endcase
  end

  assign _we = CYC_I & STB_I & WE_I;

  always @* begin
    DAT_O = 32'b0;
    case (ADR_I[31:11])
      CtrlBase[31:11]: begin
        DAT_O = ctrl_out[ADR_I[3:2]];
      end
      UartBase[31:11]: begin
        DAT_O = _uart_DAT_O;
      end
      EthmacBase[31:11]: begin
        DAT_O = ethmac_out[ADR_I[6:2]];
      end
      EthphyBase[31:11]: begin
        DAT_O = ethphy_out[ADR_I[3:2]];
      end
      LedsBase[31:11]: begin
        DAT_O = leds_out;
      end
      SdCardBlock2MemBase[31:11]: begin
        DAT_O = sdcard_block2mem_out[ADR_I[4:2]];
      end
      SdCardCoreBase[31:11]: begin
        DAT_O = sdcard_core_out[ADR_I[5:2]];
      end
      SdCardIrqBase[31:11]: begin
        DAT_O = sdcard_irq_out[ADR_I[3:2]];
      end
      SdCardMem2BlockBase[31:11]: begin
        DAT_O = sdcard_mem2block_out[ADR_I[4:2]];
      end
      SdCardPhyBase[31:11]: begin
        DAT_O = sdcard_phy_out[ADR_I[3:2]];
      end
      SdRamDfiiBase[31:11]: begin
        DAT_O = sdram_dfii_out[ADR_I[5:2]];
      end
      SdVideoDmaBase[31:11]: begin
        DAT_O = video_dma_out[ADR_I[4:2]];
      end
      SdVideoVtgBase[31:11]: begin
        DAT_O = video_vtg_out[ADR_I[5:2]];
      end
      default: begin
        DAT_O = 32'b0;
      end
    endcase
  end

  assign ACK_O = _uart_ACK_O | _ACK_O;

endmodule
