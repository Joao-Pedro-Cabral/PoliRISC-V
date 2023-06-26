//
//! @file   sdram_controller2.v
//! @brief  Tradução de uma implementação de um controlador de SDRAMs
//          de FPGAs (original em VHDL: https://github.com/nullobject/sdram-fpga/blob/master/sdram.vhd)
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-06-20
//

module sdram_controller2 #(
    // frequência de clock, em MHz.
    parameter integer CLK_FREQ,

    // interface de 32 bits do controlador
    parameter integer ADDR_WIDTH = 26,  // 64Mx8 (memória de 32Mx16)
    parameter integer DATA_WIDTH = 32,

    // interface com a SDRAM
    parameter integer SDRAM_ADDR_WIDTH = 13,
    parameter integer SDRAM_DATA_WIDTH = 16,
    // se esse valor for mudado, deve-se consertar
    // o sdram_a_logic
    parameter integer SDRAM_COL_WIDTH  = 10,
    parameter integer SDRAM_ROW_WIDTH  = 13,
    parameter integer SDRAM_BANK_WIDTH = 2,

    // delay, em ciclos de clock, entre o começo
    // de um comando de leitura e a disponibilidade
    // do dado na saída da memória
    parameter integer CAS_LATENCY = 2,

    // número de palavras de 16 bits que podem ser
    // manipuladas em rajada durante a leitura ou escrita
    parameter integer BURST_LENGTH = 4,

    // valores de temporização, em nanosegundos
    parameter real T_DESL = 100000.0, // delay de inicialização
    parameter real T_MRD  = 14.0,     // tempo de ciclo do registrador de modo
    parameter real T_RC   = 60.0,     // tempo de ciclo de linha da matriz de memória
    parameter real T_RCD  = 15.0,     // delay entre RAS e CAS
    parameter real T_RP   = 15.0,     // delay entre precarga e ativação
    parameter real T_WR   = 15.0,     // tempo de recuperação da escrita
    parameter real T_REFI = 7800.0    // tempo médio refresh

) (
    input reset,
    input clk,

    input [ADDR_WIDTH-1:0] addr,  // endereço
    input [DATA_WIDTH-1:0] data,  // dado de entrada
    input [3:0] bwe,  // byte write enable

    input we,  // write enable
    input req, // requisição de operação

    output ack,  // reconhecimento de operação (operação iniciada)
    output reg valid,  // avisa que dado na saída é válido

    output [DATA_WIDTH-1:0] q,  // dado de saída

    // interface com a SDRAM
    output reg [SDRAM_ADDR_WIDTH-1:0] sdram_a,
    output reg [SDRAM_BANK_WIDTH-1:0] sdram_ba,
    inout reg [SDRAM_DATA_WIDTH-1:0] sdram_dq,
    output sdram_cke,
    output sdram_cs_n,
    output sdram_ras_n,
    output sdram_cas_n,
    output sdram_we_n,
    output reg sdram_dqml,
    output reg sdram_dqmh
);

  // comandos
  localparam reg [3:0]
    CmdDeselect    = 4'hF,
    CmdLoadMode    = 4'h0,
    CmdAutoRefresh = 4'h1,
    CmdPrecharge   = 4'h2,
    CmdActive      = 4'h3,
    CmdWrite       = 4'h4,
    CmdRead        = 4'h5,
    CmdStop        = 4'h6,
    CmdNop         = 4'h7;

  // 0: sequencial 1: intercalado
  localparam reg BurstType = 0;

  // 0: rajada 1: única
  localparam reg WriteBurstMode = 0;

  // ModeReg: valor escrito no registrador
  // de modo para configurar a memória
  localparam reg [2:0] L2BurstLength = $clog2(BURST_LENGTH);
  localparam reg [2:0] CasLatency = CAS_LATENCY;
  localparam reg [SDRAM_ADDR_WIDTH-1:0] ModeReg = {
    3'o0, WriteBurstMode, 2'b00, CasLatency, BurstType, L2BurstLength
  };

  // cálculo de período de clock
  localparam real ClkPeriod = 1.0 / CLK_FREQ * 1000.0;

  // número de ciclos de clock de espera
  // antes de inicializar o dispositivo
  // (arredondado pra cima)
  localparam integer InitWait = (T_DESL + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // durante o comando LOAD MODE
  localparam integer LoadModeWait = (T_MRD + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // durante o comando ACTIVE
  localparam integer ActiveWait = (T_RCD + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // durante o comando REFRESH
  localparam integer RefreshWait = (T_RC + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // durante o comando PRECHARGE
  localparam integer PrechargeWait = (T_RP + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // durante o comando READ
  localparam integer ReadWait = CAS_LATENCY + BURST_LENGTH;

  // número de ciclos de clock de espera
  // durante o comando WRITE
  localparam integer WriteWait = BURST_LENGTH + (T_WR + T_RP + ClkPeriod - 1) / ClkPeriod;

  // número de ciclos de clock de espera
  // antes de ser necessário refrescar a memória
  localparam integer RefreshInterval = (T_REFI / ClkPeriod) - 10;

  // estados do controlador
  localparam reg [2:0]
    Init = 3'o0,
    Mode = 3'o1,
    Idle = 3'o2,
    Active = 3'o3,
    Read = 3'o4,
    Write = 3'o5,
    Refresh = 3'o6;
  // sinais de estado
  reg [2:0] state, next_state;

  reg [3:0] cmd, next_cmd;

  // sinais de controle
  wire start;
  wire load_mode_done;
  wire active_done;
  wire refresh_done;
  wire first_word;
  wire second_word;
  wire third_word;
  wire read_done;
  wire write_done;
  wire should_refresh;

  // contadores
  reg [13:0] wait_counter;
  reg [9:0] refresh_counter;

  // registradores
  reg [SDRAM_COL_WIDTH+SDRAM_ROW_WIDTH+SDRAM_BANK_WIDTH-1:0] addr_reg;
  reg addr_lsb_reg;
  reg [DATA_WIDTH-1:0] data_reg;
  reg we_reg;
  reg [3:0] bwe_reg;
  reg [16*BURST_LENGTH-1:0] q_reg;

  // aliases
  wire [SDRAM_COL_WIDTH-1:0] col = addr_reg[SDRAM_COL_WIDTH-1:0];  // warning: valor hardcoded
  wire [SDRAM_ROW_WIDTH-1:0] row = addr_reg[SDRAM_COL_WIDTH+SDRAM_ROW_WIDTH-1:SDRAM_COL_WIDTH];
  wire [SDRAM_BANK_WIDTH-1:0] bank =
      addr_reg[SDRAM_COL_WIDTH+SDRAM_ROW_WIDTH+SDRAM_BANK_WIDTH-1:SDRAM_COL_WIDTH+SDRAM_ROW_WIDTH];

  // lógica de controle

  // máquina de estados
  // TODO: criar um  sinal que é um OR de todos os dones
  always @(state, wait_counter, req, we_reg, load_mode_done, active_done, refresh_done, read_done,
      write_done, should_refresh) begin : fsm

    next_state <= state;

    // comando padrão é NOP
    next_cmd   <= CmdNop;

    case (state)
      // executa a sequência de inicialização
      Init: begin
        if (wait_counter == 0) next_cmd <= CmdDeselect;
        if (wait_counter == InitWait - 1) next_cmd <= CmdPrecharge;
        if (wait_counter == InitWait + PrechargeWait - 1) next_cmd <= CmdAutoRefresh;
        if (wait_counter == InitWait + PrechargeWait + RefreshWait - 1) next_cmd <= CmdAutoRefresh;
        if (wait_counter == InitWait + PrechargeWait + 2 * RefreshWait - 1) begin
          next_state <= Mode;
          next_cmd   <= CmdLoadMode;
        end
      end

      // Carrega o registrador de modo
      Mode: begin
        if (load_mode_done) next_state <= Idle;
      end

      // espera por requisição de leitura/escrita
      Idle: begin
        if (should_refresh) begin
          next_state <= Refresh;
          next_cmd   <= CmdAutoRefresh;
        end else if (req) begin
          next_state <= Active;
          next_cmd   <= CmdActive;
        end
      end

      // ativa a linha da matriz da memória
      Active: begin
        if (active_done) begin
          if (we_reg) begin
            next_state <= Write;
            next_cmd   <= CmdWrite;
          end else begin
            next_state <= Read;
            next_cmd   <= CmdRead;
          end
        end
      end

      // executa o comando READ
      Read: begin
        if (read_done) begin
          if (should_refresh) begin
            next_state <= Refresh;
            next_cmd   <= CmdAutoRefresh;
          end else if (req) begin
            next_state <= Active;
            next_cmd   <= CmdActive;
          end else next_state <= Idle;
        end
      end

      // executa o comando WRITE
      Write: begin
        if (write_done) begin
          if (should_refresh) begin
            next_state <= Refresh;
            next_cmd   <= CmdAutoRefresh;
          end else if (req) begin
            next_state <= Active;
            next_cmd   <= CmdActive;
          end else next_state <= Idle;
        end
      end

      // executa o comando AUTOREFRESH
      Refresh: begin
        if (refresh_done) begin
          if (req) begin
            next_state <= Active;
            next_cmd   <= CmdActive;
          end else next_state <= Idle;
        end
      end

      default: next_state <= Idle;
    endcase
  end

  // transiciona para o próximo estado
  always @(posedge clk or posedge reset) begin : latch_next_state
    if (reset) begin
      state <= Init;
      cmd   <= CmdNop;
    end else begin
      state <= next_state;
      cmd   <= next_cmd;
    end
  end

  // o wait_counter é utilizado para segurar o
  // estado atual por muitos ciclos de clock
  always @(posedge clk or posedge reset) begin : update_wait_counter
    if (reset) wait_counter <= 0;
    else begin
      if (state != next_state) wait_counter <= 0;  // mudança de estado
      else wait_counter <= wait_counter + 1'b1;
    end
  end

  // o refresh counter é usado para engatilhar uma operação de
  // refresh
  always @(posedge clk or posedge reset) begin : update_refresh_counter
    if (reset) refresh_counter <= 0;
    else begin
      if (state == Refresh && wait_counter == 0) refresh_counter <= 0;
      else refresh_counter <= refresh_counter + 1'b1;
    end
  end

  always @(posedge clk) begin : latch_request
    if (start) begin
      // é necessário multiplicar o endereço por dois,
      // pois há uma conversão de um endereço de 32 bits
      // do controlador para um endereço de 16 bits da
      // SDRAM
      addr_reg     <= addr[SDRAM_COL_WIDTH+SDRAM_ROW_WIDTH+SDRAM_BANK_WIDTH:1];
      addr_lsb_reg <= addr[0];
      data_reg     <= data;
      we_reg       <= we;
      bwe_reg      <= ~bwe;  // warning: valor hardcoded
    end
  end

  // warning: valor hardcoded
  always @(*) begin
    if (state == Write) begin
      if (wait_counter == 0) begin
        if (addr_lsb_reg) sdram_dq = {data_reg[7:0], 8'hzz};
        else sdram_dq = data_reg[15:0];
      end else if (wait_counter == 1'b1) begin
        if (addr_lsb_reg) sdram_dq = data_reg[23:8];
        else sdram_dq = data_reg[31:16];
      end else if (wait_counter == 2'b10) begin
        if (addr_lsb_reg) sdram_dq = {8'hzz, data_reg[31:24]};
        else sdram_dq = 16'hzzzz;
      end else sdram_dq = 16'hzzzz;
    end else sdram_dq = 16'hzzzz;
  end

  always @(posedge clk) begin : latch_sdram_data
    valid <= 0;

    if (state == Read) begin
      if (first_word) begin
        if (addr_lsb_reg) q_reg[7:0] <= sdram_dq[15:8];
        else q_reg <= sdram_dq;
      end else if (second_word) begin
        if (addr_lsb_reg) q_reg[23:8] <= sdram_dq;
        else q_reg[31:16] <= sdram_dq;
      end else if (third_word) begin
        if (addr_lsb_reg) q_reg[31:24] <= sdram_dq[7:0];
        else q_reg[47:32] <= sdram_dq;
      end else if (read_done) begin
        q_reg[63:48] <= sdram_dq;
        valid <= 1'b1;
      end
    end
  end

  // configuração dos sinais de espera
  assign load_mode_done = (wait_counter == LoadModeWait - 1'b1) ? 1'b1 : 1'b0;
  assign active_done = (wait_counter == ActiveWait - 1'b1) ? 1'b1 : 1'b0;
  assign refresh_done = (wait_counter == RefreshWait - 1'b1) ? 1'b1 : 1'b0;
  assign first_word = (wait_counter == CasLatency) ? 1'b1 : 1'b0;
  assign second_word = (wait_counter == CasLatency + 1'b1) ? 1'b1 : 1'b0;
  assign third_word = (wait_counter == CasLatency + 2'b10) ? 1'b1 : 1'b0;
  assign read_done = (wait_counter == ReadWait - 1'b1) ? 1'b1 : 1'b0;
  assign write_done = (wait_counter == WriteWait - 1'b1) ? 1'b1 : 1'b0;

  // a SDRAM deve ser refrescada quando o intervalo de refresh tiver
  // decorrido
  assign should_refresh = (refresh_counter >= RefreshInterval - 1'b1) ? 1'b1 : 1'b0;

  // uma nova requisição só é permitida ao fim dos estados
  // Idle, Read, Write e Refresh
  assign start =
        (state == Idle) ? 1'b1
      : (state == Read && read_done) ? 1'b1
      : (state == Write && write_done) ? 1'b1
      : (state == Refresh && refresh_done) ? 1'b1
      : 1'b0;

  // levanta o sinal de confirmação no começo do estado
  // Active
  assign ack = (state == Active && wait_counter == 14'b0) ? 1'b1 : 1'b0;

  // saída de dados
  /* assign q = addr_lsb_reg ? q_reg[DATA_WIDTH+8-1:8] : q_reg[DATA_WIDTH-1:0]; */
  assign q = q_reg[DATA_WIDTH-1:0];

  // desativa o clock no começo do estado Init
  assign sdram_cke = (state == Init && wait_counter == 14'b0) ? 1'b0 : 1'b1;

  // configuração dos sinais de controle da SDRAM
  assign {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = cmd;

  always @(*) begin : sdram_ba_logic
    case (state)
      Active: sdram_ba = bank;
      Read: sdram_ba = bank;
      Write: sdram_ba = bank;
      default: sdram_ba = 0;
    endcase
  end

  always @(*) begin : sdram_a_logic
    case (state)
      Init: sdram_a = 13'b0010000000000;  // warning: valor hardcoded
      Mode: sdram_a = ModeReg;
      Active: sdram_a = row;
      Read: sdram_a = {3'o1, col};  // warning: valor hardcoded
      Write: sdram_a = {3'o1, col};  // warning: valor hardcoded
      default: sdram_a = 0;
    endcase
  end

  always @(*) begin
    if (wait_counter == 0) begin
      if (addr_lsb_reg) begin
        sdram_dqml = 1'b1;  // desativado
        sdram_dqmh = bwe_reg[0];
      end else begin
        sdram_dqml = bwe_reg[0];
        sdram_dqmh = bwe_reg[1];
      end
    end else if (wait_counter == 1'b1) begin
      if (addr_lsb_reg) begin
        sdram_dqml = bwe_reg[1];
        sdram_dqmh = bwe_reg[2];
      end else begin
        sdram_dqml = bwe_reg[2];
        sdram_dqmh = bwe_reg[3];
      end
    end else begin
      if (addr_lsb_reg) begin
        sdram_dqml = bwe_reg[3];
        sdram_dqmh = 1'b1;  // desativado
      end else begin
        sdram_dqml = 1'b1;  // desativado
        sdram_dqmh = 1'b1;  // desativado
      end
    end
  end
endmodule
