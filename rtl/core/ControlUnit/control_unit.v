
module control_unit #(
    parameter integer BYTE_NUM = 8
) (
    // Common
    input wire clock,
    input wire reset,

    // Memory
    input  wire                mem_ack,
    output reg                 mem_rd_en,
    output reg                 mem_wr_en,
    output reg [BYTE_NUM-1:0] mem_byte_en,

    // Vindo do Fluxo de Dados
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire zero,
    input wire negative,
    input wire carry_out,
    input wire overflow,
    input wire [1:0] privilege_mode,
    input wire csr_addr_exception,

    // Sinais de Controle do Fluxo de Dados
    output reg alua_src,
    output reg alub_src,
    output reg aluy_src,
    output reg [3:0] alu_src,
    output reg sub,
    output reg arithmetic,
    output reg alupc_src,
    output reg pc_src,
    output reg pc_en,
    output reg [1:0] wr_reg_src,
    output reg wr_reg_en,
    output reg csr_imm,
    output reg [1:0] csr_op,
    output reg csr_wr_en,
    output reg ir_en,
    output reg mem_addr_src,
    output reg mret,
    output reg sret,
    output reg illegal_instruction,
    output reg ecall
);

  // sinais úteis

  localparam reg[6:0] UlaRTypeOpCode = 7'b0110011,
    WRtypeOpCode = 7'b0111011,
    ULAITypeOpCode = 7'b0010011,
    ULAWITypeOpCode = 7'b0011011,
    ITypeOpCode = 7'b0000011,
    STypeOpCode = 7'b0100011,
    DesvioCondicionalOpCode = 7'b1100011,
    LuiOpCode =   7'b0110111,
    AuipcOpCode = 7'b0010111,
    JalOpCode =   7'b1101111,
    JalrOpCode =  7'b1100111,
    FenceOpCode = 7'b0001111,
    SystemOpCode = 7'b1110011;

  localparam reg [4:0]
        Fetch = 5'h00,
        Decode = 5'h01,
        RegistradorRegistrador = 5'h02,
        Lui = 5'h03,
        RegistradorImediato = 5'h04,
        Auipc = 5'h05,
        Jal = 5'h06,
        DesvioCondicional = 5'h07,
        Jalr = 5'h08,
        Load = 5'h09,
        Store = 5'h0A,
        Ecall = 5'h0B,
        Idle = 5'h0C;
  localparam reg [4:0] Xret = 5'h0D; // MRET, SRET
  localparam reg [4:0] Zicsr = 5'h0E;
  localparam reg [4:0]
        Illegal = 5'h0F,
        Fence = 5'h10;
  localparam reg [4:0] MultiplicacaoOuDivisao = 5'h11;

  reg [4:0] estado_atual, proximo_estado;

  task automatic zera_sinais;
    begin
      mem_wr_en   = 1'b0;
      mem_rd_en   = 1'b0;
      mem_byte_en = 'b0;
      alua_src    = 1'b0;
      alub_src    = 1'b0;
      aluy_src = 1'b0;
      alu_src      = 4'b0000;
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
      mret         = 1'b0;
      sret         = 1'b0;
      csr_wr_en = 1'b0;
      csr_imm = 1'b0;
      csr_op  = 2'b00;
      illegal_instruction = 1'b0;
      proximo_estado = Fetch;
    end
  endtask

  // lógica da mudança de estados
  always @(posedge clock, posedge reset) begin
    if (reset) estado_atual <= Idle;
    else estado_atual <= proximo_estado;
  end

  // decisores para desvios condicionais baseados nas flags da ULA
  wire beq_bne = zero ^ funct3[0];
  wire blt_bge = (negative ^ overflow) ^ funct3[0];
  wire bltu_bgeu = carry_out ~^ funct3[0];
  wire cond = funct3[1] == 0 ? (funct3[2] == 0 ? beq_bne : blt_bge) : bltu_bgeu;
  // uso sempre 8 bits aqui -> truncamento automático na atribuição do always
  wire [BYTE_NUM-1:0] byte_en = funct3[1]==0 ?
        (funct3[0]==0 ? 'h1 : 'h3) : (funct3[0]==0 ? 'hF : 'hFF);

  // máquina de estados principal
  always @(*) begin

    zera_sinais;

    case (estado_atual)  // synthesis parallel_case
      Idle: begin
        if (reset) proximo_estado = Idle;
      end

      Fetch: begin
        mem_byte_en = 4'hF;
        mem_rd_en   = 1'b1;
        if (mem_ack) begin
          ir_en = 1'b1;
          proximo_estado = Decode;
        end else proximo_estado = Fetch;
      end
      Decode: begin
        case(opcode)
          UlaRTypeOpCode: begin
            proximo_estado = RegistradorRegistrador;
            if(funct3 == 3'b000 || funct3 == 3'b101) begin
              if({funct7[6],funct7[4:1]} != 0) proximo_estado = Illegal;
            end else if(funct7[6:1] != 0) proximo_estado = Illegal;
          end
          WRtypeOpCode: begin
            if(BYTE_NUM == 8) begin
              proximo_estado = RegistradorRegistrador;
              if(funct3 == 3'b000 || funct3 == 3'b101) begin
                  if({funct7[6],funct7[4:1]} != 0) proximo_estado = Illegal;
              end else if(funct3 == 3'b010 || funct3 == 3'b011) proximo_estado = Illegal;
            end else begin
              proximo_estado = Illegal;
            end
          end
          ULAITypeOpCode: begin
            proximo_estado = RegistradorImediato;
            if(BYTE_NUM == 8) begin
              if(funct3 == 3'b001 && funct7[6:1] != 0) proximo_estado = Illegal;
              if(funct3 == 3'b101 && {funct7[6],funct7[4:1]} != 0)
                proximo_estado = Illegal;
            end else begin
              if(funct3 == 3'b001 && funct7 != 0) proximo_estado = Illegal;
              if(funct3 == 3'b101 && {funct7[6],funct7[4:1]} != 0)
                proximo_estado = Illegal;
            end
          end
          ULAWITypeOpCode: begin
            if(BYTE_NUM == 8) begin
            proximo_estado = RegistradorImediato;
            if(funct3 == 3'b101 && {funct7[6],funct7[4:1]} != 0) proximo_estado = Illegal; // SRIW
            else if(funct3 == 3'b001 && funct7 != 0) proximo_estado = Illegal; // SLLIW
            else if(funct3 != 3'b000) proximo_estado = Illegal; // ADDIW
            end else begin
              proximo_estado = Illegal;
            end
          end
          ITypeOpCode: begin // (Load)
            proximo_estado = Load;
            if(BYTE_NUM == 8) begin
              if(funct3 == 3'b111) proximo_estado = Illegal;
            end else begin
              if(funct3 == 3'b011 || funct3[2:1] == 2'b11) proximo_estado = Illegal;
            end
          end
          STypeOpCode: begin
            proximo_estado = Store;
            if(funct3[2]) proximo_estado = Illegal;
            else if(BYTE_NUM == 8 && funct3[1:0] == 2'b11) proximo_estado = Illegal;
          end
          DesvioCondicionalOpCode: proximo_estado = DesvioCondicional;
          LuiOpCode: proximo_estado = Lui;
          AuipcOpCode: proximo_estado = Auipc;
          JalOpCode: proximo_estado = Jal;
          JalrOpCode: proximo_estado = Jalr;
          FenceOpCode: proximo_estado = Fence;
          SystemOpCode: begin
            if(funct3 == 0) begin
              if(funct7 == 0) proximo_estado = Ecall; // ECALL
              else if(funct7 == 7'h18 && privilege_mode == 2'b11) proximo_estado = Xret; // MRET
              else if(funct7 == 7'h08 && privilege_mode[0]) proximo_estado = Xret; // SRET
              else proximo_estado = Illegal;
            end
            else if(funct3 != 3'b100) begin // Zicsr
              if(privilege_mode >= funct7[4:3]) proximo_estado = Zicsr;
              else proximo_estado = Illegal;
            end
            else proximo_estado = Illegal;
          end
          default: proximo_estado = Illegal;
        endcase
      end

      RegistradorRegistrador: begin
        aluy_src = opcode[3];
        alu_src = {funct7[0], funct3};
        sub = funct7[5];
        arithmetic = funct7[5];
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      Lui: begin
        alub_src = 1'b1;
        aluy_src = 1'b1;
        pc_en = 1'b1;
        wr_reg_en = 1'b1;

        proximo_estado = Fetch;
      end

      RegistradorImediato: begin
        alub_src = 1'b1;
        aluy_src = opcode[3];
        alu_src = {1'b0, funct3};
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
        if (mem_ack) begin
          pc_en = 1'b1;
          wr_reg_en = 1'b1;
          proximo_estado = Fetch;
        end
        else proximo_estado = Load;
      end

      Store: begin
        mem_addr_src = 1'b1;
        mem_byte_en = byte_en;
        alub_src = 1'b1;
        mem_wr_en = 1'b1;
        if (mem_ack) begin
          pc_en = 1'b1;
          proximo_estado = Fetch;
        end
        else proximo_estado = Store;
      end

      Ecall: begin
        ecall = 1'b1;
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end

      Illegal: begin
        illegal_instruction = 1'b1;
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end

      Fence: begin // Conservative Fence
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end

      Xret: begin
        mret = funct7[4];
        sret = ~funct7[4];
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end

      Zicsr: begin
        wr_reg_en = 1'b1;
        wr_reg_src = 2'b01;
        // não significa que algum CSR será escrito
        csr_wr_en = 1'b1;
        csr_imm = funct3[2];
        csr_op  = funct3[1:0];
        illegal_instruction = csr_addr_exception;
        pc_en = 1'b1;
        proximo_estado = Fetch;
      end

      default: proximo_estado = Idle;
    endcase
  end

endmodule
