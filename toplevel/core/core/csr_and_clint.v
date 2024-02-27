`include "macros.vh"
`include "extensions.vh"

`define ADR_I_IS_BASE(BASE) (BASE[31:11] == ADR_I[31:11])
`define ADR_I_REG_SEL(REG_ADR) (REG_ADR[10:0] == ADR_I[10:0])

module csr_and_clint (
    input wire CLK_I,
    input wire RST_I,
    input wire [31:0] ADR_I,
    input wire [31:0] DAT_I,
    input wire CYC_I,
    input wire STB_I,
    input wire WE_I,
    input wire [3:0] SEL_I,
    output wire [31:0] DAT_O,
    output wire ACK_O
);

  reg [31:0] _DAT_O;

  // ctrl block
  localparam reg [31:0] CtrlBase = 32'hf0000000;
  localparam reg [31:0] CtrlReset = 32'hf0000000;
  localparam reg [31:0] CtrlScratch = 32'hf0000004;
  localparam reg [31:0] CtrlBusErrors = 32'hf0000008;

  reg [7:0] ctrl_reset, ctrl_scratch, ctrl_bus_errors;

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      {ctrl_reset, ctrl_scratch, ctrl_bus_errors} <= {8'b0, 8'b0, 8'b0};
    end else if (`ADR_I_IS_BASE(CtrlBase)) begin
      case (1'b1)
        `ADR_I_REG_SEL(CtrlReset): begin
            ctrl_reset <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(CtrlScratch): begin
            ctrl_scratch <= DAT_I[7:0];
        end
        /* Read only
        `ADR_I_REG_SEL(CtrlBusErrors): begin
            ctrl_bus_errors <= DAT_I[7:0];
        end
        */
        default: begin
        end
      endcase
    end
  end
  // ctrl block end

  // ddrphy block
  localparam reg [31:0] DdrphyBase = 32'hf0000800;
  localparam reg [31:0] DdrphyRst = 32'hf0000800;
  localparam reg [31:0] DdrphyDlySel = 32'hf0000804;
  localparam reg [31:0] DdrphyHalfSys8xTaps = 32'hf0000808;
  localparam reg [31:0] DdrphyWlevelEn = 32'hf000080C;
  localparam reg [31:0] DdrphyWlevelStrobe = 32'hf0000810;
  localparam reg [31:0] DdrphyRdlyDqRst = 32'hf0000814;
  localparam reg [31:0] DdrphyRdlyDqInc = 32'hf0000818;
  localparam reg [31:0] DdrphyRdlyDqBitslipRst = 32'hf000081C;
  localparam reg [31:0] DdrphyRdlyDqBitslip = 32'hf0000820;
  localparam reg [31:0] DdrphyWdlyDqBitslipRst = 32'hf0000824;
  localparam reg [31:0] DdrphyWdlyDqBitslip = 32'hf0000828;
  localparam reg [31:0] DdrphyRdphase = 32'hf000082C;
  localparam reg [31:0] DdrphyWrphase = 32'hf0000830;

  reg [7:0] ddrphy_rst;
  reg [7:0] ddrphy_dly_sel;
  reg [7:0] ddrphy_half_sys8x_taps;
  reg [7:0] ddrphy_wlevel_en;
  reg [7:0] ddrphy_wlevel_strobe;
  reg [7:0] ddrphy_rdly_dq_rst;
  reg [7:0] ddrphy_rdly_dq_inc;
  reg [7:0] ddrphy_rdly_dq_bitslip_rst;
  reg [7:0] ddrphy_rdly_dq_bitslip;
  reg [7:0] ddrphy_wdly_dq_bitslip_rst;
  reg [7:0] ddrphy_wdly_dq_bitslip;
  reg [7:0] ddrphy_rdphase;
  reg [7:0] ddrphy_wrphase;

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ddrphy_rst <= 8'b0';
      ddrphy_dly_sel <= 8'b0';
      ddrphy_half_sys8x_taps <= 8'b0';
      ddrphy_wlevel_en <= 8'b0';
      ddrphy_wlevel_strobe <= 8'b0';
      ddrphy_rdly_dq_rst <= 8'b0';
      ddrphy_rdly_dq_inc <= 8'b0';
      ddrphy_rdly_dq_bitslip_rst <= 8'b0';
      ddrphy_rdly_dq_bitslip <= 8'b0';
      ddrphy_wdly_dq_bitslip_rst <= 8'b0';
      ddrphy_wdly_dq_bitslip <= 8'b0';
      ddrphy_rdphase <= 8'b0';
      ddrphy_wrphase <= 8'b0';
    end else if (`ADR_I_IS_BASE(DdrphyBase)) begin
      case (1'b1)
        `ADR_I_REG_SEL(DdrphyBase): begin
          Ddrphy_rst <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRst): begin
          ddrphy_rst <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyDlySel): begin
          ddrphy_dly_sel <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyHalfSys8xTaps): begin
          ddrphy_half_sys8x_taps <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyWlevelEn): begin
          ddrphy_wlevel_en <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyWlevelStrobe): begin
          ddrphy_wlevel_strobe <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRdlyDqRst): begin
          ddrphy_rdly_dq_rst <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRdlyDqInc): begin
          ddrphy_rdly_dq_inc <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRdlyDqBitslipRst): begin
          ddrphy_rdly_dq_bitslip_rst <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRdlyDqBitslip): begin
          ddrphy_rdly_dq_bitslip <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyWdlyDqBitslipRst): begin
          ddrphy_wdly_dq_bitslip_rst <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyWdlyDqBitslip): begin
          ddrphy_wdly_dq_bitslip <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyRdphase): begin
          ddrphy_rdphase <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(DdrphyWrphase): begin
          ddrphy_wrphase <= DAT_I[7:0];
        end
        default: begin
        end
      endcase
    end
  end
  // ddrphy block end

  // ethphy block
  localparam reg [31:0] EthphyBase = 32'hf0002800;
  localparam reg [31:0] EthphyCrgReset = 32'hf0002800;
  localparam reg [31:0] EthphyMdioW = 32'hf0002804;
  localparam reg [31:0] EthphyMdioR = 32'hf0002808;

  reg [7:0] ethphy_crg_reset;
  reg [7:0] ethphy_mdio_w;
  reg [7:0] ethphy_mdio_r;

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      ethphy_crg_reset <= 8'b0;
      ethphy_mdio_w <= 8'b0;
      ethphy_mdio_r <= 8'b0;
    end else if (`ADR_I_IS_BASE(EthphyBase)) begin
      case (1'b1)
        `ADR_I_REG_SEL(EthphyCrgReset): begin
          ethphy_crg_reset <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(EthphyMdioW): begin
          ethphy_mdio_w <= DAT_I[7:0];
        end
        `ADR_I_REG_SEL(EthphyMdioR): begin
          ethphy_mdio_r <= DAT_I[7:0];
        end
        default: begin
        end
      endcase
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
    end else if (`ADR_I_IS_BASE(LedsBase)) begin
      case (1'b1)
        `ADR_I_REG_SEL(LedsOut): begin
          leds_out <= DAT_I[7:0];
        end
        default: begin
        end
      endcase
    end
  end
  // leds block end

  // leds block
  localparam reg [31:0] LedsBase = 32'hf0003800;
  localparam reg [31:0] LedsOut = 32'hf0003800;

  reg [7:0] leds_out;

  always @(posedge CLK_I, posedge RST_I) begin
    if (1'b1 == RST_I) begin
      leds_out <= 8'b0;
    end else if (`ADR_I_IS_BASE(LedsBase)) begin
      case (1'b1)
        `ADR_I_REG_SEL(LedsOut): begin
          leds_out <= DAT_I[7:0];
        end
        default: begin
        end
      endcase
    end
  end
  // leds block end

  assign DAT_O = _DAT_O;

endmodule
