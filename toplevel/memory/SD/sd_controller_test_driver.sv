
module sd_controller_test_driver (
    /* sinais de sistema */
    input clock,
    input reset,

    /* interface com o controlador  */
    wishbone_if.primary wb_if_p,

    /* depuração */
    output [15:0] test_driver_state,
    output [15:0] test_driver_state_return
);

  import sd_controller_test_driver_pkg::*;

  reg [4095:0] expected_data_block, next_expected_data_block;

  sd_controller_test_driver_fsm_t state, next_state, state_return, next_state_return;

  reg [31:0] addr_reg, next_addr_reg;

  reg state_vars_enable;

  /* lógica de mudança de estados */
  always @(posedge clock, posedge reset) begin
    if (reset) begin
      state               <= Test0;
      state_return        <= Test0;
      addr_reg            <= 32'h0;
      expected_data_block <= 4096'h0;
    end else begin
      state <= next_state;
      if (state_vars_enable) begin
        state_return        <= next_state_return;
        addr_reg            <= next_addr_reg;
        expected_data_block <= next_expected_data_block;
      end else begin
        state_return        <= state_return;
        addr_reg            <= addr_reg;
        expected_data_block <= expected_data_block;
      end
    end
  end

  always_comb begin
    wb_if_p.cyc            = 1'b0;
    wb_if_p.stb            = 1'b0;
    wb_if_p.we             = 1'b0;
    wb_if_p.addr           = 32'h00000000;
    state_vars_enable        = 1'b0;
    next_state_return        = Test0;
    next_addr_reg            = Address0;
    next_expected_data_block = DataBlock0;
    wb_if_p.dat_o_p        = 4096'h0;

    unique case (state)
      Test0: begin
        next_state               = WriteDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test1;
        next_addr_reg            = Address0;
        next_expected_data_block = DataBlock0;
      end

      Test1: begin
        next_state               = WriteDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test2;
        next_addr_reg            = Address1;
        next_expected_data_block = DataBlock1;
      end

      Test2: begin
        next_state               = WriteDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test3;
        next_addr_reg            = Address2;
        next_expected_data_block = DataBlock2;
      end

      Test3: begin
        next_state               = WriteDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = TestEnd;
        next_addr_reg            = Address3;
        next_expected_data_block = DataBlock3;
      end

      WriteDataBlock: begin
        wb_if_p.cyc        = 1'b1;
        wb_if_p.stb        = 1'b1;
        wb_if_p.we         = 1'b1;
        wb_if_p.dat_o_p    = expected_data_block;
        wb_if_p.addr       = addr_reg;
        if (wb_if_p.ack) next_state  = ReadDataBlock;
        else next_state      = state;
      end

      ReadDataBlock: begin
        wb_if_p.cyc  = 1'b1;
        wb_if_p.stb  = 1'b1;
        wb_if_p.we   = 1'b0;
        wb_if_p.addr = addr_reg;
        if (wb_if_p.ack) next_state = TestRead;
        else next_state = state;
      end

      TestRead: begin
        if (wb_if_p.dat_i_p == expected_data_block) next_state = state_return;
        else next_state = ReadError;
      end

      TestEnd: begin
        next_state = state;
      end

      ReadError: begin
        next_state = state;
      end

      default: next_state = Test0;
    endcase
  end

  assign test_driver_state = state;
  assign test_driver_state_return = state_return;

endmodule
