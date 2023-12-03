lui sp,4096  ; main
lui x5,1
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32

; writing to mtvec
addi t0,x0,112             ; BASE address for interrupt handling
csrrw x0,mtvec,t0
csrrw x0,stvec,t0

; setting mtimecmp
lui t0,-1
lui t1,262143             ; mtimecmp base address
sw t0,0(t1)

addi a0,x0,0b1            ; SSI
ori t0,x0,0b1010
csrrw x0,mie,t0           ; enables software interrupts
csrrw x0,mideleg,t0       ; delegates software interrupts
ori t1,x0,0b10101010
csrrw x0,mstatus,t0       ; enables global interrupts

; Machine Software Interrupt
addi t0,x0,-1
lui s2,262144             ; msip base address
sw t0,0(s2)

; Supervisor Software Interrupt
addi s2,x0,0b10
csrrs x0,mip,s2
jal ra,112

; end program
addi sp,sp,28
addi x1,x0,1
sw t6,0(sp)
addi sp,sp,4
add x0,x0,x0

addi t6,t6,1
csrrs t2,sepc,x0          ; does not write to sepc
addi t2,t2,4
csrrw x0,sepc,t2
csrrs t0,scause,x0        ; does not write to scause
csrrw x0,scause,x0        ; writes to scause
slli t0,t0,1
srli t0,t0,1
sub t2,t0,a0
beq t2,x0,24
csrrs t2,mepc,x0          ; does not write to mepc
addi t2,t2,4
csrrw x0,mepc,t2
sw x0,0(s2)
mret
csrrs t2,sepc,x0          ; does not write to sepc
addi t2,t2,-4
csrrw x0,sepc,t2
ori t0,x0,0b100000000000  ; SSI ISR
sb t0,0(s0)
csrrc x0,sip,s2
sret

; go to supervisor mode
addi t0,x0,0b1
slli t1,t0,12             ; MPP[1]
slli t0,t0,11             ; MPP[0]
csrrs x0,mstatus,t0       ; set MPP[0]
csrrc x0,mstatus,t1       ; clear MPP[1]
csrrw x0,mepc,ra
csrrsi x0,mstatus,0b1010
mret
