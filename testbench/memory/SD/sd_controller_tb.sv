
module sd_controller_tb ();

  import macros_pkg::*;
  import sd_receiver_pkg::*;
  import sd_sender_pkg::*;
  import sd_controller_pkg::*;

  // Parâmetros do testbench
  localparam integer AmntOfTests = 40;
  localparam integer Clock50MPeriod = 6;
  localparam integer Seed = 103;
  localparam integer SDSC = 1;

  // Sinais do DUT
  reg clock;
  reg reset;
  reg cyc, stb, wr;
  reg [31:0] addr;
  wire [4095:0] read_data;
  reg [4095:0] write_data;
  wire miso;
  wire cs;
  wire sck;
  wire mosi;
  wire ack;
  wishbone_if #(.DATA_SIZE(4096), .BYTE_SIZE(8), .ADDR_SIZE(32)) wb_if (.*);
  // Sinais do modelo do cartão
  wire cmd_error;
  // Sinais auxiliares
  reg generate_write_data;
  reg [1:0] teste;  // 00: Reset, 01: Init, 10: Read, 11: Write

  integer i;

  sd_controller #(
      .SDSC(SDSC)
  ) DUT (
      .wb_if_s(wb_if),
      .miso(miso),
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .sd_controller_state_db(),
      .sd_receiver_state_db(),
      .sd_sender_state_db(),
      .check_cmd_0_db(),
      .check_cmd_8_db(),
      .check_cmd_55_db(),
      .check_cmd_59_db(),
      .check_acmd_41_db(),
      .check_cmd_16_db(),
      .check_cmd_24_db(),
      .check_write_db(),
      .check_cmd_13_db(),
      .check_cmd_17_db(),
      .check_read_db(),
      .check_error_token_db(),
      .crc_error_db(),
      .crc16_db()
  );

  sd_model #(
      .SDSC(SDSC)
  ) sd_card (
      .cs(cs),
      .sck(sck),
      .mosi(mosi),
      .miso(miso),
      .expected_addr(addr),
      .cmd_error(cmd_error)
  );

  // Wishbone
  assign wb_if.cyc = cyc;
  assign wb_if.stb = stb;
  assign wb_if.we = wr;
  assign wb_if.addr = addr;
  assign wb_if.dat_o_p = write_data;
  assign read_data = wb_if.dat_i_p;
  assign ack = wb_if.ack;

  always #(Clock50MPeriod / 2) clock = ~clock;

  task automatic CheckInitialization;
    begin
      teste = 2'b01;
      // Inicialização do cartão SD
      while (DUT.state != sd_controller_pkg::Idle) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock);
        // Checar se não há erro de CRC7
        CHK_CMD_ERROR_INIT: assert(cmd_error === 1'b0);
        @(negedge clock);
      end
    end
  endtask

  task automatic CheckRead;
    begin
      teste = 2'b10;
      while (!ack) begin
        // Checo na subida, pois o clock do sd_card é invertido
        @(posedge clock);
        // Checar se não há erro
        CHK_CMD_ERROR_READ: assert(cmd_error === 1'b0);
        // Confiro ack na borda de descida
        @(negedge clock);
        // Enables não são mais relevantes
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end
      cyc = 1'b0;
      stb = 1'b0;
      wr  = 1'b0;
      // Após leitura checa o dado lido e se houve algum erro
      CHK_CMD_ERROR_READ_END: assert(cmd_error === 1'b0);
      if (!sd_card.random_error_flag)
        CHK_READ_DATA_READ_END: assert(read_data === sd_card.data_block);
    end
  endtask

  event   write_data_event;
  integer j;
  always @(write_data_event) begin
    for (j = 0; j < 128; j = j + 1) begin
      write_data[32*j+:32] <= $urandom;
    end
  end

  task automatic CheckWrite;
    begin
      teste = 2'b11;
      while (!ack) begin
        @(posedge clock);
        // Checar se não há erro
        CHK_CMD_ERROR_WRITE: assert(cmd_error === 1'b0);
        // Confiro ack na borda de descida
        @(negedge clock);
        // Enables não são mais relevantes
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end
      cyc = 1'b1;
      stb = 1'b1;
      wr  = 1'b0;
      // Após leitura checa o dado lido e se houve algum erro
      CHK_CMD_ERROR_WRITE_END: assert(cmd_error === 1'b0);
      if (!sd_card.random_error_flag)
        CHK_WRITE_DATA_WRITE_END: assert(write_data === sd_card.received_data_block);
    end
  endtask

  // Initial para estimular o DUT
  initial begin
    {clock, reset, cyc, stb, wr, addr, generate_write_data, teste} = 0;
    // Reset inicial
    @(negedge clock);
    reset = 1'b1;
    @(negedge clock);
    reset = 1'b0;
    cyc = $urandom(Seed);
    stb = $urandom;
    wr = $urandom;
    addr = $urandom;
    ->write_data_event;
    @(negedge clock);

    $display(" SOT: [%0t]", $time);

    CheckInitialization;  // Confere Inicialização do cartão

    $display(" Initialization Complete: [%0t]", $time);

    @(negedge clock);

    // Realizar leituras
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      if (cyc && stb && !wr) begin
        CheckRead;  // Confere a leitura
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end else if (cyc && stb && wr) begin
        CheckWrite;  // Confere a escrita
      end else begin
        cyc = $urandom;
        stb = $urandom;
        wr  = $urandom;
      end

      addr = $urandom;
      if (cyc && stb && wr) begin
        ->write_data_event;
      end
      teste = 2'b00;
      wait (DUT.state == sd_controller_pkg::Idle);  // Wait handshake between controller and sd card
      @(negedge clock);
    end

    $display("EOT: [%0t]", $time);
    $stop;
  end

endmodule
