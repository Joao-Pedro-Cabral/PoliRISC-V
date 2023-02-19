if(opcode[1:0] != 11)
    halt();
else if( opcode[4] = 1 )
    if( opcode[5] = 1 )
        if( opcode[2] = 0 )
            inst_type = r-type; // Integer Register-Register
        else if( opcode[3] = 0 && opcode[6] = 0 )
            inst_type = u-type; // LUI
        else
            halt();
    else
        if( opcode[2] = 0 )
            inst_type = i-type; // Integer Register-Immediate
        else if( opcode[3] = 0 && opcode[6] = 0 )
            inst_type = u-type; // AUIPC
        else
            halt();
else
    if( opcode[6] = 1 )
        if( opcode[3] = 1 )
            inst_type = j-type; // JAL
        else if( opcode[2] = 0 )
            inst_type = b-type; // Conditional Branch
        else if( opcode[5] = 1 )
            inst_type = i-type; // JALR
        else
            halt();
    else
        if( opcode[5] = 0 )
            inst_type = i-type; // Load
        else if( opcode[2] = 0 && opcode[3] = 0 )
            inst_type = s-type; // Store
        else
            halt();


