//
//! @file   sdram_init.v
//! @brief  Inicializa a SDRAM da DE10-Lite, Clock: 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-26
//

`include "sdram_params.vh"

module sdram_init (
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,      // 1: habilita a inicialização
    output reg         end_init,    // 1: fim da inicialização
    // SDRAM
    output reg  [12:0] dram_addr,
    output wire [ 1:0] dram_ba,
    output wire        dram_cs_n,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n
);

  // Sinais intermediários/controle
  reg [3:0] command;  // CS, RAS, CAS, WE (Esses sinais só tem sentido em conjunto)
  reg contador_reset;  // reset do contador
  reg contador_reset2;  // reset do contador
  wire [14:0] contagem;  // contador
  wire [3:0] contagem2;  // contador
  wire power_up_end = (contagem == `T_DELAY);  // Espera até a SDRAM estabilizar(100 us);
  wire pall_auto = (contagem2 == `T_RP);  // 2 NOPs: Trp
  wire auto_auto = (contagem2 == `T_RC);  // 9 NOPs: Trc (tempo entre refreshes)
  wire auto_ref_end = (contagem == `T_REF_INI);  // Refresh Pós-PALL: 8 AUTO Refresh + 72 NOP

  assign dram_ba = 2'b0; // Sempre 0 na inicialização(don't care nas operações e reservado no MRS)

  // Comando a ser executado pela SDRAM
  assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;

  // Estado da FSM
  reg [2:0] present_state, next_state;

  // contadores
  sync_parallel_counter #(
      .size(15),
      .init_value(0)
  ) contador (
      .clock(clock),
      .reset(contador_reset),
      .load(1'b0),
      .load_value(15'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(contagem)
  );
  sync_parallel_counter #(
      .size(4),
      .init_value(0)
  ) contador2 (
      .clock(clock),
      .reset(contador_reset2),
      .load(1'b0),
      .load_value(4'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .value(contagem2)
  );

  // estados da FSM
  localparam reg [2:0]  Idle = 3'h0,
                        PowerUp = 3'h1,
                        Pall = 3'h2,
                        Nop = 3'h3,
                        AutoRef = 3'h4,
                        Nop2 = 3'h5,
                        ModeReg = 3'h6;

  // lógica da mudança de estados
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  always @(*) begin
    end_init        = 0;
    contador_reset  = 0;
    contador_reset2 = 0;
    dram_addr       = 0;  // don't care com exceção no Mode Register Set e no PALL
    case (present_state)  // synthesis parallel_case
      Idle: begin
        command         = 4'b0111;  // NOP
        contador_reset  = 1;  // Resetar contadores
        contador_reset2 = 1;
        if (enable == 1'b1) next_state = PowerUp;
        else next_state = Idle;
      end
      PowerUp: begin
        command = 4'b0111;  // NOP
        if (power_up_end == 1'b1)  // SDRAM estável
          next_state = Pall;
        else next_state = PowerUp;
      end
      Pall: begin  // Precharge All Banks
        command         = 4'b0010;  // Precharge
        dram_addr       = 13'b0010000000000;  // A10 = 1 -> All Banks
        contador_reset2 = 1;  // Reiniciar contagem2 -> pall_auto
        next_state      = Nop;
      end
      Nop: begin
        command        = 4'b0111;  // NOP
        contador_reset = 1;
        if (pall_auto == 1'b1) next_state = AutoRef;  // Começar ciclo de Auto Refresh
        else next_state = Nop;
      end
      AutoRef: begin  // Auto Refresh Pós-Pall
        command         = 4'b0001;  // Auto Refresh
        contador_reset2 = 1'b1;  // contar REF to REF time(Trc)
        next_state      = Nop2;
      end
      Nop2: begin
        command = 4'b0111;  // NOP
        if (auto_ref_end == 1'b1) next_state = ModeReg;  // Fim do Ciclo de Auto Refresh
        else if (auto_auto == 1'b1) next_state = AutoRef;  // Auto Refresh denovo
        else next_state = Nop2;  // Ainda não está na hora de outro Auto Refresh
      end
      ModeReg: begin
        command          = 4'b0000;  // Mode Register Set
        // Configuração da SDRAM
        dram_addr[12:10] = 3'b000;  // A12, A11, A10: Reservados
        dram_addr[9]     = 1'b1;  // A9 = 1: Single Location Acess
        dram_addr[8:7]   = 2'b00;  // A8, A7 = 0: Operação Normal(Demais valores são reservados)
        dram_addr[6:4]   = 3'b011;  // A6, A5, A4 = 3: CAS = 3
        dram_addr[3]     = 1'b0;  // A3: Burst Sequencial
        dram_addr[2:0]   = 3'b000;  // A2, A1, A0 = 0: Apenas 1 endereço
        end_init         = 1'b1;  // fim da inicialização
        next_state       = Idle;  // Tmrc é cumprido pelo Idle do controller
      end
      default: begin
        command    = 4'b0111;  // NOP
        next_state = Idle;
      end
    endcase
  end
endmodule
