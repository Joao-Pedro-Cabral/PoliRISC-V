//
//! @file   sdram_tester.v
//! @brief  Circuito para testar o SDRAM Controller(DE10-Lite) com Clock = 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//

module sdram_tester(
    // Usuário
    input  wire        clock,        // 200 MHz
    input  wire        reset_n,      // KEY0
    input  wire        ativar,       // KEY1
    input  wire [9:0]  chaves,       // SW0 à SW9
    output wire [6:0]  lsb,          // 4 bits menos significativos (HEX0)
    output wire [6:0]  msb,          // 4 bits mais significativos  (HEX1)
    output wire        sdram_busy,   // busy do controlador da SDRAM
    // SDRAM
    output wire        dram_clk,
    output wire        dram_cke,
    output wire [12:0] dram_addr,
    output wire [1:0]  dram_ba,
	output wire        dram_cs_n,
	output wire        dram_ras_n,
	output wire        dram_cas_n,
	output wire        dram_we_n,
    output wire        dram_ldqm,
    output wire        dram_udqm,
    inout  wire [15:0] dram_dq
);

    // Sinais intermediários
    wire reset = ~ reset_n;                      // KEY0 ativo baixo
    wire ativado;                                // indica borda de subida do ativar
    wire wr_en, rd_en, addr_en, size_en;         // enables dos registradores
    wire wr_data_en;
    wire op_rst;                                 // reset da operação(rd/wr)
    wire [1:0] addr_src;                         // seletor do mux do endereço
    wire addr_mux_out;                           // saída do multiplexador de endereço
    wire [2:0] contagem;                         // contagem do número de bytes que foram escritos/lidos
    wire cnt_rst, cnt_en;                        // Reset e enable da contagem
    wire op_end;                                 // Fim da operação com o shift register
    wire busy;                                   // SDRAM Controller está realizando uma operação

    // DF
    sdram_tester_df DF (.clock(clock), .reset(reset), .ativar(ativar), .chaves(chaves), .lsb(lsb), .msb(msb), .addr_en(addr_en), 
        .wr_en(wr_en), .rd_en(rd_en), .wr_data_en(wr_data_en), .size_en(size_en), .cnt_en(cnt_en), .cnt_rst(cnt_rst), .op_rst(op_rst),
        .addr_src(addr_src), .ativado(ativado), .op_end(op_end), .busy(busy), .dram_clk(dram_clk), .dram_cke(dram_cke),
        .dram_addr(dram_addr), .dram_ba(dram_ba), .dram_cs_n(dram_cs_n), .dram_ras_n(dram_ras_n), .dram_cas_n(dram_cas_n),
        .dram_we_n(dram_we_n), .dram_ldqm(dram_ldqm), .dram_udqm(dram_udqm), .dram_dq(dram_dq));
    
    // UC
    sdram_tester_uc UC (.clock(clock), .reset(reset), .chaves_0(chaves[0]), .ativado(ativado), .op_end(op_end), .busy(busy), .op_rst(op_rst), .addr_en(addr_en), 
        .size_en(size_en), .rd_en(rd_en), .wr_en(wr_en), .wr_data_en(wr_data_en), .cnt_en(cnt_en), .cnt_rst(cnt_rst), .addr_src(addr_src));
    
    assign sdram_busy = busy;

endmodule