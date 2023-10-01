lui sp,4096  ; main
lui x5,1
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32

; writing to mtvec
addi t0,x0,96            ; BASE address for interrupt handling
csrrw x0,mtvec,t0

addi a0,x0,0b1            ; SSI
ori t0,x0,0b1010
csrrw x0,mie,t0           ; enables software interrupts
csrrw x0,mideleg,t0       ; delegates software interrupts
ori t1,x0,0b10101010
csrrw x0,mstatus,t0       ; enables global interrupts

; Machine Software Interrupt
addi t0,x0,-1
lui t1,524292             ; msip base address
sw t0,0(t1)

; Supervisor Software Interrupt
j 30
lui t1,524296             ; ssip base address
sw t0,0(t1)

; end program
addi sp,sp,28
addi x1,x0,1
sw x1,0(sp)
addi sp,sp,4
add x0,x0,x0

csrrs t0,mcause,x0        ; does not write to mcause
and t1,t0,a0
bne t1,x0,4
mret
ori t0,x0,0b100000000000  ; SSI ISR
sb t0,0(s0)
sret

; go to supervisor mode
addi t0,x0,0b1
slli t1,t0,12             ; MPP[1]
slli t0,t0,11             ; MPP[0]
csrrs x0,mstatus,t0       ; set MPP[0]
csrrc x0,mstatus,t1       ; clear MPP[1]
ecall
jr ra

; go to machine mode
addi t0,x0,0b1
slli t1,t0,12             ; MPP[1]
slli t0,t0,11             ; MPP[0]
csrrc x0,mstatus,t0       ; clear MPP[0]
csrrc x0,mstatus,t1       ; clear MPP[1]
ecall
jr ra
