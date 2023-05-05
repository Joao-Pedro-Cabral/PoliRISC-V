//
//! @file   sdram_tester_uc.v
//! @brief  Unidade de Controle do SDRAM Tester
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-05-03
//

module sdram_tester_uc(
    // Comum
    input  wire        clock,
    input  wire        reset,
    // Interface Humana
    input  wire        chaves_0, // chaves[0]
    // DF
    input  wire        ativado,
    input  wire        op_end,
    input  wire        busy,
    output reg         rd_en,
    output reg         wr_en,
    output reg         op_rst,
    output reg         addr_en,
    output reg         size_en,
    output reg         wr_data_en,
    output reg         cnt_en,
    output reg         cnt_rst,
    output reg [1:0]   addr_src
);

    reg [3:0] present_state, next_state; // FSM

    // Estados da FSM
    localparam [3:0]
        idle      = 4'h0,
        address1  = 4'h1,
        address2  = 4'h2,
        address3  = 4'h3,
        op_size   = 4'h4,
        op_mode   = 4'h5,
        rd_start  = 4'h6,
        rd_wait   = 4'h7,
        rd_mode   = 4'h8,
        pre_wr    = 4'h9,  
        wr_start  = 4'hA, 
        wr_wait   = 4'hB;

    // transição de estados
    always @(posedge clock, posedge reset) begin
        if(reset) 
            present_state <= idle;
        else
            present_state <= next_state;
    end

    // lógica de mudança de estado e de saída
    always @(*) begin
        rd_en      = 0;
        wr_en      = 0;
        op_rst     = 0;
        addr_en    = 0;
        size_en    = 0;
        wr_data_en = 0;
        addr_src   = 0;
        cnt_rst    = 0;
        cnt_en     = 0;
        case(present_state)
            idle: begin // não faz nada
                if(ativado)
                    next_state = address1;
                else
                    next_state = ativado;
            end
            address1: begin // determinar address[9:0]
                if(ativado) begin
                    addr_en    = 1'b1;
                    next_state = address2;
                end
                else
                    next_state = address1;
            end
            address2: begin // determinar address[19:10]
                if(ativado) begin
                    addr_en    = 1'b1;
                    addr_src   = 2'b01;
                    next_state = address3;
                end
                else
                    next_state = address2;
            end
            address3: begin // determinar address[26:20]
                if(ativado) begin
                    addr_en    = 1'b1;
                    addr_src   = 2'b10;
                    next_state = op_size;
                end
                else
                    next_state = address3;
            end
            op_size: begin // determinar rd_wr_size
                if(ativado) begin
                    size_en    = 1'b1;
                    next_state = op_mode;
                end
                else
                    next_state = op_size;
            end
            op_mode: begin // determinar rd_enable/wr_enable
                cnt_rst = 1'b1; // pre_wr usa contador
                if(ativado) begin
                    if(chaves_0) // write
                        next_state = pre_wr;
                    else // read
                        next_state = rd_start;
                end
                else
                    next_state = op_mode;
            end
            rd_start: begin
                rd_en = 1'b1;
                if(busy) // Leitura começou
                    next_state = rd_wait;
                else
                    next_state = rd_start;
            end
            rd_wait: begin
                cnt_rst = 1'b1; // Contador será usado no próximo estado
                if(!busy) begin // Fim da leitura
                    op_rst     = 1'b1;
                    next_state = rd_mode;
                end
                else
                    next_state = rd_wait;
            end
            rd_mode: begin // Exibir leitura nos displays
                cnt_en = ativado; // Incrementar contagem e exibir próximo byte
                if(op_end && ativado) // Fim da operação
                    next_state = idle; 
                else // Continuar exibindo
                    next_state = rd_mode;
            end
            pre_wr: begin // Obter write data
                wr_data_en  = ativado; // Ativado -> alterar write data
                cnt_en      = ativado; // Ativado -> Incrementar contagem
                if(op_end && ativado) // Fim da operação de geração do write data
                    next_state = wr_start;
                else
                    next_state = pre_wr;
            end
            wr_start: begin
                wr_en = 1'b1; // Habilitar Escrita
                if(busy) // Escrita começou
                    next_state = wr_wait;
                else
                    next_state = wr_start;
            end
            wr_wait: begin
                if(!busy) begin // Fim da escrita
                    op_rst     = 1'b1;
                    next_state = idle;
                end
                else
                    next_state = wr_wait;
            end
            default: begin // Impossível
                next_state = idle;
            end
        endcase
    end
endmodule