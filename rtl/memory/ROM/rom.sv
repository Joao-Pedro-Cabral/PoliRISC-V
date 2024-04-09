
module rom #(
  parameter string ROM_INIT_FILE = "rom_init_file.mif",
  parameter integer WORD_SIZE = 8,
  parameter integer BUSY_CYCLES = 3 // numero de ciclos que ack está ativo
) (
  wishbone_if.secondary wb_if_s
);

  localparam integer DataSize = $size(wb_if_s.dat_i_s);
  localparam integer AddrSize = $size(wb_if_s.addr);

  logic [$clog2(BUSY_CYCLES):0] busy_flag = 0;
  logic [WORD_SIZE - 1:0] memory[2**AddrSize- 1:0];
  logic [(2**AddrSize)/(DataSize/WORD_SIZE)- 1:0] [DataSize-1:0] memory_packed;

  // variáveis de iteração
  genvar i;

  // inicializando a memória
  initial begin
    $readmemb(ROM_INIT_FILE, memory);
  end

  // Particionando a memória de acordo com os offsets
  generate
    for (i = 0; i < 2 ** AddrSize; i = i + 1) begin : g_mem_packed
      assign memory_packed[i/(DataSize/WORD_SIZE)][WORD_SIZE*(i%(DataSize/WORD_SIZE))+:WORD_SIZE]
            = memory[i];
    end
  endgenerate

  // Leitura da ROM
  assign wb_if_s.dat_o_s = memory_packed[wb_if_s.addr[AddrSize-1:$clog2(DataSize/WORD_SIZE)]];

  always @(posedge wb_if_s.clock) begin : wishbone_ack
    wb_if_s.ack <= 1'b0;
    if (busy_flag) begin
      busy_flag <= busy_flag + 1;
      if(busy_flag === BUSY_CYCLES) wb_if_s.ack <= 1'b1;
      else if(busy_flag === BUSY_CYCLES + 1) busy_flag <= 1'b0;
    end else if (wb_if_s.cyc && wb_if_s.stb) begin
      busy_flag <= 1'b1;
    end
  end

endmodule
