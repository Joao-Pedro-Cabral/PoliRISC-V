j 12
addi sp,sp,28 ; ecall address
addi x1,x0,1
sw x1,0(sp)
addi sp,sp,4
addi x0,x0,x0
lui sp,4096  ; main
lui x5,1 
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32
ecall
