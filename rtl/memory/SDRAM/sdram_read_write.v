//
//! @file   sdram_read_write.v
//! @brief  Realiza operações de leitura e escrita na SDRAM da DE10-Lite(Single Acess), Clock: 200MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-28
//

`include "sdram_params.vh"

module sdram_read_write (
    input  wire        clock,
    input  wire        reset,
    input  wire        rd_enable,    // 1: habilita a leitura
    input  wire        wr_enable,    // 1: habilita a escrita
    input  wire [12:0] init_row,
    input  wire [ 9:0] init_column,
    input  wire [ 1:0] init_bank,
    input  wire [ 1:0] init_dqm,     // Valores válidos: 00, 01 e 10(apenas LB)
    input  wire [ 2:0] op_num,       // Número de operações: 1 a 5(000 a 100)
    output reg         end_op,       // 1: fim das operações
    output wire [63:0] rd_data_o,
    input  wire [63:0] wr_data_i,
    // SDRAM
    output reg  [12:0] dram_addr,
    output reg  [ 1:0] dram_ba,
    output wire        dram_cs_n,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,
    output wire        dram_ldqm,
    output wire        dram_udqm,
    inout  wire [15:0] dram_dq
);

  // Configuração da SDRAM
  reg  [ 3:0] command;
  reg  [ 1:0] dqm;

  // Endereço da Operação
  wire [12:0] row;
  wire [ 9:0] column;
  wire [ 1:0] bank;
  wire [24:0] address;
  wire [24:0] init_address = {init_bank, init_row, init_column};

  // Sinais de controle do endereço da operação
  reg         address_load;
  reg         address_enable;

  // Sinais de leitura
  reg         reading;  // 1: leitura
  reg         rd_data_reset;  // Reset do dado lido
  wire [63:0] shift_read_data;  // Dado lido shiftado
  wire [63:0] read_data;  // Dado lido

  // Sinais de escrita
  reg         writing;  // 1: escrita
  reg         wr_data_load;  // carregar dado da entrada no registrador de escrita
  wire [63:0] shift_write_data;  // Dado a ser escrito no registrador
  wire [63:0] write_data;  // Dado a ser escrito na SDRAM

  // Sinais de controle da operação
  wire [ 1:0] op_dqm;  // dqm da operação
  wire [ 1:0] op_dqm_mux_out;  // entrada do registrador do op_dqm
  reg         op_dqm_en;  // habilitar escrita do novo op_dqm
  reg  [ 1:0] op_dqm_src;  // escolher o op_dqm_mux_out
  wire        ops_end;  // 1: fim da operação

  // Contagens
  reg         nop_count_reset;  // reset do contador de nops
  reg         op_cnt_reset;  // reset do contador de operações
  reg         op_cnt_enable;  // enable do contador de operações
  wire [ 1:0] nop_count;  // numeros de nops
  wire [ 2:0] op_count;  // número de operações a serem executadas
  wire        active_end = (nop_count == `T_RCD_RC);  // Aumentar NOPs para compensar T_RC
  wire        op_act_end = (nop_count == `CAS_LATENCY);  // 1 NOP após comando READ/WRITE

  // Estado da FSM
  reg [2:0] present_state, next_state;

  // contadores
  sync_parallel_counter #(
      .size(2),
      .init_value(0)
  ) nop_counter (
      .clock(clock),
      .reset(nop_count_reset),
      .load(1'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .load_value(2'b0),
      .value(nop_count)
  );
  sync_parallel_counter #(
      .size(25),
      .init_value(0)
  ) addr_counter (
      .clock(clock),
      .reset(1'b0),
      .load(address_load),
      .inc_enable(address_enable),
      .dec_enable(1'b0),
      .load_value(init_address),
      .value(address)
  );
  sync_parallel_counter #(
      .size(3),
      .init_value(0)
  ) op_counter (
      .clock(clock),
      .reset(op_cnt_reset),
      .load(1'b0),
      .inc_enable(op_cnt_enable),
      .dec_enable(1'b0),
      .load_value(3'b0),
      .value(op_count)
  );

  // estados da FSM
  localparam reg [2:0] Idle = 3'h0, Start = 3'h1,  // inicialização -> evitar glitchs com Idle
  PreActive = 3'h2,  // Prepara o próximo dqm
  Active = 3'h3,  // Ativar o banco com a linha escolhida
  ActiveNop = 3'h4,  // NOP 2 vezes após ACTIVE
  OpAct = 3'h5,  // Ativar operação
  OpNop = 3'h6,  // NOP 3 vezes
  OpEnd = 3'h7;  // Último ciclo da operação

  // lógica de transição de estados
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // comando a ser executado pela SDRAM
  assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;

  // Habilitar o MSB e o LSB do barramento de dados da SDRAM
  assign {dram_udqm, dram_ldqm} = dqm;

  assign {bank, row, column} = address;

  assign ops_end = ~(|(op_count ^ op_num));  // compara op_count com op_num

  // Escrevendo no barramento bidirecional
  // LSB(10: O LSB está no MSB do write_data)
  assign dram_dq[7:0]  = (writing & ~dqm[0]) ?
                (dqm[1] ? write_data[63:56] : write_data[55:48]) : {8{1'bz}};
  assign dram_dq[15:8] = (writing & ~dqm[1]) ? write_data[63:56] : {8{1'bz}};  // MSB

  assign rd_data_o = read_data;

  // Registrador de leitura
  register_d #(
      .N(64),
      .reset_value(0)
  ) read_data_reg (
      .clock(clock),
      .reset(rd_data_reset),
      .enable(reading),
      .D(shift_read_data),
      .Q(read_data)
  );
  // Multiplexador para determinar o valor lido a partir do op_dqm
  // op_dqm: 00 -> ler 2 bytes; 01: ler MSB; 10: ler LSB; 11: manter valor antigo
  gen_mux #(
      .size(64),
      .N(2)
  ) read_data_mux (
      .A({
        read_data,
        {read_data[55:0], dram_dq[7:0]},
        {read_data[55:0], dram_dq[15:8]},
        {read_data[47:0], dram_dq}
      }),
      .S(op_dqm),
      .Y(shift_read_data)
  );

  // Registrador de escrita -> Altera valor na carga inicial ou após a escrita
  register_d #(
      .N(64),
      .reset_value(0)
  ) write_data_reg (
      .clock(clock),
      .reset(1'b0),
      .enable(wr_data_load | writing),
      .D(shift_write_data),
      .Q(write_data)
  );
  // Multiplexador para determinar o próximo valor a ser escrito a partir do op_dqm e do wr_data_load
  // load: 1 -> wr_data_i; op_dqm: 00 -> escrever 2 bytes; 01: escrever MSB; 10: escrever LSB; 11: atualizar com wr_data_i
  gen_mux #(
      .size(64),
      .N(2)
  ) write_data_mux (
      .A({
        wr_data_i, {write_data[55:0], 8'b0}, {write_data[55:0], 8'b0}, {write_data[47:0], 16'b0}
      }),
      .S(op_dqm | {2{wr_data_load}}),
      .Y(shift_write_data)
  );

  // op_dqm -> reset : op_dqm = 2'b11
  register_d #(
      .N(2),
      .reset_value(3)
  ) op_dqm_reg (
      .clock(clock),
      .reset(reset),
      .enable(op_dqm_en),
      .D(op_dqm_mux_out),
      .Q(op_dqm)
  );

  gen_mux #(
      .size(2),
      .N(2)
  ) op_dqm_mux (
      .A({2'b00, {init_dqm[0], init_dqm[1]}, init_dqm, 2'b11}),
      .S(op_dqm_src),
      .Y(op_dqm_mux_out)
  );

  // lógica de saída e de próximo estado
  always @(*) begin
    end_op          = 0;
    nop_count_reset = 0;
    address_load    = 0;
    address_enable  = 0;
    op_cnt_reset    = 0;
    op_cnt_enable   = 0;
    writing         = 0;
    reading         = 0;
    rd_data_reset   = 1'b0;
    wr_data_load    = 1'b0;
    command         = 4'b0111;
    dram_addr       = 0;
    dram_ba         = 2'b00;
    dqm             = 2'b11;
    op_dqm_en       = 0;
    op_dqm_src      = 2'b00;
    case (present_state)  // synthesis parallel_case
      Idle: begin
        command         = 4'b0111;  // NOP
        dram_addr       = 0;  // don't care
        dram_ba         = 2'b00;  // don't care
        dqm             = 2'b11;  // Barramento desabilitado
        address_load    = 1'b1;  // Carregar endereço inicial da operação
        op_cnt_reset    = 1'b1;  // Resetar contador da operação
        nop_count_reset = 1'b1;  // Resetar o contador de NOPs
        if (rd_enable == 1'b1 || wr_enable == 1'b1) next_state = Start;
        else next_state = Idle;
      end
      Start: begin  // uso para evitar glitches dos resets
        op_cnt_reset    = 1'b1;  // Resetar contador da operação
        nop_count_reset = 1'b1;  // Resetar o contador de NOPs
        rd_data_reset   = 1'b1;  // limpar o registrador de leitura
        wr_data_load    = 1'b1;  // limpar o registrador de escrita
        next_state      = PreActive;
      end
      PreActive: begin  // Ciclo anterior ao Active -> Decide como será a operação
        command   = 4'b0111;  // NOP
        dram_addr = 0;  // don't care
        dram_ba   = 2'b00;  // don't care
        dqm       = 2'b11;  // Barramento desabilitado
        op_dqm_en = 1'b1;  // atualizar op_dqm
        if (op_count == 0) op_dqm_src = 2'b01;  // DQM inicial
        else if (ops_end == 1'b1)
          op_dqm_src = 2'b10;  // ultima operação -> inverso da inicial(valores válidos: 00 e 01)
        else op_dqm_src = 2'b11;  // Caso contrário: habilitar todo o barramento
        next_state = Active;
      end
      Active: begin  // Ativar o banco com a linha escolhida
        command         = 4'b0011;  // Ativar
        dram_addr       = row;  // Linha desejada
        dram_ba         = bank;  // Banco escolhido
        dqm             = 2'b11;  // Barramento desabilitado
        nop_count_reset = 1'b1;
        next_state      = ActiveNop;
      end
      ActiveNop: begin  // 4 NOPs após Active -> Tras
        command   = 4'b0111;  // NOP
        dram_addr = 0;  // don't care
        dram_ba   = 2'b00;  // don't care
        dqm       = 2'b11;  // Barramento desabilitado
        if (active_end == 1'b1) next_state = OpAct;  // 2 NOPs -> Read
        else next_state = ActiveNop;  // Não deu 2 NOPs
      end
      OpAct: begin
        if (rd_enable == 1'b1) command = 4'b0101;  // Ativar leitura
        else begin
          command = 4'b0100;  // Ativar escrita
          writing = 1'b1;
        end
        dram_ba          = bank;
        dram_addr[12:11] = 2'b00;  // don't care
        dram_addr[10]    = 1'b1;  // 64 bits -> Auto Precharge
        dram_addr[9:0]   = column;
        dqm              = op_dqm;  // 2 bytes
        nop_count_reset  = 1'b1;
        next_state       = OpNop;
      end
      OpNop: begin
        command   = 4'b0111;  // NOP
        dram_addr = 0;  // don't care
        dram_ba   = 2'b00;  // don't care
        dqm       = 2'b11;  // Barramento desabilitado
        if (op_act_end == 1'b1) next_state = OpEnd;  // 2 NOPs -> Terminar a operação
        else next_state = OpNop;  // Não deu 2 NOPs
      end
      OpEnd: begin
        command        = 4'b0111;  // NOP
        dram_addr      = 0;  // don't care
        dram_ba        = 2'b00;  // don't care
        dqm            = 2'b11;  // Barramento desabilitado
        address_enable = 1'b1;  // Gerar novo endereço da próxima operação
        op_cnt_enable  = 1'b1;  // Incrementar o número de operações
        if (rd_enable == 1'b1) reading = 1'b1;  // Realizar leitura
        if (ops_end == 1'b1) begin
          end_op     = 1'b1;  // Fim das operações
          next_state = Idle;
        end else next_state = PreActive;  // Ir para a próxima operação
      end
      default: begin  // Impossível
        next_state = Idle;
      end
    endcase
  end
endmodule
