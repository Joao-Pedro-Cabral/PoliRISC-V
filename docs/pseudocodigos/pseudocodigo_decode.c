if(opcode[1:0] != 11)
    halt();
else if( opcode[4] = 1 )
    if( opcode[5] = 1 )
        if( opcode[2] = 0 )
            inst_type = tipo_r; // Registrador-Registrador
        else if( opcode[3] = 0 && opcode[6] = 0 )
            inst_type = tipo_u; // LUI (Registrador-Imediato)
        else
            halt();
    else
        if( opcode[2] = 0 )
            inst_type = tipo_i; // Registrador-Imediato
        else if( opcode[3] = 0 && opcode[6] = 0 )
            inst_type = tipo_u; // AUIPC (Registrador-Imediato)
        else
            halt();
else
    if( opcode[6] = 1 )
        if( opcode[3] = 1 )
            inst_type = tipo_j; // JAL
        else if( opcode[2] = 0 )
            inst_type = tipo_b; // Desvio Condicional
        else if( opcode[5] = 1 )
            inst_type = tipo_i; // JALR
        else
            halt();
    else
        if( opcode[5] = 0 )
            inst_type = tipo_i; // Load (carregamento de dados da memória)
        else if( opcode[2] = 0 && opcode[3] = 0 )
            inst_type = tipo_s; // Store (armazenamento na memória)
        else
            halt();
