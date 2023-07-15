//
//! @file   sd_controller_test_driver.v
//! @brief  Teste de uma implementação de um controlador de SD
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-07-14
//

module sd_controller_test_driver (
    /* sinais de sistema */
    input clock,
    input reset,

    /* interface com o controlador  */
    input [4095:0] read_data,
    input busy,
    output reg rd_en,
    output reg [31:0] addr,

    /* depuração */
    output test_driver_state

);

  localparam reg [4095:0] DataBlock0 = 4096'h0;
  localparam reg [4095:0] DataBlock1 = 4096'h0;
  localparam reg [4095:0] DataBlock2 = 4096'h0;
  localparam reg [4095:0] DataBlock3 = 4096'h0;
  reg [4095:0] expected_data_block, next_expected_data_block;

  localparam reg [31:0] Address0 = 32'h0;
  localparam reg [31:0] Address1 = 32'h0;
  localparam reg [31:0] Address2 = 32'h0;
  localparam reg [31:0] Address3 = 32'h0;

  localparam reg [15:0]
    Test0         = 16'h0000,
    Test1         = 16'h0001,
    Test2         = 16'h0002,
    Test3         = 16'h0003,
    ReadDataBlock = 16'h0004,
    WaitRead      = 16'h0005,
    TestRead      = 16'h0006,
    ReadError     = 16'hFFFE,
    TestEnd       = 16'hFFFF;
  reg [15:0] state, next_state, state_return, next_state_return;

  reg [31:0] addr_reg, next_addr_reg;

  /* lógica de mudança de estados */
  always @(posedge clk) begin
    if (reset) begin
      state               <= Test0;
      state_return        <= Test0;
      addr_reg            <= 32'h0;
      expected_data_block <= 4096'h0;
    end else begin
      state               <= next_state;
      state_return        <= next_state_return;
      addr_reg            <= next_addr_reg;
      expected_data_block <= next_expected_data_block;
    end
  end

  always @(*) begin
    rd_en = 1'b0;
    addr  = 32'h00000000;

    case (state)
      Test0: begin
        next_state               = ReadDataBlock;
        next_state_return        = Test1;
        next_addr_reg            = Address0;
        next_expected_data_block = DataBlock0;
      end

      Test1: begin
        next_state               = ReadDataBlock;
        next_state_return        = Test2;
        next_addr_reg            = Address1;
        next_expected_data_block = DataBlock1;
      end

      Test2: begin
        next_state               = ReadDataBlock;
        next_state_return        = Test3;
        next_addr_reg            = Address2;
        next_expected_data_block = DataBlock2;
      end

      Test3: begin
        next_state               = ReadDataBlock;
        next_state_return        = TestEnd;
        next_addr_reg            = Address3;
        next_expected_data_block = DataBlock3;
      end

      ReadDataBlock: begin
        rd_en = 1'b1;
        addr  = addr_reg;
        if (busy) next_state = WaitRead;
        else next_state = state;
      end

      WaitRead: begin
        if (busy) next_state = state;
        else next_state = TestRead;
      end

      TestRead: begin
        if (read_data == expected_data_block) next_state = state_return;
        else next_state = ReadError;
      end

      default: next_state = Test0;
    endcase

  end

  assign test_driver_state = state;

endmodule
