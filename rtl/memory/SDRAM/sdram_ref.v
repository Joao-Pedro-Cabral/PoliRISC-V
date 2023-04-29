//
//! @file   sdram_ref.v
//! @brief  Circuito para restaurar a SDRAM da DE10-Lite, Clock: 200 MHz
//! @author João Pedro Cabral Miranda(miranda.jp@usp.br)
//! @date   2023-04-26
//

module sdram_ref(
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,   // 1: habilita o refresh
    output reg         end_ref,  // 1: fim do refresh
    // SDRAM
    output reg  [12:0] dram_addr,
    output wire [1:0]  dram_ba,
	output wire        dram_cs_n,
	output wire        dram_ras_n,
	output wire        dram_cas_n,
	output wire        dram_we_n,
);

// Sinais intermediários/controle
reg [3:0] command;

// Contadores
reg   nop_cnt_rst;
wire  [3:0] nop_cnt;
wire  pall_nop_end = (nop_cnt >= 1); // 2 NOPs: Trp
wire  ref_nop_end  = (nop_cnt >= 8); // 9 NOPs: Trc -> O último NOP é o idle do controller

// Endereços não importam com exceção de A10(All banks)
assign dram_addr = {3'b001, 10'b0}; // A0 = 1
assign dram_ba   = 2'b00;

// Comando a ser executado pela SDRAM
assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;

reg [1:0] present_state, next_state; // Estado da FSM

// contador
sync_parallel_counter #(.size(4), .init_value(0)) contador (.clock(clock), .reset(nop_cnt_rst), .enable(1'b1), .value(nop_cnt));

// lógica de mudança de estados
always @(posedge clock, posedge reset) begin
    if(reset)
        present_state <= idle;
    else
        present_state <= next_state;
end

// estados da FSM
localparam [1:0]
    idle = 2'h0;

// lógica de saída
always @(*) begin
    end_ref     <= 1'b0;
    nop_cnt_rst <= 1'b0;
    case (present_state)
        idle: begin
            command <= 4'b0111; // NOP
            if(enable == 1'b1)
                next_state <= pall;
            else
                next_state <= idle;
        end
        pall: begin // Precharge All Banks -> Acho que não precisa por que todos os bancos estão em idle
            comand      <= 4'b0010; // Precharge
            nop_cnt_rst <= 1'b1;
            next_state  <= pall_nop;    
        end
        pall_nop: begin
            command <= 4'b0111;     // NOP
            if(pall_nop_end == 1'b1)
                next_state <= ref;  // Após 2 NOPs -> Refresh
            else
                next_state <= idle;            
        end
        ref: begin
            command     <= 4'b0001;  // Refresh
            nop_cnt_rst <= 1'b1;
            next_state  <= ref_nop;
        end
        ref_nop: begin
            command    <= 4'0111;  // NOP
            if(ref_nop_end == 1'b1) begin
                end_ref    <= 1'b1;
                next_state <= idle;
            end
            else
                next_state <= ref_nop;
        end
    endcase
end