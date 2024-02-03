# Initialize registers
addi a0,x0,15      # Load immediate 15 to register a0
addi a1,x0,3       # Load immediate 3 to register a1

# MUL - Multiply
mul a2, a0, a1

# MULH - Multiply High (signed)
lui a0,65536
lui a1,621412
addi a1,a1,3072
mulh a3, a0, a1 // 0x097B64C0

# MULHSU - Multiply High (signed-unsigned)
addi a1,a1,-1
mulhsu a4, a0, a1 // 0x0FFFFFFF

# MULHU - Multiply High (unsigned)
mulhu a5, a1, a0  // 0x0FFFFFFF

# DIV - Divide (signed)
addi a0,a0,-1      # Change value in register a0
addi a1,a1,2       # Change value in register a1
div a6, a0, a1 // 0xFFFFFFFF

# DIVU - Divide (unsigned)
divu a7, a0, a1 // 0x7FFFFFFF

# REM - Remainder (signed)
rem a8, a0, a1

# REMU - Remainder (unsigned)
li a0, 11      # Change value in register a0
li a1, 4       # Change value in register a1
remu a9, a0, a1
