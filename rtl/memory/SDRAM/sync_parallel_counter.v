
module sync_parallel_counter(clock, reset, inc_enable, dec_enable, load, load_value, value);
    parameter size = 4;                       // número de bits da contagem
    parameter [size - 1:0] init_value = 0;    // inicio da contagem
    input  wire clock, reset, inc_enable, dec_enable, load;
    input  wire [size - 1:0] load_value;      // valor para carga 
    output wire [size - 1:0] value;
    wire [size - 1:0] enable_vector;          // vetor de enable dos registradores T
    wire [size - 1:0] enable_aux;             // vetor auxiliar para a formação dos enables
    wire [size - 1:0] reg_T_out;              // saída dos registradores T
    wire [size - 1:0] reg_T_in;               // entrada dos registradores T
    genvar i, j;                              // variáveis de iteração do generate

    // gero o contador
    generate
        for(i = 0; i < size; i = i + 1) begin: count_gen
            // gero os size registradores T usando registradores D
            register_d #(.N(1), .reset_value(init_value[i])) register_T 
                (.clock(clock), .reset(reset), .enable(load | enable_vector[i]), .D(reg_T_in[i]), .Q(reg_T_out[i]));
            // gero os enables dos registradores
            // inc_enable: incrementa / dec_enable: decrementa
            assign enable_vector[i] = enable_aux[i] & (inc_enable | dec_enable);
            // gero os enable_aux(concatenação de AND de 2 entradas)
            // inc_enable: 1 -> reg_T_out(incrementar), caso contrário: ~reg_T_out(decrementar)
            // Relação entre reg_T_out e inc_enable é uma XNOR!
            if(i > 0)
                assign enable_aux[i] = enable_aux[i - 1] & (reg_T_out[i - 1] ~^ inc_enable);
            else
                assign enable_aux[0] = 1;
        end
    endgenerate

    // load = 1: carga com valor da entrada; load = 0: continuar a contagem
    assign reg_T_in = load ? load_value : ~reg_T_out; 
    assign value = reg_T_out;

endmodule
