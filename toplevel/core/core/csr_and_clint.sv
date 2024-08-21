
module csr_and_clint (
    // core interface
    wishbone_if.secondary wb_if_s,

    // uart interface
    input  wire rxd,
    output wire txd,
    output wire uart_interrupt
);

  function automatic reg adr_i_is_base(input reg [31:0] base, input reg [31:0] addr);
    begin
      adr_i_is_base = base[31:11] == addr[31:11];
    end
  endfunction

  function automatic reg adr_i_reg_sel(input reg [31:0] reg_adr, input reg [31:0] addr);
    begin
      adr_i_reg_sel = reg_adr[10:0] == addr[10:0];
    end
  endfunction

  wire _we;

  // ctrl block
  localparam reg [31:0] CtrlBase = 32'hf0000000;
  localparam integer CtrlSize = 3;

  reg [31:0] ctrl_out[CtrlSize-1:0];
  integer i0;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i0 = 0; i0 < CtrlSize; i0 = i0 + 1)
        ctrl_out[i0] <= 0;
    end else if (_we && adr_i_is_base(CtrlBase, wb_if_s.addr)) begin
      ctrl_out[wb_if_s.addr[3:2]] <= wb_if_s.dat_i_s;
    end
  end
  // ctrl block end

  // timer block
  localparam reg [31:0] Timer0Base = 32'hf0001800;
  localparam integer Timer0Size = 8;

  reg [31:0] timer0_out[Timer0Size-1:0];
  integer i1;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i1 = 0; i1 < Timer0Size; i1 = i1 + 1)
        timer0_out[i1] <= 0;
    end else if (_we && adr_i_is_base(Timer0Base, wb_if_s.addr)) begin
      timer0_out[wb_if_s.addr[4:2]] <= wb_if_s.dat_i_s;
    end
  end
  // timer block end

  // uart block
  localparam reg [31:0] UartBase = 32'hF0001000;

  wire [31:0] _uart_wr_data;
  wire _uart_ack;
  wishbone_if #(.DATA_SIZE(32), .ADDR_SIZE(3), .BYTE_SIZE(8)) wb_if_uart
               (.clock(wb_if_s.clock), .reset(wb_if_s.reset));

  uart #(
      .LITEX_ARCH(1),
      .FIFO_DEPTH(16),
      .CLOCK_FREQ_HZ(115200 * 32)
  ) uart_0 (
      .wb_if_s(wb_if_uart),
      .rxd(rxd),
      .txd(txd),
      .interrupt(uart_interrupt)
  );
  assign wb_if_uart.cyc = wb_if_s.cyc & adr_i_is_base(UartBase, wb_if_s.addr);
  assign wb_if_uart.stb = wb_if_s.stb & adr_i_is_base(UartBase, wb_if_s.addr);
  assign wb_if_uart.we = wb_if_s.we & adr_i_is_base(UartBase, wb_if_s.addr);
  assign wb_if_uart.addr = wb_if_s.addr[4:2];
  assign wb_if_uart.tgd = wb_if_s.tgd;
  assign wb_if_uart.sel = wb_if_s.sel;
  assign wb_if_uart.dat_o_p = wb_if_s.dat_i_s;
  assign _uart_wr_data = wb_if_uart.dat_o_s;
  // uart block end

  // ethmac block
  localparam reg [31:0] EthmacBase = 32'hf0002000;
  localparam integer EthmacSize = 17;

  reg [31:0] ethmac_out[EthmacSize-1:0];
  integer i2;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i2 = 0; i2 < EthmacSize; i2 = i2 + 1)
        ethmac_out[i2] <= 0;
    end else if (_we && adr_i_is_base(EthmacBase, wb_if_s.addr)) begin
      ethmac_out[wb_if_s.addr[6:2]] <= wb_if_s.dat_i_s;
    end
  end
  // ethmac block end

  // ethphy block
  localparam reg [31:0] EthphyBase = 32'hf0002800;
  localparam integer EthphySize = 3;

  reg [31:0] ethphy_out[EthphySize-1:0];
  integer i3;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i3 = 0; i3 < EthphySize; i3 = i3 + 1)
        ethphy_out[i3] <= 0;
    end else if (_we && adr_i_is_base(EthphyBase, wb_if_s.addr)) begin
      ethphy_out[wb_if_s.addr[3:2]] <= wb_if_s.dat_i_s;
    end
  end
  // ethphy block end

  // leds block
  localparam reg [31:0] LedsBase = 32'hf0003800;
  localparam reg [31:0] LedsOut = 32'hf0003800;

  reg [7:0] leds_out;

  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      leds_out <= 8'b0;
    end else if (_we && adr_i_is_base(LedsBase, wb_if_s.addr)) begin
      case (1'b1)
        adr_i_reg_sel(LedsOut, wb_if_s.addr): begin
          leds_out <= wb_if_s.dat_i_s[7:0];
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
  integer i4;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i4 = 0; i4 < SdCardBlock2MemSize; i4 = i4 + 1)
        sdcard_block2mem_out[i4] <= 0;
    end else if (_we && adr_i_is_base(SdCardBlock2MemBase, wb_if_s.addr)) begin
      sdcard_block2mem_out[wb_if_s.addr[4:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdcard_block2mem block end

  // sdcard_core block
  localparam reg [31:0] SdCardCoreBase = 32'hf0004800;
  localparam reg [3:0] SdCardCoreSize = 11;

  reg [31:0] sdcard_core_out[SdCardCoreSize-1:0];
  integer i5;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i5 = 0; i5 < SdCardCoreSize; i5 = i5 + 1)
        sdcard_core_out[i5] <= 0;
    end else if (_we && adr_i_is_base(SdCardCoreBase, wb_if_s.addr)) begin
      sdcard_core_out[wb_if_s.addr[5:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdcard_core block end

  // sdcard_irq block
  localparam reg [31:0] SdCardIrqBase = 32'hf0005000;
  localparam reg [1:0] SdCardIrqSize = 3;

  reg [31:0] sdcard_irq_out[SdCardIrqSize-1:0];
  integer i6;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i6 = 0; i6 < SdCardIrqSize; i6 = i6 + 1)
        sdcard_irq_out[i6] <= 0;
    end else if (_we && adr_i_is_base(SdCardIrqBase, wb_if_s.addr)) begin
      sdcard_irq_out[wb_if_s.addr[3:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdcard_irq block end

  // sdcard_mem2block block
  localparam reg [31:0] SdCardMem2BlockBase = 32'hf0005800;
  localparam reg [2:0] SdCardMem2BlockSize = 7;

  reg [31:0] sdcard_mem2block_out[SdCardMem2BlockSize-1:0];
  integer i7;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i7 = 0; i7 < SdCardMem2BlockSize; i7 = i7 + 1)
        sdcard_mem2block_out[i7] <= 0;
    end else if (_we && adr_i_is_base(SdCardMem2BlockBase, wb_if_s.addr)) begin
      sdcard_mem2block_out[wb_if_s.addr[4:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdcard_mem2block block end

  // sdcard_phy block
  localparam reg [31:0] SdCardPhyBase = 32'hf0006000;
  localparam reg [2:0] SdCardPhySize = 4;

  reg [31:0] sdcard_phy_out[SdCardPhySize-1:0];
  integer i8;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i8 = 0; i8 < SdCardPhySize; i8 = i8 + 1)
        sdcard_phy_out[i8] <= 0;
    end else if (_we && adr_i_is_base(SdCardPhyBase, wb_if_s.addr)) begin
      sdcard_phy_out[wb_if_s.addr[3:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdcard_phy block end

  // sdram_dfii block
  localparam reg [31:0] SdRamDfiiBase = 32'hf0006800;
  localparam reg [3:0] SdRamDfiiSize = 13;

  reg [31:0] sdram_dfii_out[SdRamDfiiSize-1:0];
  integer i9;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i9 = 0; i9 < SdRamDfiiSize; i9 = i9 + 1)
        sdram_dfii_out[i9] <= 0;
    end else if (_we && adr_i_is_base(SdRamDfiiBase, wb_if_s.addr)) begin
      sdram_dfii_out[wb_if_s.addr[5:2]] <= wb_if_s.dat_i_s;
    end
  end
  // sdram_dfii block end

  // video_dma block
  localparam reg [31:0] SdVideoDmaBase = 32'hf0007000;
  localparam reg [2:0] SdVideoDmaSize = 6;

  reg [31:0] video_dma_out[SdVideoDmaSize-1:0];
  integer i10;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i10 = 0; i10 < SdVideoDmaSize; i10 = i10 + 1)
        video_dma_out[i10] <= 0;
    end else if (_we && adr_i_is_base(SdVideoDmaBase, wb_if_s.addr)) begin
      video_dma_out[wb_if_s.addr[4:2]] <= wb_if_s.dat_i_s;
    end
  end
  // video_dma block end

  // video_vtg block
  localparam reg [31:0] SdVideoVtgBase = 32'hf0007800;
  localparam reg [3:0] SdVideoVtgSize = 9;

  reg [31:0] video_vtg_out[SdVideoVtgSize-1:0];
  integer i11;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (1'b1 == wb_if_s.reset) begin
      for(i11 = 0; i11 < SdVideoVtgSize; i11 = i11 + 1)
        video_vtg_out[i11] <= 0;
    end else if (_we && adr_i_is_base(SdVideoVtgBase, wb_if_s.addr)) begin
      video_vtg_out[wb_if_s.addr[5:2]] <= wb_if_s.dat_i_s;
    end
  end
  // video_vtg block end

  localparam reg AckIdle = 1'b0, AckAsserted = 1'b1;
  reg ack_state, ack_next_state;
  reg _ack;
  always_ff @(posedge wb_if_s.clock, posedge wb_if_s.reset) begin
    if (wb_if_s.reset) begin
      ack_state <= AckIdle;
    end else begin
      ack_state <= ack_next_state;
    end
  end

  always_comb begin
    _ack = 1'b0;
    ack_next_state = AckIdle;

    case (ack_state)
      AckIdle: begin
        if (wb_if_s.stb && wb_if_s.cyc && !adr_i_is_base(UartBase, wb_if_s.addr)) begin
          ack_next_state = AckAsserted;
        end
      end

      AckAsserted: begin
        _ack = 1'b1;
      end

      default: begin
      end
    endcase
  end

  assign _we = wb_if_s.cyc & wb_if_s.stb & wb_if_s.we;

  always_comb begin
    wb_if_s.dat_o_s = 32'b0;
    unique case (wb_if_s.addr[31:11])
      CtrlBase[31:11]: begin
        wb_if_s.dat_o_s = ctrl_out[wb_if_s.addr[3:2]];
      end
      UartBase[31:11]: begin
        wb_if_s.dat_o_s = _uart_wr_data;
      end
      Timer0Base[31:11]: begin
        wb_if_s.dat_o_s = timer0_out[wb_if_s.addr[4:2]];
      end
      EthmacBase[31:11]: begin
        wb_if_s.dat_o_s = ethmac_out[wb_if_s.addr[6:2]];
      end
      EthphyBase[31:11]: begin
        wb_if_s.dat_o_s = ethphy_out[wb_if_s.addr[3:2]];
      end
      LedsBase[31:11]: begin
        wb_if_s.dat_o_s = leds_out;
      end
      SdCardBlock2MemBase[31:11]: begin
        wb_if_s.dat_o_s = sdcard_block2mem_out[wb_if_s.addr[4:2]];
      end
      SdCardCoreBase[31:11]: begin
        wb_if_s.dat_o_s = sdcard_core_out[wb_if_s.addr[5:2]];
      end
      SdCardIrqBase[31:11]: begin
        wb_if_s.dat_o_s = sdcard_irq_out[wb_if_s.addr[3:2]];
      end
      SdCardMem2BlockBase[31:11]: begin
        wb_if_s.dat_o_s = sdcard_mem2block_out[wb_if_s.addr[4:2]];
      end
      SdCardPhyBase[31:11]: begin
        wb_if_s.dat_o_s = sdcard_phy_out[wb_if_s.addr[3:2]];
      end
      SdRamDfiiBase[31:11]: begin
        wb_if_s.dat_o_s = sdram_dfii_out[wb_if_s.addr[5:2]];
      end
      SdVideoDmaBase[31:11]: begin
        wb_if_s.dat_o_s = video_dma_out[wb_if_s.addr[4:2]];
      end
      SdVideoVtgBase[31:11]: begin
        wb_if_s.dat_o_s = video_vtg_out[wb_if_s.addr[5:2]];
      end
      default: begin
        wb_if_s.dat_o_s = 32'b0;
      end
    endcase
  end

  assign wb_if_s.ack = wb_if_uart.ack | _ack;

endmodule
