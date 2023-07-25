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
    output [15:0] test_driver_state
);

  localparam reg [0:4095] DataBlock0 = 4096'h05daad417c06b4988d0ed93195dc28249affd7c230ddb0f349a009c966088218b3ef1f0d0d0a57bf013438f57aa771268dd41d15c54bb440a27e14c5ca5ed4c9c7723229113da7203f8af77d2b5675ca8792284d7c2d19b24c535b49a2a31503c771576ee4084ab6a71f3035dec4f72bf31af9555eacedabf87379ea80ed14825cdf884f05d276208478f17ed6d904828346bc0f73a0eb9cc4bd96a8bc763691f0fbccab8f94deb5a00db71885e23091eade80df60ade0157e84a1484a2512416ad92778356f579ca1c1b26378abd8d53d2dd62e958292bd2b37f54c5b72682440d514b051d09eacae3b4e7fd946e655add14b67917e0d3eb376ae1778cb109ace3db82c6b018806e11e8c276071dc0b6c90e7a53428a8e8e0d55a176b44a16975ef35423dd5881d532b44144883745836ed284cbcbd503e2b8400932c0874795367986c16813433f65021133303055e8bb403ee0c30b59428adda02d7c2567684c1bb8e293948d5a122b1513f1cd4c87e6a9452d25634a67932374e94c12f01baf5862773de0fbe75e031e1d081d36e903f7e46c15a07bb06993dcafb415cae1f3f9308db4170eb981f535a0cad77b0f11c7570da1f8f28547d1a4ae6b5f4c8e9456d62e804330b9eed69b3d2211ca329e0806fd22cb94162dd377165883e63751019e012911bae9e3023375c00ea92ee38b407c8e5bbfadfe12bdfec7537fb;
  localparam reg [0:4095] DataBlock1 = 4096'h2e129e2f1a029660666f1d2a135a09cb26daf32265e08216dd50940da8db8b2f522993be002226c666ee4fb2db21a10dca410354953d411fcecaa25307c9c2923aeadd5a65073789aa05357c9980e89dab7eb99d00c6ae526a6e57f6fbbd8fbb0252e769b36cfad7978a6b47cf587a3e32112507c916c7cd0fc9fb4a5c41dac3b2c73e589e62f7352ffca540ab5398892785d59b120cae22dc1d7adedae4ca5be5c908e4afc942103787419e2def9561b9515fc65558871972beb2e6e1e1aca1fe13d0cd651dd9f640301086d58c5925a10c2492e600b89825b57276d75b688f7ab8fb5ad2a0ccfd0e2c7231d598cdfb55f40535caf70213083e728fd327212d66cb741c80fb9e84030848e4845d6911d1f6e0432caccbc132fe953ba9a0f1b3e53277f7e5ea9d213e91c099745316bea9df6131b911e78298ec5c9cb31a0d3df845618a312bb84926cd1570dd5fe84531b7fde3d2eebf6cf97a761c488f1a465d899fe45eae213c21ca7fe5194512ee310768561a981cef8a399db911590959819bd1b7651cada7cc4ad7db72303559a60cb59fa1d8dcc9d8e482105492a54b27943b10673fdba5b60f7dbd67e0c3f702379e9fc2184de55b0126e048cf52836f649aa123f3e1ed78ad5263758cdf730e7226f629cb3afbe5d272189a1395a01f4de17a9e7e8250cb1cf630dbb1be276147ee982609dfa4bdaac081e453cae0;
  localparam reg [0:4095] DataBlock2 = 4096'h1d1565574afeb510a4671ea3286dd41aead0526722f5ad922587699ea610fef046b4dc998083d4dcd4c729d199c574fc5623b95cf498bd57944e133dfadd623bc211b44940944d4ca0420441bda03864b2b66219621c8bfe77f1e8534006e3d8e0b59795c2fc1528d7a0cbc504e7f73f1b7746a5d2d713b8e2b62a72133e9057de4cdb4cbaa9e65540c6102d3ddcd18a54a9cc18a42c1db7fbc1b4d669fe834942984aa8ed8bea0dcf52f77339a27e3d474576b953679868858a5afa5b4dae4eca31805d1b7bf84116b8f1ba32d770a31e3fb4f259f514607cf8a34aa0ef39cc10b121e2957b98632250057658cda6aebcdaad37e57231eea400aa64210e17db9f6102eec51f390bbaf2bb6e17659d422408ad9b5c16d5bdb9b2ef48fa1407eab3b07d85e5b2aaa3fba13d8b32fb9e6068198bd5c5547810bd5e35c20555429260a5c202954222ce17f8a653ab3cf9c3d2b306fd1fe5667b3ecf0eebf7be2be3f0e5f3f180e6d9300b59beb3765ea5cb37f6e8b5d1b8c084f70f1363c3b0b0604929911bc224c761de578c9e9a91f485a850015025169d3e9a51665e097514534fe3afcce35606634cf3fb9158dec2bd5b4866a209aefc235c0e14a1a98de05579281a3d1122be8d9951fb7759899bef1c6b20c8215f254d2585e5d8baf87032fe3f9576b49e7d5e7865ae8be215032a602e75183e6888630a99783278eb6e0d;
  localparam reg [0:4095] DataBlock3 = 4096'h03db202452f4ce90559e15064266dab90259b76f767a10654128365e6a7e6c4dff2792a94ec6d7eb56e317404c6ff81f96420a6a39f3e9e620d89f352cb3229400a41ba7a4168593b7d92ef012c9eab4bbeb95ed87969e44f2e8bb9c5ee50b1cfeadedb145045d4303749e202c93edce9f2ee5c1e2073fc495ba1323474d843f34d6ab7f7ab142ea3be84b8dfa94c33fc1653457ab9b17353c2f78f36de7e2af249a487b5afd2aee1d47d110c0353ee24119622efd2ca7d041f885122700c268148b4a23fe1763667023d0316fdc8e2225b04bfc96a7ad1886d73694f591c0f8265b39475e4c52b7ea39098440a5679e80de66aeab23ecd6df6c69ed08fdd8f876772655d86828fbc320dcc14321fd62e01d4eb3e1009d06c754cc2b18229b8de57b8f6d072e8f3f37ea9989ed3e2500e3eec30e755b72847a4dc2d6356ed9276ae2673821579ade5ae428e82e2873d108d6b500d0f8a8e4c5ce7ac5c14eae804b65b0f530565078c0366d969abea9112ce82c14836feff29fc6c6900ffa986718f62361637b9efd2c0e9f32b6e98f4aa58eaff2caf0b3e7d7fb96bae350c2ea24c79f61d08aeae278c8e11273a4b3191953609e600ffd80c78fd5789dd62ac79b396991abcc84e28103343fa86296c1c0908743ac26c9091fc2805ada00f2299229887476d524b1e44c004232148e8adc896f76ab82b0794cab5e6b7bebfb86;
  reg [4095:0] expected_data_block, next_expected_data_block;

  localparam reg [31:0] Address0 = 32'h0;
  localparam reg [31:0] Address1 = 32'h1;
  localparam reg [31:0] Address2 = 32'h2;
  localparam reg [31:0] Address3 = 32'h3;

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

  reg state_vars_enable;

  /* lógica de mudança de estados */
  always @(posedge clock) begin
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

  always @(*) begin
    rd_en                    = 1'b0;
    addr                     = 32'h00000000;
    state_vars_enable        = 1'b0;
    next_state_return        = Test0;
    next_addr_reg            = Address0;
    next_expected_data_block = DataBlock0;

    case (state)
      Test0: begin
        next_state               = ReadDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test1;
        next_addr_reg            = Address0;
        next_expected_data_block = DataBlock0;
      end

      Test1: begin
        next_state               = ReadDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test2;
        next_addr_reg            = Address1;
        next_expected_data_block = DataBlock1;
      end

      Test2: begin
        next_state               = ReadDataBlock;
        state_vars_enable        = 1'b1;
        next_state_return        = Test3;
        next_addr_reg            = Address2;
        next_expected_data_block = DataBlock2;
      end

      Test3: begin
        next_state               = ReadDataBlock;
        state_vars_enable        = 1'b1;
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
        rd_en = 1'b1;
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
