//
//! @file   instruction_cache_tb.v
//! @brief  Testbench de um cache para uma memória
//          ROM de instruções alinhada em 16 bits
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-05-02
//

`timescale 1 ns / 100 ps

`define ASSERT(condition, message) \
  if (!(condition)) \
  begin \
    $display(message); \
    $stop; \
  end

module instruction_cache_tb ();

  localparam integer AmntOfTests = 10000;
  localparam integer ClockPeriod = 10;
  localparam integer BusyCycles = 3;

  localparam integer L2CacheSize = 4;
  localparam integer L2BlockSize = 2;
  localparam integer L2AddrSize = 3;
  localparam integer L2DataSize = 1;
  localparam integer Offset = L2BlockSize;
  localparam integer ByteOffset = L2DataSize;
  localparam integer BlockOffset = L2BlockSize - L2DataSize;
  localparam integer Index = L2CacheSize - Offset;
  localparam integer Tag = 2 ** (L2DataSize + 3) - Offset - Index;
  localparam integer Depth = 2 ** (L2CacheSize - L2BlockSize);

  /* Sinais do sistema */
  reg CLK_I;
  reg RST_I;
  /* //// */

  /* Interface com a memória de instruções */
  reg [2**(L2BlockSize+3)-1:0] inst_DAT_I;
  reg inst_ACK_I;
  wire inst_CYC_O;
  wire [2**L2AddrSize-1:0] inst_ADR_O;
  /* //// */

  /* Interface com o controlador de memória */
  reg inst_cache_CYC_I;
  reg [2**L2AddrSize-1:0] inst_cache_ADR_I;
  wire [2**(L2DataSize+3)-1:0] inst_cache_DAT_O;
  wire inst_cache_ACK_O;
  /* //// */

  // Cache local
  reg [2**(L2BlockSize+3)-1:0] cache_data[2**(L2CacheSize-L2BlockSize)-1:0];
  reg [Tag-1:0] cache_tag[Depth-1:0];
  reg [Depth-1:0] cache_valid;

  // Sinais intermediários
  wire [Index-1:0] index = inst_cache_ADR_I[Index+Offset-1:Offset];
  wire [Tag-1:0] tag = inst_cache_ADR_I[2**L2AddrSize-1:Index+Offset];
  wire [(Offset>0 ? Offset-1 : 0):0] offset = Offset > 0 ? inst_cache_ADR_I[Offset-1:0] : 0;
  wire [(ByteOffset>0 ? ByteOffset-1 : 0):0] byte_offset = ByteOffset > 0 ? offset[ByteOffset-1:0] : 0;
  wire [(BlockOffset>0 ? BlockOffset-1 : 0):0] block_offset = BlockOffset > 0 ? offset[Offset-1:ByteOffset] : 0;
  event busy_event;
  always @(busy_event) begin
    inst_ACK_I = ~inst_ACK_I;
  end

  instruction_cache #(
      .L2_CACHE_SIZE(L2CacheSize),  // log_2(tamanho da cache em bytes)
      .L2_BLOCK_SIZE(L2BlockSize),  // log_2(tamanho do bloco em bytes)
      .L2_ADDR_SIZE (L2AddrSize),   // log2(bits de endereço)
      .L2_DATA_SIZE (L2DataSize)    // log2(bytes de dados)
  ) DUT (
      /* Sinais do sistema */
      .CLK_I(CLK_I),
      .RST_I(RST_I),
      /* //// */

      /* Interface com a memória de instruções */
      .inst_DAT_I  (inst_DAT_I),
      .inst_ACK_I  (inst_ACK_I),
      .inst_CYC_O(inst_CYC_O),
      .inst_ADR_O  (inst_ADR_O),
      /* //// */

      /* Interface com o controlador de memória */
      .inst_cache_CYC_I(inst_cache_CYC_I),
      .inst_cache_ADR_I  (inst_cache_ADR_I),
      .inst_cache_DAT_O  (inst_cache_DAT_O),
      .inst_cache_ACK_O  (inst_cache_ACK_O)
      /* //// */
  );

  task assert_dut;
    begin
      `ASSERT(inst_cache_ACK_O === 1'b1, "\tinst_cache_busy !== 0b0")
      `ASSERT(
          cache_data[index][(block_offset+1)*(2**(ByteOffset+3))-1-:(2**(ByteOffset+3))] === inst_cache_DAT_O,
          "\tcache_data[index][(block_offset+1)*(2**(ByteOffset+3))-1-:(2**(ByteOffset+3))] !== inst_cache_DAT_O")
      `ASSERT(cache_tag[index] === DUT.path.cache_tag[index],
              "\tcache_tag[index] !== DUT.path.cache_tag[index]")
      `ASSERT(cache_valid[index] === DUT.path.cache_valid[index],
              "\tcache_valid[index] !== DUT.path.cache_valid[index]")
      `ASSERT(DUT.control.cache_WE_O === '0, "\tDUT.control.cache_WE_O !== 0b0")
    end
  endtask

  task doNothing(input integer test_case);
    begin
      $display("[%0t] doNothing start: test %d", $time, test_case);
      #ClockPeriod;
      $display("[%0t] doNothing end", $time);
      assert_dut();
      @(negedge CLK_I);
    end
  endtask

  task hitState(input integer test_case);
    begin
      $display("[%0t] hitState start: test %d", $time, test_case);
      `ASSERT(inst_cache_ACK_O === 1'b0, "\tinst_cache_busy !== 0b1")
      #ClockPeriod;
      $display("[%0t] hitState end", $time);
      assert_dut();
      @(negedge CLK_I);
    end
  endtask

  task missState(input integer test_case);
    begin
      $display("[%0t] missState start: test %d", $time, test_case);
      `ASSERT(inst_cache_ACK_O === 1'b0, "\tinst_cache_busy !== 0b1")
      /* inst_ACK_I = 1'b1; */
      -> busy_event;
      `ASSERT(DUT.control.cache_WE_O === inst_ACK_I,
              "\tDUT.control.cache_WE_O !== inst_ACK_I")
      fork
        begin
          #(BusyCycles * ClockPeriod) -> busy_event;
        end
        begin
          #(BusyCycles / 2.0 * ClockPeriod);
          cache_data[index]  = inst_DAT_I;
          cache_tag[index]   = tag;
          cache_valid[index] = 1'b1;
        end
      join
      #(ClockPeriod);
      $display("[%0t] missState end", $time);
      assert_dut();
      @(negedge CLK_I);
    end
  endtask


  always #(ClockPeriod/2) CLK_I = ~CLK_I;
  integer i;
  initial begin
    {CLK_I, RST_I, inst_DAT_I, inst_cache_CYC_I, inst_cache_ADR_I, cache_valid} = 0;
    inst_ACK_I = 1'b1;

    @(negedge CLK_I);
    RST_I = 1;
    @(negedge CLK_I);
    RST_I = 0;

    $display("[%0t] SOT", $time);

    // Teste de leitura da Cache
    @(negedge CLK_I);
    for (i = 0; i < AmntOfTests; i = i + 1) begin
      inst_DAT_I = $urandom;
      inst_cache_CYC_I = $urandom;
      inst_cache_ADR_I = $urandom;
      @(negedge CLK_I);

      if (inst_cache_CYC_I === 1'b1) begin
        if (cache_valid[index] === 1'b1 && tag === cache_tag[index]) begin
          hitState(i);
        end else begin
          missState(i);
        end
      end else begin
        doNothing(i);
      end
    end
    $display("[%0t] EOT", $time);
    $stop;
  end

endmodule
