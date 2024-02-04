# Initialize registers
addi a0,x0,15      # Load immediate 15 to register a0
addi a1,x0,3       # Load immediate 3 to register a1

# MUL - Multiply
mul a2, a0, a1

# MULH - Multiply High (signed)
lui a0,-65536 # 0xF0000000 = -268435456 = 4026531840
lui a1,621412 # 0x97B64000 = -1749663744 = 2545303552
mulh a3, a0, a1 # 0x06849C00 = 109353984

# MULHSU - Multiply High (signed-unsigned)
mulhsu a4, a3, a1 # 0x03DCDBEC = 64805868

# MULHU - Multiply High (unsigned)
mulhu a5, a4, a0  # 0x039F0E2D = 60755501

# DIV - Divide (signed)
div a6, a1, a5 # 0xFFFFFFE4 = -28 = 4294967268

# DIVU - Divide (unsigned)
divu a7, a6, a5 # 0x00000046 = 70

# REM - Remainder (signed)
rem a2, a0, a7 # 0xFFFFFFF0 = -16 = 4294967280

# REMU - Remainder (unsigned)
remu a3, a2, a5 # 0x02821FA2 = 42082210

# Write data
lui sp,4096
lui x5,1
or sp,sp,x5
addi sp,sp,-4
sw a3,0(sp)
