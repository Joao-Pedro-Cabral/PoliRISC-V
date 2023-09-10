lui sp,4096  ; main
lui x5,1 
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32

; writing to mtvec
addi t0,x0,176            ; BASE address for interrupt handling
slli t0,t0,2
csrrw x0,mtvec,t0

; setting mtimecmp
lui t0,-1
lui t1,524288             ; mtimecmp base address
sw t0,0(t1)

addi a2,x0,0b1            ; SSI
addi a3,x0,0b11           ; MSI
addi a4,x0,0b101          ; STI
addi a5,x0,0b111          ; MTI
addi a6,x0,0b1001         ; SEI
addi a7,x0,0b1011         ; MEI
ori t0,x0,0b101010101010
csrrw x0,mie,t0           ; enables every interrupt
ori t1,x0,0b10101010
csrrw x0,mstatus,t0       ; enables global interrupts
ecall

; Machine Timer Interrupt
add t0,x0,x0
lui t1,524288             ; mtimecmp base address
sw t0,0(t1)

; Supervisor Timer Interrupt
j 104
add t0,x0,x0
lui t1,524288             ; mtimecmp base address
sw t0,0(t1)

; Illegal Instruction
j 110
mul x0,x0,x0

; Machine Software Interrupt
csrrci x0,mip,8

; Supervisor Software Interrupt
j 104
csrrci x0,mip,2

; end program
addi sp,sp,28
addi x1,x0,1
sw x1,0(sp)
addi sp,sp,4
addi x0,x0,x0

csrrs t0,mcause,x0        ; does not write to mcause
and t1,t0,a7
bne t1,x0,24
and t1,t0,a6
bne t1,x0,26
and t1,t0,a5
bne t1,x0,28
and t1,t0,a4
bne t1,x0,36
and t1,t0,a3
bne t1,x0,44
and t1,t0,a2
bne t1,x0,46
mret
ori t0,x0,0b10            ; MEI ISR
sb t0,5(s0)
mret
ori t0,x0,0b1000          ; SEI ISR
sb t0,4(s0)
mret
ori t0,x0,0b100000        ; MTI ISR
lui t0,-1
lui t1,524288             ; mtimecmp base address
sw t0,0(t1)
sb t0,3(s0)
mret
ori t0,x0,0b10000000      ; STI ISR
lui t0,-1
lui t1,524288             ; mtimecmp base address
sw t0,0(t1)
sb t0,2(s0)
mret
ori t0,x0,0b1000000000    ; MSI ISR
sb t0,1(s0)
mret
ori t0,x0,0b100000000000  ; SSI ISR
sb t0,0(s0)
mret

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
