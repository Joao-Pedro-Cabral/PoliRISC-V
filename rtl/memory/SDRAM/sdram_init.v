//
//! @file   sdram_init.v
//! @brief  Inicializa a SDRAM da DE10-Lite, Clock: 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-26
//

module sdram_init(
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,   // 1: habilita a inicialização
    output reg         end_init, // 1: fim da inicialização
    // SDRAM
    output reg  [12:0] dram_addr,
    output wire [1:0]  dram_ba,
	output wire        dram_cs_n,
	output wire        dram_ras_n,
	output wire        dram_cas_n,
	output wire        dram_we_n,
);

// Sinais intermediários/controle
reg  [3:0] command;                                 // CS, RAS, CAS, WE (Esses sinais só tem sentido em conjunto)
reg  contador_reset;                                // reset do contador
reg  contador_reset2;                               // reset do contador
wire [14:0] contagem;                               // contador 
wire [3:0] contagem2;                               // contador
wire power_up_end = (contagem  >= 20000);           // Espera até a SDRAM estabilizar(100 us)
wire pall_auto    = (contagem2 >= 1);               // 2 NOPs: Trp
wire auto_auto    = (contagem2 >= 8);               // 9 NOPs: Trc (tempo entre refreshes)
wire auto_ref_end = (contagem  >= 63);              // Refresh Pós-PALL: 8 AUTO Refresh + 56 NOP

assign dram_ba   = 2'b0; // Sempre 0 na inicialização(don't care nas operações e reservado no Mode Register Set)

// Comando a ser executado pela SDRAM
assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;

// Estado da FSM
reg [2:0] present_state, next_state;

// contadores
sync_parallel_counter #(.size(15), .init_value(0)) contador (.clock(clock), .reset(contador_reset), .enable(1'b1), .value(contagem));
sync_parallel_counter #(.size(4), .init_value(0)) contador2 (.clock(clock), .reset(contador_reset2), .enable(1'b1), .value(contagem2));

// lógica da mudança de estados
always @(posedge clock, posedge reset) begin
    if(reset)
        present_state <= idle;
    else
        present_state <= next_state;
end

// estados da FSM
localparam [2:0]
    idle     = 3'h0,
    power_up = 3'h1,
    pall     = 3'h2,  // Precharge All Banks
    nop      = 3'h3,
    auto_ref = 3'h4,  // Auto Refresh
    nop2     = 3'h5,  // NOP
    mode_reg = 3'h6;  // Mode Register Set

always @(*) begin
    end_init        <= 0;
    contador_reset  <= 0;
    contador_reset2 <= 0;
    dram_addr       <= 0; // don't care com exceção no Mode Register Set e no PALL
    case(present_state)
        idle: begin
            command        <= 4'b0111; // NOP
            contador_reset <= 1;       // Reiniciar contagem
            if(enable == 1'b1)
                next_state <= power_up;
            else
                next_state <= idle;
        end
        power_up: begin
            command         <= 4'b0111;   // NOP
            if(power_up_end == 1'b1)      // SDRAM estável
                next_state  <= pall;
            else
                next_state  <= power_up;
        end
        pall: begin // Precharge All Banks
            comand          <= 4'b0010;           // Precharge
            dram_addr       <= 13'b0010000000000; // A10 = 1 -> All Banks
            contador_reset2 <= 1;                 // Reiniciar contagem2 -> pall_auto  
            next_state      <= nop;
        end
        nop: begin
            command         <= 4'b0111;   // NOP
            contador_reset  <= 1;
            if(pall_auto == 1'b1)
                next_state  <= auto_ref;  // Começar ciclo de Auto Refresh
            else
                next_state  <= nop;    
        auto_ref: begin // Auto Refresh Pós-Pall
            command         <= 4'b0001;   // Auto Refresh
            contador_reset2 <= 1'b1;      // contar REF to REF time(Trc)
            next_state      <= nop2;
        end
        nop2: begin
            command         <= 4'b0111;   // NOP
            if(auto_ref_end == 1'b1)
                next_state  <= mode_reg;  // Fim do Ciclo de Auto Refresh
            else if(auto_auto == 1'b1)
                next_state  <= auto_ref;  // Auto Refresh denovo    
            else 
                next_state  <= nop2;       // Ainda não está na hora de outro Auto Refresh    
        end
        mode_reg: begin
            command           <= 4'h0000;  // Mode Register Set
            // Configuração da SDRAM
            dram_addr[12:10]  <= 3'b000;   // A12, A11, A10: Reservados
            dram_addr[9]      <= 1'b1;     // A9 = 1: Single Location Acess
            dram_addr[8:7]    <= 2'b00;    // A8, A7 = 0: Operação Normal(Demais valores são reservados)
            dram_addr[6:4]    <= 3'b011;   // A6, A5, A4 = 3: CAS = 3
            dram_addr[3]      <= 1'b0;     // A3: Burst Sequencial
            dram_addr[2:0]    <= 3'b000;   // A2, A1, A0 = 0: Apenas 1 endereço
            next_state        <= idle;     // Tmrc é cumprido pelo idle do controller
        end
        default: begin
            command        <= 4'b0111;   // NOP
            next_state     <= idle;   
        end
    endcase   
end   