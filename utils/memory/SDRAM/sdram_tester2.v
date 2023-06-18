//
//! @file   sdram_tester2.v
//! @brief  Circuito para testar o SDRAM Controller(DE10-Lite) com Clock = 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-06-15
//

module sdram_tester2 #(
    parameter integer CLOCK_FREQ_HZ = 50000000  // 50MHz
) (
    // Usuário
    input  wire        clock,       // 200 MHz
    input  wire        reset_n,     // KEY0
    output wire        check_op,    // LEDR0: 1 -> operação bem sucedida
    output wire [ 2:0] state,       // depuração: LEDR1 - LEDR3
    // SDRAM
    output wire        dram_clk,
    output wire        dram_cke,
    output wire [12:0] dram_addr,
    output wire [ 1:0] dram_ba,
    output wire        dram_cs_n,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,
    output wire        dram_ldqm,
    output wire        dram_udqm,
    inout  wire [15:0] dram_dq
);

  localparam integer OneSecSize = $clog2(CLOCK_FREQ_HZ);
  // Sinais do Controlador
  wire reset;
  reg rd_enable;
  reg wr_enable;
  wire [25:0] address;
  wire [1:0] rd_wr_size;
  wire [63:0] write_data;
  wire busy;
  wire [63:0] read_data;
  // Auxiliares para gerar os sinais da SDRAM
  wire [25:0] _address;
  wire [1:0] _rd_wr_size;
  wire [63:0] _write_data;
  wire [63:0] xor_data;  // _xor_data após o mux
  wire [63:0] _xor_data;
  // Sinais de Controle dos Contadores e Registradores
  reg data_size_rst;
  reg data_size_en;
  reg address_en;
  reg write_data_en;
  reg one_sec_rst;
  // Contador de 1s
  wire [OneSecSize-1:0] cte_0 = 0;
  wire [OneSecSize-1:0] one_sec_count;
  wire one_sec;
  // FSM
  reg [2:0] present_state, next_state;  // FSM

  // Estados da FSM
  localparam reg [2:0]
        Idle      = 3'h0,
        StartOp   = 3'h1,
        StartWrite  = 3'h2,
        EndWrite  = 3'h3,
        StartRead   = 3'h4,
        EndRead   = 3'h5,
        AfterRead  = 3'h6,
        EndTest   = 3'h7;

  // Assigns gerais
  assign reset = ~reset_n;
  assign _xor_data = write_data ^ read_data;
  assign check_op = ~(|(xor_data));  // Dado lido = Dado escrito
  assign one_sec = (one_sec_count == (CLOCK_FREQ_HZ - 1));  // Passou 1s
  assign state = present_state;  // depuração

  // Multiplexador para determinar o check_op com base no tamanho da operação
  gen_mux #(
      .size(64),
      .N(2)
  ) read_mux (
      .A({
        _xor_data,  // 64 bits
        {32'b0, _xor_data[31:0]},  // 32 bits
        {48'b0, _xor_data[15:0]},  // 16 bits
        {56'b0, _xor_data[7:0]}  // 8 bits
      }),
      .S(rd_wr_size),
      .Y(xor_data)
  );

  // Contadores para gerar as entradas da SDRAM
  // Testar todas as 8 possibilidades de escrita/leitura
  sync_parallel_counter #(
      .size(3),
      .init_value(3'b0)
  ) data_size_cnt (
      .clock(clock),
      .reset(data_size_rst),
      .load(1'b0),
      .inc_enable(data_size_en),
      .dec_enable(1'b0),
      .load_value(3'b0),
      .value({_rd_wr_size, _address[0]})
  );

  // Gerar endereço "aleatório"
  sync_parallel_counter #(
      .size(25),
      .init_value(25'b0)
  ) address_cnt (
      .clock(clock),
      .reset(reset),
      .load(1'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .load_value(25'b0),
      .value(_address[25:1])
  );

  // Gerar dado "aleatório"
  sync_parallel_counter #(
      .size(64),
      .init_value(64'hEFEFCDF8)  // algum valor qualquer
  ) write_data_cnt (
      .clock(clock),
      .reset(reset),
      .load(1'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .load_value(64'b0),
      .value(_write_data)
  );

  // Contador de 1s -> permitir a visualização do check_op
  sync_parallel_counter #(
      .size(OneSecSize),
      .init_value(0)
  ) one_sec_cnt (
      .clock(clock),
      .reset(one_sec_rst),
      .load(1'b0),
      .inc_enable(1'b1),
      .dec_enable(1'b0),
      .load_value(cte_0),
      .value(one_sec_count)
  );

  // Buffers das entradas da SDRAM
  register_d #(
      .N(3),
      .reset_value(3'b0)
  ) data_size_reg (
      .clock(clock),
      .reset(reset),
      .enable(data_size_en),
      .D({_rd_wr_size, _address[0]}),
      .Q({rd_wr_size, address[0]})
  );

  register_d #(
      .N(25),
      .reset_value(25'b0)
  ) address_reg (
      .clock(clock),
      .reset(reset),
      .enable(address_en),
      .D(_address[25:1]),
      .Q(address[25:1])
  );

  register_d #(
      .N(64),
      .reset_value(64'hFFFFFFFF)  // algum valor qualquer
  ) write_data_reg (
      .clock(clock),
      .reset(reset),
      .enable(write_data_en),
      .D(_write_data),
      .Q(write_data)
  );

  // Controlador da SDRAM
  sdram_controller Controlador (
      .clock(clock),
      .reset(reset),
      .rd_enable(rd_enable),
      .wr_enable(wr_enable),
      .address(address),
      .rd_wr_size(rd_wr_size),
      .write_data(write_data),
      .busy(busy),
      .read_data(read_data),
      .dram_clk(dram_clk),
      .dram_cke(dram_cke),
      .dram_addr(dram_addr),
      .dram_ba(dram_ba),
      .dram_cs_n(dram_cs_n),
      .dram_ras_n(dram_ras_n),
      .dram_cas_n(dram_cas_n),
      .dram_we_n(dram_we_n),
      .dram_ldqm(dram_ldqm),
      .dram_udqm(dram_udqm),
      .dram_dq(dram_dq)
  );

  // FSM
  // transição de estados
  always @(posedge clock, posedge reset) begin
    if (reset) present_state <= Idle;
    else present_state <= next_state;
  end

  // lógica de saída
  always @(*) begin
    rd_enable = 1'b0;
    wr_enable = 1'b0;
    data_size_rst = 1'b0;
    data_size_en = 1'b0;
    address_en = 1'b0;
    write_data_en = 1'b0;
    one_sec_rst = 1'b0;
    case (present_state)
      Idle: begin
        data_size_rst = 1'b1;
        one_sec_rst = 1'b1;
        next_state = StartOp;
      end
      StartOp: begin
        data_size_en = 1'b1;
        address_en = 1'b1;
        write_data_en = 1'b1;
        next_state = StartWrite;
      end
      StartWrite: begin  // Inicia a escrita
        wr_enable  = 1'b1;
        next_state = EndWrite;
      end
      EndWrite: begin
        wr_enable   = 1'b1;
        one_sec_rst = 1'b1;
        // Busy deve levantar na transição StartWrite -> EndWrite
        if (busy == 1'b0) next_state = StartRead;
        else next_state = EndWrite;
      end
      StartRead: begin
        rd_enable  = 1'b1;
        next_state = EndRead;
      end
      EndRead: begin
        rd_enable   = 1'b1;
        one_sec_rst = 1'b1;
        // Busy deve levantar na transição StartRead -> EndRead
        if (busy == 1'b0) next_state = AfterRead;
        else next_state = EndRead;
      end
      // Esperar 1s para visualizar o check_op no LED
      AfterRead: begin
        if (one_sec == 1'b1) begin
          // Os 8 testes foram realizados
          if ({rd_wr_size, address[0]} == 3'b111) next_state = EndTest;
          else next_state = StartOp;
        end else next_state = AfterRead;
      end
      EndTest: begin
        next_state = EndTest;  // Trava a FSM
      end
      default: begin  // Inalcançável
        next_state = Idle;
      end
    endcase
  end

endmodule
