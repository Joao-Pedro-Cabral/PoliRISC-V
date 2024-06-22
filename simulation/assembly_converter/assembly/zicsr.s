lui sp,4096  ; main
lui x5,1 
or sp,sp,x5
addi sp,sp,-32
addi s0,sp,32

; writing to mtvec
addi t0,x0,168            ; BASE address for interrupt handling
csrrw x0,mtvec,t0
csrrw x0,stvec,t0

; setting mtimecmp
lui t0,-1
lui t1,262143             ; mtimecmp base address
addi t1, t1, 48
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
lui t1,262143             ; mtimecmp base address
addi t1, t1, 48
sw t0,0(t1)

; Supervisor Timer Interrupt
addi s2,x0,0b1
slli s2,s2,5             ; STIP bit in mip
csrrs x0,mip,s2
jal ra,268

; Illegal Instruction
mul x0,x0,x0
csrrc x0,6,x0

; Machine Software Interrupt
addi t0,x0,-1
lui s2,262143             ; msip base address
sw t0,0(s2)

; Supervisor Software Interrupt
addi s2,x0,0b10
csrrs x0,mip,s2
jal ra,236

; end program
addi sp,sp,28
addi sp,sp,-28
addi x1,x0,1
sw t6,0(sp)
addi sp,sp,4
add x0,x0,x0

csrrci x0,mstatus,0b1010
addi t6,t6,1
csrrs t2,mepc,x0          ; does not write to mepc
addi t2,t2,4
csrrw x0,mepc,t2
csrrs t0,mcause,x0        ; does not write to mcause
csrrw x0,mcause,x0        ; writes to mcause
slli t0,t0,1
srli t0,t0,1
sub t1,t0,a7
beq t1,x0,48
sub t1,t0,a6
beq t1,x0,52
sub t1,t0,a5
beq t1,x0,56
sub t1,t0,a4
beq t1,x0,72
sub t1,t0,a3
beq t1,x0,92
sub t1,t0,a2
beq t1,x0,100
mret
ori t0,x0,0b10            ; MEI ISR
sb t0,5(s0)
mret
ori t0,x0,0b1000          ; SEI ISR
sb t0,4(s0)
j 132
ori t0,x0,0b100000        ; MTI ISR
lui t0,-1
lui t1,262143             ; mtimecmp base address
addi t1, t1, 48
sw t0,0(t1)
sb t0,3(s0)
mret
ori t0,x0,0b10000000      ; STI ISR
sb t0,2(s0)
csrrc x0,mip,s2
csrrs t2,mepc,x0          ; does not write to mepc
addi t2,t2,-4
csrrw x0,mepc,t2
j 80
ori t0,x0,0b1000000000    ; MSI ISR
sb t0,1(s0)
sw x0,0(s2)
mret
ori t0,x0,0b100000000000  ; SSI ISR
sb t0,0(s0)
csrrc x0,mip,s2
csrrs t2,mepc,x0          ; does not write to mepc
addi t2,t2,-4
csrrw x0,mepc,t2
j 36

; go to supervisor mode
addi t0,x0,0b1
slli t1,t0,12             ; MPP[1]
slli t0,t0,11             ; MPP[0]
csrrs x0,mstatus,t0       ; set MPP[0]
csrrc x0,mstatus,t1       ; clear MPP[1]
csrrw x0,mepc,ra
csrrsi x0,mstatus,0b1010
mret

; go to machine mode
addi t0,x0,0b1
slli t1,t0,12             ; MPP[1]
slli t0,t0,11             ; MPP[0]
csrrs x0,mstatus,t0       ; set MPP[0]
csrrs x0,mstatus,t1       ; set MPP[1]
csrrsi x0,mstatus,0b1010
mret
