//
//! @file   sdram_tester_df.v
//! @brief  Dataflow do SDRAM Tester
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//

module sdram_tester_df (
    // Comum
    input  wire        clock,
    input  wire        reset,
    // Interface Humana
    input  wire        ativar,
    input  wire [9:0]  chaves,
    output wire [6:0]  lsb,
    output wire [6:0]  msb, 
    // UC
    input  wire        addr_en,
    input  wire        size_en,
    input  wire        rd_en,
    input  wire        wr_en,
    input  wire        wr_data_en,
    input  wire        cnt_en,
    input  wire        cnt_rst,
    input  wire        op_rst,
    input  wire [1:0]  addr_src,
    output wire        ativado,
    output wire        op_end,
    output wire        busy,
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

    // Sinais do Controlador
    wire        rd_enable;         // 1: habilita a leitura
    wire        wr_enable;         // 1: habilita a escrita
    wire [25:0] address;           // endereço da operação
    wire [1:0]  rd_wr_size;        // 00: Byte, 01: Half Word, 10: Word, 11: Double Word
    wire [63:0] write_data;        // dado a ser escrito na SDRAM
    wire [63:0] read_data;         // dado lido da SDRAM

    // Sinais intermediários
    wire [25:0] addr_mux_out;                // saída do multiplexador de endereço
    wire [2:0] contagem;                     // contagem do número de bytes que foram escritos/lidos
    reg  [2:0] byte_num;                     // numero de bytes envolvidos na operação - 1(0, 1, 3 ou 7)

    // Saída dos displays
    wire [3:0] read_data_lsb;
    wire [3:0] read_data_msb;

    // Controlador (KEY0 é ativo baixo)
    sdram_controller Controlador (.clock(clock), .reset(reset), .rd_enable(rd_enable), .wr_enable(wr_enable),
        .address(address), .rd_wr_size(rd_wr_size), .write_data(write_data), .busy(busy), 
        .read_data(read_data), .dram_clk(dram_clk), .dram_cke(dram_cke), .dram_addr(dram_addr), 
        .dram_ba(dram_ba), .dram_cs_n(dram_cs_n), .dram_ras_n(dram_ras_n), .dram_cas_n(dram_cas_n), 
        .dram_we_n(dram_we_n), .dram_ldqm(dram_ldqm), .dram_udqm(dram_udqm), .dram_dq(dram_dq));

    // Edge detector (Ativar é ativo alto X KEY1 é ativo baixo)
    edge_detector detecta_ativar (.clock(clock), .reset(reset), .sinal(~ativar), .pulso(ativado));

    // Registradores para acessar o Controlador
    register_d #(.N(2), .reset_value(0))  op_reg (.clock(clock), .reset(reset | op_rst), .enable(rd_en | wr_en), 
        .D({wr_en, rd_en}), .Q({wr_enable, rd_enable}));
    register_d #(.N(26), .reset_value(0)) addr_reg (.clock(clock), .reset(reset), .enable(addr_en),
        .D(addr_mux_out), .Q(address));
    register_d #(.N(2), .reset_value(0))  size_reg (.clock(clock), .reset(reset), .enable(size_en), 
        .D(chaves[1:0]), .Q(rd_wr_size));
    register_d #(.N(64), .reset_value(0)) write_reg (.clock(clock), .reset(reset), .enable(wr_data_en),
        .D({write_data[55:0], chaves[7:0]}), .Q(write_data));

    // Multiplexador para selecionar a região do endereço que será alterada
    gen_mux #(.size(26), .N(2)) addr_mux (.A({address, {chaves[5:0], address[19:0]}, 
        {address[25:20], chaves[9:0], address[9:0]}, {address[25:10], chaves[9:0]}}), .S(addr_src), .Y(addr_mux_out));

    // Multiplexadores para determinar a parte do dado lido que será exibido no display
    gen_mux #(.size(4), .N(3)) lsb_mux (.A({read_data[59:56], read_data[51:48],
        read_data[43:40], read_data[35:32], read_data[27:24], read_data[19:16], 
        read_data[11:8], read_data[3:0]}), .S(contagem), .Y(read_data_lsb));
    gen_mux #(.size(4), .N(3)) msb_mux (.A({read_data[63:60], read_data[55:52],
        read_data[47:44], read_data[39:36], read_data[31:28], read_data[23:20], 
        read_data[15:12], read_data[7:4]}), .S(contagem), .Y(read_data_msb));

    // displays
    hexa7seg display_lsb (.hexa(read_data_lsb), .sseg(lsb));
    hexa7seg display_msb (.hexa(read_data_msb), .sseg(msb));

    // Contagem
    sync_parallel_counter #(.size(3), .init_value(0)) counter (.clock(clock), .reset(cnt_rst), .load(1'b0),
        .enable(cnt_en), .load_value(3'b0), .value(contagem));
    
    // Lógica para determinar o byte_num
    always @(*) begin
        case(rd_wr_size)  // byte_num = 2**rd_wr_size - 1
            0:       byte_num = 0;
            1:       byte_num = 1;
            2:       byte_num = 3;
            3:       byte_num = 7;
            default: byte_num = 0; // Impossível a priori
        endcase
    end

    assign op_end = ~(|(byte_num ^ contagem)); // fim da operação

endmodule