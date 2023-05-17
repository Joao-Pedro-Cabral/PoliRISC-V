//
//! @file   sdram_controller.v
//! @brief  Controlador SDRAM da DE10-Lite(Single Acess), Clock: 200MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-28
//

module sdram_controller(
    // Processador
    input  wire        clock,
    input  wire        reset,
    input  wire        rd_enable,    // 1: habilita a leitura
    input  wire        wr_enable,    // 1: habilita a escrita
    input  wire [25:0] address,      // endereço da operação
    input  wire [1:0]  rd_wr_size,   // 00: Byte, 01: Half Word, 10: Word, 11: Double Word
    input  wire [63:0] write_data,   // dado a ser escrito na SDRAM
    output wire        busy,
    output wire [63:0] read_data,    // dado lido da SDRAM
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

    // Refresh counter
    reg  ref_rst;
    reg  ref_cnt_en;     // habilita a contagem dos ciclos para refresh
    wire [9:0] ref_cnt; // uso 10 bits para ter certeza que não haverá overflow -> basta apenas 8
    wire ref_start = (ref_cnt >= 157); // Clock*Tref/refresh_count = 20*10^3*64/8192 = 156,25

    // SDRAM init
    reg  init_enable;
    wire end_init;
    wire [12:0] init_dram_addr;
    wire [1:0]  init_dram_ba;
    wire        init_dram_cs_n;
    wire        init_dram_ras_n;
    wire        init_dram_cas_n;
    wire        init_dram_we_n;
    wire [18:0] init_dram = {init_dram_addr, init_dram_ba, init_dram_cs_n, 
        init_dram_ras_n, init_dram_cas_n, init_dram_we_n}; // Sinais do init para a SDRAM

    // SDRAM read write
    reg  rd_wr_enable;     // 1: permite que aconteça uma leitura ou escrita, caso contrário 0
    wire [2:0] rd_wr_num;
    wire end_rd_wr;
    wire [63:0] wr_data; // write data tratado para permitir a correta escrita na memória
    wire [12:0] rd_wr_dram_addr;
    wire [1:0]  rd_wr_dram_ba;
    wire        rd_wr_dram_cs_n;
    wire        rd_wr_dram_ras_n;
    wire        rd_wr_dram_cas_n;
    wire        rd_wr_dram_we_n;
    wire [18:0] rd_wr_dram = {rd_wr_dram_addr, rd_wr_dram_ba, rd_wr_dram_cs_n, 
        rd_wr_dram_ras_n, rd_wr_dram_cas_n, rd_wr_dram_we_n}; // Sinais do rd_wr para a SDRAM

    // SDRAM Refresh
    reg  ref_enable;
    wire end_ref;
    wire [12:0] ref_dram_addr;
    wire [1:0]  ref_dram_ba;
    wire        ref_dram_cs_n;
    wire        ref_dram_ras_n;
    wire        ref_dram_cas_n;
    wire        ref_dram_we_n;
    wire [18:0] ref_dram = {ref_dram_addr, ref_dram_ba, ref_dram_cs_n, 
        ref_dram_ras_n, ref_dram_cas_n, ref_dram_we_n}; // Sinais do ref para a SDRAM

    // busy
    reg busy_d; // entrada D do busy_reg

    wire [18:0] idle_dram = {13'b0, 2'b00, 4'b0111}; // Sinais do idle para a SDRAM (NOP -> addr e ba: dont'care)

    wire [18:0] dram; // Sinais de endereço e de controle da SDRAM

    // estados da FSM
    localparam [1:0]
        init_mode  = 2'h0,
        idle_mode  = 2'h1,
        rd_wr_mode = 2'h2,
        ref_mode   = 2'h3;

    reg [1:0] present_state, next_state; // Estado da FSM

    // Contador de tempo do refresh
    sync_parallel_counter #(.size(10), .init_value(0)) refresh_counter (.clock(clock), .reset(ref_rst), .load(1'b0),
        .load_value(10'b0), .enable(ref_cnt_en), .value(ref_cnt));

    // Controladores auxiliares
    sdram_init init (.clock(clock), .reset(reset), .enable(init_enable), .end_init(end_init), 
        .dram_addr(init_dram_addr), .dram_ba(init_dram_ba), .dram_cs_n(init_dram_cs_n), 
        .dram_ras_n(init_dram_ras_n), .dram_cas_n(init_dram_cas_n), .dram_we_n(init_dram_we_n));

        // Escrita e leitura apenas apenas em idle
        // init_dqm: msb: 1 apenas se for LB/SB operação em endereço par; lsb: 1 se e somente se a operação for em endereço ímpar
    sdram_read_write read_write (.clock(clock), .reset(reset), .rd_enable(rd_enable & rd_wr_enable), .wr_enable(wr_enable & rd_wr_enable),
        .init_row(address[23:11]), .init_column(address[10:1]), .init_bank(address[25:24]), .init_dqm({~(address[0] | rd_wr_size[0] | rd_wr_size[1]), address[0]}),
        .op_num(rd_wr_num), .end_op(end_rd_wr), .rd_data_o(read_data), .wr_data_i(wr_data), .dram_addr(rd_wr_dram_addr), 
        .dram_ba(rd_wr_dram_ba), .dram_cs_n(rd_wr_dram_cs_n), .dram_ras_n(rd_wr_dram_ras_n), .dram_cas_n(rd_wr_dram_cas_n), 
        .dram_we_n(rd_wr_dram_we_n), .dram_ldqm(dram_ldqm), .dram_udqm(dram_udqm), .dram_dq(dram_dq));

    sdram_ref ref (.clock(clock), .reset(reset), .enable(ref_enable), .end_ref(end_ref), 
        .dram_addr(ref_dram_addr), .dram_ba(ref_dram_ba), .dram_cs_n(ref_dram_cs_n), 
        .dram_ras_n(ref_dram_ras_n), .dram_cas_n(ref_dram_cas_n), .dram_we_n(ref_dram_we_n));

    // Saídas da SDRAM
    assign dram_cke = 1'b1;   // clock sempre habilitado
    assign dram_clk = ~clock; // respeitar hold e setup time -> amostro na borda de descida
    assign {dram_addr, dram_ba, dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = dram;

    // Multiplexador para os sinais de endereço e controle da SDRAM com base no estado atual da FSM
    gen_mux #(.size(19), .N(2)) sdram_mux (.A({ref_dram, rd_wr_dram, idle_dram, init_dram}), .S(present_state), .Y(dram));

    // geração do rd_wr_num
    assign rd_wr_num[2] = rd_wr_size[1] & rd_wr_size[0] & address[0];
    assign rd_wr_num[1] = rd_wr_size[1] & (rd_wr_size[0] ^ address[0]);
    assign rd_wr_num[0] = (rd_wr_size[1] & ~ address[0]) | (~rd_wr_size[1] & rd_wr_size[0] & address[0]);

    // Multiplexador para determinar o wr_data 
    // SDRAM R/W escreve a partir dos MSBs, pois a leitura realiza << (1 byte lido é shiftado para a esquerda)
    // Logo, devemos dar o wr_data com os << necessários para colocar os dados na parte mais significativa
    // 11: SD -> Sem shift; 10: SW -> Shift de 32 bits; 01: SH -> Shift de 48 bits; 00: SB -> Shift de 56 bits
    gen_mux #(.size(64), .N(2)) wr_data_mux (.A({write_data, {write_data[31:0], 32'b0}, {write_data[15:0], 48'b0},
        {write_data[7:0], 56'b0}}), .S(rd_wr_size), .Y(wr_data));

    // busy -> levanta na borda de clock seguinte ao levantamento de um dos enables
    // busy -> desce sincronamente com o fim da operação
    register_d #(.N(1), .reset_value(0)) busy_reg (.clock(clock), .reset(reset), .enable(rd_enable | wr_enable), .D(busy_d), .Q(busy)); 

    // transição de estados
    always @(posedge clock, posedge reset) begin
        if(reset) 
            present_state <= init_mode;
        else
            present_state <= next_state;
    end

    // Lógica de próximo estado e de saída
    always @(*) begin
        busy_d        = 1'b1; // valor padrão da entrada: 1
        ref_rst       = 1'b0;
        ref_cnt_en    = 1'b0;
        init_enable   = 1'b0;
        rd_wr_enable  = 1'b0;
        ref_enable    = 1'b0;
        case(present_state) // synthesis parallel_case
            init_mode: begin
                init_enable    = 1'b1; // Habilitar inicialização(não contamos ciclo de refresh no inicio)
                ref_rst        = 1'b1; // zerar o refresh cnt
                if(end_init)
                    next_state = idle_mode;
                else
                    next_state = init_mode;
            end
            idle_mode: begin
                ref_cnt_en     = 1'b1;
                if(ref_start == 1'b1)
                    next_state = ref_mode; // Começar o refresh
                else if(rd_enable == 1'b1 || wr_enable == 1'b1)
                    next_state = rd_wr_mode; // Começar a operação
                else
                    next_state = idle_mode;  // Manter em idle
            end
            rd_wr_mode: begin
                rd_wr_enable   = 1'b1; // Habilitar operação
                ref_cnt_en     = 1'b1; // Contar ciclos de refresh (necessário?)
                if(end_rd_wr) begin
                    busy_d     = 1'b0; // fim da operação -> busy abaixa no próximo ciclo
                    next_state = idle_mode;
                end
                else
                    next_state = rd_wr_mode;
            end
            ref_mode: begin
                ref_enable     = 1'b1; // Realizar refresh
                ref_rst        = 1'b1; // Resetar contador de refresh
                if(end_ref)
                    next_state = idle_mode;
                else
                    next_state = ref_mode;
            end
        endcase
    end
endmodule
