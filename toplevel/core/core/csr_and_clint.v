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
    output wire [31:0] DAT_O,
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

  reg [31:0] _DAT_O;
  wire [31:0] _uart_DAT_O;
  wire _ACK_O;

  // ctrl block
  localparam reg [31:0] CtrlBase = 32'hf0000000;
  localparam integer CtrlSize = 3;

  reg [7:0] ctrl_out[CtrlSize];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ctrl_out <= {CtrlSize{32'b0}};
    end else if (adr_i_is_base(CtrlBase)) begin
      ctrl_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // ctrl block end

  // uart block
  localparam reg [31:0] Uart = 32'hF0001000;

  uart #(
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      .ADR_I(ADR_I[4:2]),
      .DAT_I(DAT_I),
      .CYC_I(CYC_I),
      .STB_I(STB_I & adr_i_is_base(Uart)),
      .WE_I(WE_I & adr_i_is_base(Uart)),
      .DAT_O(_uart_DAT_O),
      .ACK_O(_ACK_O),
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
    end else if (adr_i_is_base(EthmacBase)) begin
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
    end else if (adr_i_is_base(EthphyBase)) begin
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
    end else if (adr_i_is_base(LedsBase)) begin
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

  reg [31:0] sdcard_block2mem_out[SdCardBlock2MemSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_block2mem_out <= {SdCardBlock2MemSize{0}};
    end else if (adr_i_is_base(SdCardBlock2MemBase)) begin
      sdcard_block2mem_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // sdcard_block2mem block end

  // sdcard_core block
  localparam reg [31:0] SdCardCoreBase = 32'hf0004800;
  localparam reg [3:0] SdCardCoreSize = 11;

  reg [31:0] sdcard_core_out[SdCardCoreSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_core_out <= {SdCardCoreSize{0}};
    end else if (adr_i_is_base(SdCardCoreBase)) begin
      sdcard_core_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // sdcard_core block end

  // sdcard_irq block
  localparam reg [31:0] SdCardIrqBase = 32'hf0005000;
  localparam reg [1:0] SdCardIrqSize = 3;

  reg [31:0] sdcard_irq_out[SdCardIrqSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_irq_out <= {SdCardIrqSize{0}};
    end else if (adr_i_is_base(SdCardIrqBase)) begin
      sdcard_irq_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // sdcard_irq block end

  // sdcard_mem2block block
  localparam reg [31:0] SdCardMem2BlockBase = 32'hf0005800;
  localparam reg [2:0] SdCardMem2BlockSize = 7;

  reg [31:0] sdcard_mem2block_out[SdCardMem2BlockSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_mem2block_out <= {SdCardMem2BlockSize{0}};
    end else if (adr_i_is_base(SdCardMem2BlockBase)) begin
      sdcard_mem2block_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // sdcard_mem2block block end

  // sdcard_phy block
  localparam reg [31:0] SdCardPhyBase = 32'hf0006000;
  localparam reg [1:0] SdCardPhySize = 4;

  reg [31:0] sdcard_phy_out[SdCardPhySize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdcard_phy_out <= {SdCardPhySize{0}};
    end else if (adr_i_is_base(SdCardPhyBase)) begin
      sdcard_phy_out[ADR_I[3:2]] <= DAT_I;
    end
  end
  // sdcard_phy block end

  // sdram_dfii block
  localparam reg [31:0] SdRamDfiiBase = 32'hf0006800;
  localparam reg [3:0] SdRamDfiiSize = 13;

  reg [31:0] sdram_dfii_out[SdRamDfiiSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      sdram_dfii_out <= {SdRamDfiiSize{0}};
    end else if (adr_i_is_base(SdRamDfiiBase)) begin
      sdram_dfii_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // sdram_dfii block end

  // video_dma block
  localparam reg [31:0] SdVideoDmaBase = 32'hf0006800;
  localparam reg [2:0] SdVideoDmaSize = 6;

  reg [31:0] video_dma_out[SdVideoDmaSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      video_dma_out <= {SdVideoDmaSize{0}};
    end else if (adr_i_is_base(SdVideoDmaBase)) begin
      video_dma_out[ADR_I[4:2]] <= DAT_I;
    end
  end
  // video_dma block end

  // video_vtg block
  localparam reg [31:0] SdVideoVtgBase = 32'hf0006800;
  localparam reg [3:0] SdVideoVtgSize = 9;

  reg [31:0] video_vtg_out[SdVideoVtgSize-1:0];

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      video_vtg_out <= {SdVideoVtgSize{0}};
    end else if (adr_i_is_base(SdVideoVtgBase)) begin
      video_vtg_out[ADR_I[5:2]] <= DAT_I;
    end
  end
  // video_vtg block end

  assign DAT_O = adr_i_is_base(Uart) ? _uart_DAT_O : _DAT_O;
  assign ACK_O = _ACK_O;
endmodule
