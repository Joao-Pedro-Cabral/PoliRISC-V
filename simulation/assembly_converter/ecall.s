lui sp,4096  ; main
lui x5,1 
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32

; writing to mtvec
addi t0,x0,64             ; BASE address for interrupt handling
csrrw x0,mtvec,t0
csrrw x0,stvec,t0

; setting mtimecmp
lui t0,-1
lui t1,262143             ; mtimecmp base address
sw t0,0(t1)

ori t0,x0,0b101010101010
csrrw x0,mie,t0           ; enables every interrupt
ori t1,x0,0b10101010
csrrw x0,mstatus,t0       ; enables global interrupts
ecall

addi sp,sp,28
addi t6,t6,1
sw t6,0(sp)
