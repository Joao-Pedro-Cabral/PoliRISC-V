//
//! @file   control_unit.v
//! @brief  Implementação da unidade de controle de um processador RV64I
//! @author Igor Pontes Tresolavy (tresolavy@usp.br)
//! @date   2023-03-03
//

`include "macros.vh"

`ifdef RV64I
`define BYTE_NUM 8
`else
`define BYTE_NUM 4
`endif

module control_unit (
    // Common
    input clock,
    input reset,

    // Memory
    input                      mem_busy,
    output reg                 mem_rd_en,
    output reg                 mem_wr_en,
    output reg [`BYTE_NUM-1:0] mem_byte_en,

    // Vindo do Fluxo de Dados
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input zero,
    input negative,
    input carry_out,
    input overflow,
    input trap,
    input [1:0] privilege_mode,

    // Sinais de Controle do Fluxo de Dados
    output reg alua_src,
    output reg alub_src,
`ifdef RV64I
    output reg aluy_src,
`endif
    output reg [2:0] alu_src,
    output reg sub,
    output reg arithmetic,
    output reg alupc_src,
    output reg pc_src,
    output reg pc_en,
    output reg [1:0] wr_reg_src,
    output reg wr_reg_en,
`ifdef ZICSR
    output reg csr_imm,
    output reg [1:0] csr_op,
    output reg csr_wr_en,
`endif
    output reg ir_en,
    output reg mem_addr_src,
  `ifdef TrapReturn
    output reg mret,
    output reg sret,
  `endif
    output reg illegal_instruction,
    output reg ecall
);

  // sinais úteis

  localparam reg [4:0]
        Fetch = 5'h00,
        Fetch2 = 5'h01,
        Decode = 5'h02,
        RegistradorRegistrador = 5'h03,
        Lui = 5'h04,
        RegistradorImediato = 5'h05,
        Auipc = 5'h06,
        Jal = 5'h07,
        DesvioCondicional = 5'h08,
        Jalr = 5'h09,
        Load = 5'h0A,
        Load2 = 5'h0B,
        Store = 5'h0C,
        Store2 = 5'h0D,
        Ecall = 5'h0E,
        Idle = 5'h0F;
`ifdef TrapReturn
  localparam reg [4:0] Xret = 5'h10; // MRET, SRET
`endif
`ifdef ZICSR
  localparam reg [4:0] Zicsr = 5'h11;
`endif

  reg [4:0] estado_atual, proximo_estado;

  task zera_sinais;
    begin
      mem_wr_en   = 1'b0;
      mem_rd_en   = 1'b0;
      mem_byte_en = 'b0;
      alua_src    = 1'b0;
      alub_src    = 1'b0;
`ifdef RV64I
      aluy_src = 1'b0;
`endif
      alu_src      = 3'b000;
      sub          = 1'b0;
      arithmetic   = 1'b0;
      alupc_src    = 1'b0;
      pc_src       = 1'b0;
      pc_en        = 1'b0;
      wr_reg_src   = 2'b00;
      wr_reg_en    = 1'b0;
      ir_en        = 1'b0;
      mem_addr_src = 1'b0;
      ecall        = 1'b0;
`ifdef TrapReturn
      mret         = 1'b0;
      sret         = 1'b0;
`endif
`ifdef ZICSR
      csr_wr_en = 1'b0;
      csr_imm = 1'b0;
      csr_op  = 2'b00;
`endif
      illegal_instruction = 1'b0;
      proximo_estado = Fetch;
    end
  endtask

  // lógica da mudança de estados
  always @(posedge clock, posedge reset) begin
    if (reset) estado_atual <= Idle;
    else if (trap) estado_atual <= Fetch;
    else estado_atual <= proximo_estado;
  end

  // decisores para desvios condicionais baseados nas flags da ULA
  wire beq_bne = zero ^ funct3[0];
  wire blt_bge = (negative ^ overflow) ^ funct3[0];
  wire bltu_bgeu = carry_out ~^ funct3[0];
  wire cond = funct3[1] == 0 ? (funct3[2] == 0 ? beq_bne : blt_bge) : bltu_bgeu;
  // uso sempre 8 bits aqui -> truncamento automático na atribuição do always
  wire [7:0] byte_en = funct3[1]==0 ?
        (funct3[0]==0 ? 'h1 : 'h3) : (funct3[0]==0 ? 'hF : 'hFF);

  // máquina de estados principal
  always @(*) begin

    zera_sinais;

    case (estado_atual)  // synthesis parallel_case
      Idle: begin
        if (reset) proximo_estado = Idle;
      end

      Fetch: begin
        mem_byte_en = 'hF;
        mem_rd_en   = 1'b1;
        if (mem_busy) proximo_estado = Fetch2;
      end
      Fetch2: begin
        mem_byte_en = 'hF;
        if (!mem_busy) begin
          mem_rd_en = 1'b0;
          ir_en = 1'b1;
          proximo_estado = Decode;
        end else begin
          mem_rd_en = 1'b1;
          proximo_estado = Fetch2;
        end
      end
      Decode: begin
        if (opcode[1:0] != 2'b11) illegal_instruction = 1'b1;
        else if (opcode[4] == 1'b1) begin
          if (opcode[5] == 1'b1) begin
            if (opcode[2] == 1'b0) begin
              if (opcode[6] == 1'b0) proximo_estado = RegistradorRegistrador;
              else begin
                if (funct3 == 3'b0) begin
                  if (funct7 == 7'b0) proximo_estado = Ecall;
                `ifdef TrapReturn
                  else if (((funct7 == 7'h18) || (funct7 == 7'h38)) &&
                  (privilege_mode[0] && (privilege_mode[1] | !funct7[4])))
                    proximo_estado = Xret;
                `endif
                  else illegal_instruction = 1'b1;
                end else if (funct3 == 3'b100) illegal_instruction = 1'b1;
            `ifdef ZICSR
              else if(privilege_mode >= funct7[6:5]) proximo_estado = Zicsr;
            `endif
                else illegal_instruction = 1'b1;
              end
            end else if (opcode[3] == 1'b0 && opcode[6] == 1'b0) proximo_estado = Lui;
            else illegal_instruction = 1'b1;
          end else begin
            if (opcode[2] == 1'b0) proximo_estado = RegistradorImediato;
            else if (opcode[3] == 1'b0 && opcode[6] == 1'b0) proximo_estado = Auipc;
            else illegal_instruction = 1'b1;
          end
        end else begin
          if (opcode[6] == 1'b1) begin
            if (opcode[3] == 1'b1) proximo_estado = Jal;
            else if (opcode[2] == 1'b0) proximo_estado = DesvioCondicional;
            else if (opcode[5] == 1'b1) proximo_estado = Jalr;
            else illegal_instruction = 1'b1;
          end else begin
            if (opcode[5] == 1'b0) proximo_estado = Load;
            else if (opcode[2] == 1'b0 && opcode[3] == 1'b0) proximo_estado = Store;
            else illegal_instruction = 1'b1;
          end
        end
      end

      RegistradorRegistrador: begin
      `ifdef RV64I
        aluy_src = opcode[3];
      `endif
        alu_src = funct3;
        sub = funct7[5];
        arithmetic = funct7[5];
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      Lui: begin
        alub_src = 1'b1;
      `ifdef RV64I
        aluy_src = 1'b1;
      `endif
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      RegistradorImediato: begin
        alub_src = 1'b1;
      `ifdef RV64I
        aluy_src = opcode[3];
      `endif
        alu_src = funct3;
        arithmetic = funct7[5] & funct3[2] & (~funct3[1]) & funct3[0];
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      Auipc: begin
        alua_src = 1'b1;
        alub_src = 1'b1;
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      Jal: begin
        pc_src = 1'b1;
        pc_en = 1'b1;
        wr_reg_src = 2'b11;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      DesvioCondicional: begin
        sub = 1'b1;
        pc_src = cond;
        pc_en = 1'b1;

        proximo_estado = Fetch;
      end

      Jalr: begin
        alupc_src = 1'b1;
        pc_src = 1'b1;
        pc_en = 1'b1;
        wr_reg_src = 2'b11;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      Load: begin
        mem_addr_src = 1'b1;
        mem_byte_en = byte_en;
        alub_src = 1'b1;
        wr_reg_src = 2'b10;
        mem_rd_en = 1'b1;
        if (mem_busy) proximo_estado = Load2;
        else proximo_estado = Load;
      end
      Load2: begin
        mem_addr_src = 1'b1;
        mem_byte_en = byte_en;
        alub_src = 1'b1;
        wr_reg_src = 2'b10;
        if (!mem_busy) begin
          mem_rd_en = 1'b0;
          pc_en = 1'b1;
          wr_reg_en = 1'b1;
          proximo_estado = Fetch;
        end else begin
          mem_rd_en = 1'b1;
          proximo_estado = Load2;
        end
      end

      Store: begin
        mem_addr_src = 1'b1;
        mem_byte_en = byte_en;
        alub_src = 1'b1;
        mem_wr_en = 1'b1;
        if (mem_busy) proximo_estado = Store2;
        else proximo_estado = Store;
      end
      Store2: begin
        mem_addr_src = 1'b1;
        mem_byte_en = byte_en;
        alub_src = 1'b1;
        if (!mem_busy) begin
          mem_wr_en = 1'b0;
          pc_en = 1'b1;
          proximo_estado = Fetch;
        end else begin
          mem_wr_en = 1'b1;
          proximo_estado = Store2;
        end
      end

      Ecall: begin
        ecall = 1'b1;
        proximo_estado = Fetch;
      end

    `ifdef TrapReturn
      Xret: begin
        mret = funct7[4];
        sret = ~funct7[4];
        proximo_estado = Fetch;
      end
    `endif

    `ifdef ZICSR
      Zicsr: begin
        wr_reg_en = 1'b1;
        wr_reg_src = 2'b01;
        // não significa que algum CSR será escrito
        csr_wr_en = 1'b1;
        csr_imm = funct3[2];
        csr_op  = funct3[1:0];
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end
    `endif

      default: proximo_estado = Idle;
    endcase
  end

endmodule
