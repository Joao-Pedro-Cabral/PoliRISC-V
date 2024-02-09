# Initialize registers
addi a0,x0,-1      # Load immediate -1 to register a0
addi a1,x0,-1      # Load immediate -1 register a1

# MUL - Multiply
mul a2, a0, a1 # 0x1

# MULH - Multiply High (signed)
lui a0,-65536   # 0xFFFFFFFF_F0000000
lui t0,1
mul a0,a0,t0    # 0xFFFFFF00_00000000
lui a1,621412   
mul a1,a1,t0    # 0xFFFFF97B_64000000
mulh a3, a0, a1 # 0x00000000_0006849C

# MULHSU - Multiply High (signed-unsigned)
mulhsu a4, a3, a1 # 0x00000000_0006849B

# MULHU - Multiply High (unsigned)
mulhu a5, a4, a0  # 0x00000000_0006849A

# DIV - Divide (signed)
div a6, a0, a5    # 0xFFFFFFFF_FEFFFFB2

# DIVU - Divide (unsigned)
divu a7, a6, a5   # 0x00002746_A82233F0

# REM - Remainder (signed)
rem a2, a0, a4    # 0xFFFFFFFF_FFFF4C16

# REMU - Remainder (unsigned)
remu a3, a2, a5   # 0x00000000_00061A40

# MULW - Multiply (32 bits)
mulw a4, a2, a7   # 0x00000000_666BB6A0

# DIVW - Divide (32 bits)
divw a5, a4, a2   # 0xFFFFFFFF_FFFF6E44

# DIVUW - Divide (unsigned 32 bits)
divuw a6, a5, a2   # 0x1

# REMW - Remainder (32 bits)
remw a7, a4, a2   # 0x00000000_00000CC8

# REMUW - Remainder (unsigned 32 bits)
remuw a7, a5, a2   # 0x00000000_0000222E

# Write data
lui sp,4096
lui x5,1
or sp,sp,x5
addi sp,sp,-4
sw a3,0(sp)
