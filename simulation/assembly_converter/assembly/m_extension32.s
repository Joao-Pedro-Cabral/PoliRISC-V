# Initialize registers
addi a0,x0,15      # Load immediate 15 to register a0
addi a1,x0,3       # Load immediate 3 to register a1

# MUL - Multiply
mul a2, a0, a1

# MULH - Multiply High (signed)
lui a0,-65536
lui a1,621412
mulh a3, a0, a1 # 0xFFFFF684 = -2428

# MULHSU - Multiply High (signed-unsigned)
mulhsu a4, a1, a3 # 0x00059EE4 = 368356

# MULHU - Multiply High (unsigned)
mulhu a5, a4, a0  # 0x000059EE = 23022

# DIV - Divide (signed)
div a6, a0, a5 # 0xFFFFD275 = -11659

# DIVU - Divide (unsigned)
divu a7, a1, a6 # 0x000354C8 = 218312

# REM - Remainder (signed)
rem a2, a0, a7 # 0xFFFE0428 = -130008

# REMU - Remainder (unsigned)
mul a6, a6, a5 # 0xF00055C6 = −268413498
remu a3, a6, a2 # 0x00012CBA = 76986

# Write data
lui sp,4096
lui x5,1     
or sp,sp,x5     
addi sp,sp,28
sw a3,0(sp)
