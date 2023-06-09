
//
//! @file   control_unit_RV64I_tb.v
//! @brief  Testbench da control_unit
//! @author Joao Pedro Cabral Miranda (miranda.jp@usp.br)
//! @date   2023-03-03
//

// Ideia do testbench: testar ciclo a ciclo o comportamento da UC 
// de acordo com a instrução executada
// Para isso considero as seguintes hipóteses:
// RAM, ROM, DF estão corretos.
// Com isso, basta testar se a UC consegue enviar os sinais corretos
// a partir dos sinais de entrada provenientes da RAM, ROM e DF.
// Para isso irei verificar as saídas da UC

`timescale 1 ns / 100 ps

module control_unit_RV64I_tb ();
  // sinais do DUT
  // Common
  reg              clock;
  reg              reset;
  // Bus
  wire             mem_wr_en;
  wire             mem_rd_en;
  wire    [   7:0] mem_byte_en;
  wire             mem_busy;
  // From Dataflow
  wire    [   6:0] opcode;
  wire    [   2:0] funct3;
  wire    [   6:0] funct7;
  wire             zero;
  wire             negative;
  wire             carry_out;
  wire             overflow;
  // To Dataflow
  wire             alua_src;
  wire             alub_src;
  wire             aluy_src;
  wire    [   2:0] alu_src;
  wire             sub;
  wire             arithmetic;
  wire             alupc_src;
  wire             pc_src;
  wire             pc_en;
  wire    [   1:0] wr_reg_src;
  wire             wr_reg_en;
  wire             ir_en;
  wire             mem_addr_src;
  // Sinais do Controlador de Memória
  wire    [  63:0] mem_addr;
  wire    [  63:0] wr_data;
  wire    [  63:0] rd_data;
  // Sinais do Barramento
  // Instruction Memory
  wire    [  31:0] rom_data;
  wire    [  63:0] rom_addr;
  wire             rom_enable;
  wire             rom_busy;
  // Data Memory
  wire    [  63:0] ram_address;
  wire    [  63:0] ram_write_data;
  wire    [  63:0] ram_read_data;
  wire             ram_output_enable;
  wire             ram_write_enable;
  wire             ram_chip_select;
  wire    [   7:0] ram_byte_enable;
  wire             ram_busy;
  // Sinais intermediários de teste
  reg     [  41:0] LUT_uc                                  [48:0];  // UC simulada com tabela
  wire    [2008:0] LUT_linear;  // Tabela acima linearizada
  reg     [  23:0] df_src;  // Sinais produzidos pelo LUT
  wire    [  24:0] db_df_src;  // Sinais produzidos pela UC
  // variáveis
  integer          limit = 1000;  // evitar loop infinito
  integer          i;
  genvar j;

  // DUT
  control_unit DUT (
      .clock(clock),
      .reset(reset),
      .mem_rd_en(mem_rd_en),
      .mem_byte_en(mem_byte_en),
      .mem_busy(mem_busy),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .ir_en(ir_en),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .alua_src(alua_src),
      .alub_src(alub_src),
      .aluy_src(aluy_src),
      .alu_src(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .alupc_src(alupc_src),
      .pc_src(pc_src),
      .pc_en(pc_en),
      .wr_reg_src(wr_reg_src),
      .wr_reg_en(wr_reg_en),
      .mem_addr_src(mem_addr_src),
      .mem_wr_en(mem_wr_en)
  );

  // Dataflow
  Dataflow DF (
      .clock(clock),
      .reset(reset),
      .rd_data(rd_data),
      .wr_data(wr_data),
      .ir_en(ir_en),
      .mem_addr(mem_addr),
      .alua_src(alua_src),
      .alub_src(alub_src),
      .aluy_src(aluy_src),
      .alu_src(alu_src),
      .sub(sub),
      .arithmetic(arithmetic),
      .alupc_src(alupc_src),
      .pc_src(pc_src),
      .pc_en(pc_en),
      .wr_reg_src(wr_reg_src),
      .wr_reg_en(wr_reg_en),
      .opcode(opcode),
      .funct3(funct3),
      .funct7(funct7),
      .zero(zero),
      .negative(negative),
      .carry_out(carry_out),
      .overflow(overflow),
      .mem_addr_src(mem_addr_src)
  );

  // Instanciação do barramento
  memory_controller #(
      .BYTE_AMNT(8)
  ) BUS (
      .mem_rd_en(mem_rd_en),
      .mem_wr_en(mem_wr_en),
      .mem_byte_en(mem_byte_en),
      .wr_data(wr_data),
      .mem_addr(mem_addr),
      .rd_data(rd_data),
      .mem_busy(mem_busy),
      .inst_cache_data({32'b0, rom_data}),
      .inst_cache_busy(rom_busy),
      .inst_cache_enable(rom_enable),
      .inst_cache_addr(rom_addr),
      .ram_read_data(ram_read_data),
      .ram_busy(ram_busy),
      .ram_address(ram_address),
      .ram_write_data(ram_write_data),
      .ram_output_enable(ram_output_enable),
      .ram_write_enable(ram_write_enable),
      .ram_chip_select(ram_chip_select),
      .ram_byte_enable(ram_byte_enable)
  );

  // Instruction Memory
  ROM #(
      .rom_init_file("./ROM.mif"),
      .word_size(8),
      .addr_size(10),
      .offset(2),
      .busy_cycles(2)
  ) Instruction_Memory (
      .clock (clock),
      .enable(rom_enable),
      .addr  (rom_addr[9:0]),
      .data  (rom_data),
      .busy  (rom_busy)
  );

  // Data Memory
  single_port_ram #(
      .RAM_INIT_FILE("./RAM.mif"),
      .ADDR_SIZE(12),
      .BYTE_SIZE(8),
      .DATA_SIZE(64),
      .BUSY_CYCLES(2)
  ) Data_Memory (
      .clk(clock),
      .address(ram_address),
      .write_data(ram_write_data),
      .output_enable(ram_output_enable),
      .write_enable(ram_write_enable),
      .chip_select(ram_chip_select),
      .byte_enable(ram_byte_enable),
      .read_data(ram_read_data),
      .busy(ram_busy)
  );


  // geração do clock
  always begin
    clock = 1'b0;
    #3;
    clock = 1'b1;
    #3;
  end

  // geração do LUT linear -> função não suporta array
  generate
    for (j = 0; j < 49; j = j + 1) assign LUT_linear[41*(j+1)-1:41*j] = LUT_uc[j];
  endgenerate

  // função para determinar os seletores(sinais provenientes da UC) a partir do opcode, funct3 e funct7
  function [23:0] find_instruction([6:0] opcode, [2:0] funct3, [6:0] funct7, [2008:0] LUT_linear);
    integer i;
    reg [23:0] temp;
    begin
      // U,J : apenas opcode
      if (opcode === 7'b0110111 || opcode === 7'b0010111 || opcode === 7'b1101111) begin
        for (i = 0; i < 3; i = i + 1)  // Eu coloquei U, J nas linhas 0 a 2 do mif
        if (opcode === LUT_linear[34+41*i+:7]) temp = LUT_linear[41*i+:24];
      end  // I, S, B: opcode e funct3
      else if(opcode === 7'b1100011 || opcode === 7'b0000011 || opcode === 7'b0100011 ||
                opcode === 7'b0010011 || opcode === 7'b0011011 || opcode === 7'b1100111) begin
        for (i = 3; i < 34; i = i + 1) begin  // Eu coloquei I, S, B nas linhas 3 a 33 do mif
          if (opcode === LUT_linear[34+41*i+:7] && funct3 === LUT_linear[31+41*i+:3]) begin
            // SRLI e SRAI: funct7
            if (funct3 === 3'b101 && opcode[4] == 1'b1) begin
              if (funct7[6:1] === LUT_linear[25+41*i+:6]) temp = LUT_linear[41*i+:24];
            end else temp = LUT_linear[41*i+:24];
          end
        end
      end  // R: opcode, funct3 e funct7
      else if (opcode === 7'b0111011 || opcode === 7'b0110011) begin
        for (i = 34; i < 49; i = i + 1)  // Eu coloquei I, S, B nas linhas 34 a 48 do mif
        if(opcode === LUT_linear[34+41*i+:7] && funct3 === LUT_linear[31+41*i+:3] && funct7 === LUT_linear[24+41*i+:7])
          temp = LUT_linear[41*i+:24];
      end
      find_instruction = temp;
    end
  endfunction

  // Concatenação dos sinais produzidos pela UC
  assign db_df_src = {
    ir_en,
    alua_src,
    alub_src,
    aluy_src,
    alu_src,
    sub,
    arithmetic,
    alupc_src,
    pc_src,
    wr_reg_src,
    wr_reg_en,
    mem_addr_src,
    mem_wr_en,
    mem_rd_en,
    mem_byte_en
  };

  // testar o DUT
  initial begin : Testbench
    $display("Program  size: %d", `program_size);
    $readmemb("./MIFs/core/core/RV64I.mif", LUT_uc);
    $display("SOT!");
    // Idle
    #2;
    reset = 1'b1;  // Reseto
    #0.1;
    // Confiro se a UC está em Idle 
    if (db_df_src !== 0) begin
      $display("Error Idle: db_df_src = %x", db_df_src);
      $stop;
    end
    wait (clock == 1'b1);
    wait (clock == 1'b0);
    // No ciclo seguinte, abaixo reset e confiro se a UC ainda está em Idle
    reset = 1'b0;
    #0.1;
    if (db_df_src !== 0) begin
      $display("Error Idle: db_df_src = %x", db_df_src);
      $stop;
    end
    wait (clock == 1'b1);
    wait (clock == 1'b0);
    for (i = 0; i < limit; i = i + 1) begin
      $display("Test: %d", i);
      // Fetch -> Apenas instruction mem en levantado 
      #0.1;
      // Confiro apenas os ens, pois em implementações futuras os demais podem mudar(aqui eles são don't care)
      if(ir_en !== 1'b0 || pc_en !== 1'b0 || wr_reg_en !== 1'b0 || mem_rd_en !== 1'b1 || mem_wr_en !== 1'b0 || mem_byte_en !== 8'b01111) begin
        $display(
            "Error Fetch: ir_en = %x, pc_en = %x, wr_reg_en = %x, mem_rd_en = %x, mem_byte_en = %x",
            ir_en, pc_en, wr_reg_en, mem_rd_en, mem_byte_en);
        $stop;
      end
      wait (mem_busy == 1'b1);
      wait (mem_busy == 1'b0);
      #0.1;
      // Após a memória abaixar confiro se o ir_en levantou e o instruction mem en desceu
      if (ir_en !== 1'b1 || mem_rd_en !== 1'b0 || mem_byte_en !== 8'h0F) begin
        $display("Error Fetch: ir_en = %x", ir_en);
        $stop;
      end
      wait (clock == 1'b0);
      wait (clock == 1'b1);
      #0.1;
      // Decode
      // No ciclo seguinte, obtenho as saídas da UC de acordo com o sheets
      df_src = find_instruction(opcode, funct3, funct7, LUT_linear);
      #0.1;
      // Verifico se algum enable está erroneamente habilitado
      if(ir_en !== 1'b0 || pc_en !== 1'b0 || wr_reg_en !== 1'b0 || mem_rd_en !== 1'b0 || mem_wr_en !== 1'b0) begin
        $display(
            "Error Decode: ir_en = %x, pc_en = %x, wr_reg_en = %x, mem_rd_en = %x, mem_wr_en = %x, mem_byte_en = %x",
            ir_en, pc_en, wr_reg_en, mem_rd_en, mem_wr_en, mem_byte_en);
        $stop;
      end
      wait (clock == 1'b0);
      wait (clock == 1'b1);
      #0.1;
      // Execute -> Não testo pc_src para instruções do tipo B e write_reg_en para Load (caso opcode = 0 -> deixo passar)
      if(opcode !== 0 && ({1'b0,df_src[23:15], df_src[13:12], df_src[10:0]} !== {db_df_src[24:15], db_df_src[13:12], db_df_src[10:0]} || (df_src[14] !== db_df_src[14] && opcode !== 7'b1100011)
                    || (df_src[11] !== db_df_src[11] && opcode !== 7'b0000011))) begin
        $display("Error Execute: df_src = %x, db_df_src = %x", df_src, db_df_src);
        $stop;
      end
      case (opcode)
        // Store(S*) e Load(L*)
        7'b0100011, 7'b0000011: begin
          wait (mem_busy == 1'b1);
          wait (mem_busy == 1'b0);
          #0.1;
          // Espero o busy abaixar para verificar os enables
          if(ir_en !== 1'b0 || pc_en !== 1'b1 || wr_reg_en !== df_src[11] || mem_rd_en !== 1'b0 || mem_wr_en !== 1'b0) begin
            $display(
                "Store/Load Error: pc_en = %x, wr_reg_en = %x, mem_rd_en = %x, mem_wr_en= 0x%h, mem_byte_en = %x, opcode = %x, funct3 = 0x%h",
                pc_en, wr_reg_en, mem_rd_en, mem_wr_en, mem_byte_en, opcode, funct3);
            $stop;
          end
          // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
          wait (clock == 1'b0);
          wait (clock == 1'b1);
          wait (clock == 1'b0);
        end
        // Branch(B*)
        7'b1100011: begin
          // testo pc_src de acordo com as flags do DF
          if (funct3[2:1] === 2'b00) begin
            if (zero ^ funct3[0] === 1'b1) begin
              if (pc_src !== 1'b1) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end else begin
              if (pc_src !== 1'b0) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end
          end else if (funct3[2:1] === 2'b10) begin
            if (negative ^ overflow ^ funct3[0] === 1'b1) begin
              if (pc_src !== 1'b1) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end else begin
              if (pc_src !== 1'b0) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end
          end else if (funct3[2:1] === 2'b11) begin
            if (carry_out ~^ funct3[0] === 1'b1) begin
              if (pc_src !== 1'b1) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end else begin
              if (pc_src !== 1'b0) begin
                $display("Error B-type: pc_src = %x, funct3 = %x", pc_src, funct3);
                $stop;
              end
            end
          end else $display("Error B-type: Invalid funct3! Funct3 : %x", funct3);
          // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
          wait (clock == 1'b0);
          wait (clock == 1'b1);
          wait (clock == 1'b0);
        end
        // JAL, JALR, U-type & ULA R/I-type
        7'b1101111, 7'b1100111, 7'b0010011, 7'b0110011, 7'b0011011, 7'b0111011, 7'b0110111, 7'b0010111: begin
          // Apenas checo se o pc_en está ativado
          if (pc_en !== 1'b1) begin
            $display("Error U/R/I-type: pc_en = %x, opcode = %x", pc_en, opcode);
            $stop;
          end
          // Espero a borda de descida do ciclo seguinte(padronizar com o tb do DF)
          wait (clock == 1'b0);
          wait (clock == 1'b1);
          wait (clock == 1'b0);
        end
        7'b0000000: begin
          // Fim do programa -> última instrução 0000000
          if (DF.pc === `program_size - 4) $display("End of program!");
          else $display("Error opcode case: opcode = %x", opcode);
          $stop;
        end
        default: begin  // Erro: opcode  inexistente
          $display("Error opcode case: opcode = %x", opcode);
          $stop;
        end
      endcase
    end
  end
endmodule
