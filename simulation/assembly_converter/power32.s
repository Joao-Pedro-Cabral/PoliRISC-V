j 74
addi sp,sp,-48 ; power
sw ra,44(sp)
sw s0,40(sp)
addi s0,sp,48
sw a0,-36(s0)
sw a1,-40(s0)
lw a5,-40(s0)
bne a5,zero,6 ; 6 --> L2
li a5,1
j 44 ; 44 --> L3
lw a5,-40(s0) ; L2
addi a5,a5,-1
mv a1,a5
lw a0,-36(s0)
auipc x1,0     ; call power
jalr x1,x1,-56 ; watch out!
sw a0,-28(s0)
sw zero,-20(s0)
sw zero,-24(s0)
j 16 ; 16 --> L4
lw a4,-20(s0) ; L5
lw a5,-28(s0)
add a5,a4,a5
sw a5,-20(s0)
lw a5,-24(s0)
addi a5,a5,1
sw a5,-24(s0)
lw a4,-24(s0) ; L4
lw a5,-36(s0)
blt a4,a5,-18 ; -18 --> L5
lw a5,-20(s0)
mv a0,a5 ; L3
lw ra,44(sp)
lw s0,40(sp)
addi sp,sp,48
jr ra
lui sp,4096 ; main 
lui x5,1     
or sp,sp,x5     
addi sp,sp,-32
sw ra,28(sp)
sw s0,24(sp)
addi s0,sp,32
lw a1,-24(s0)
lw a0,-20(s0)
auipc x1,0      ; call power
jalr x1,x1,-180 ; watch out!
sw a0,-28(s0)
li a5,0
mv a0,a5
lw ra,28(sp)
lw s0,24(sp)
addi sp,sp,28
addi x1, x0,1
lw x1, 0(sp)
addi sp, sp, 4
jr ra
