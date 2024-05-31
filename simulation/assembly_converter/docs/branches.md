# RISC-V Assembly Program Description

This RISC-V assembly program performs a series of memory and register manipulations, involving arithmetic and comparison operations, and looping constructs. Below is a step-by-step explanation of what the program does:

### Initialization

1. **Set up stack pointer (sp) and general purpose register (x5):**
   ```assembly
   lui sp,4096   ; Load upper immediate for sp with 4096
   lui x5,1      ; Load upper immediate for x5 with 1
   fence         ; Synchronize memory and I/O
   or sp,sp,x5   ; sp = sp | x5 (logical OR)
   fence         ; Synchronize memory and I/O
   ```

2. **Adjust stack pointer and save register s0:**
   ```assembly
   addi sp,sp,-32  ; Decrement sp by 32 (allocate stack space)
   sd s0,24(sp)    ; Save s0 to the stack at offset 24(sp)
   addi s0,sp,32   ; Set s0 to the new stack base
   ```

### Store initial values for comparisons

3. **Store initial values into memory:**
   ```assembly
   li a5,1         ; Load immediate 1 into a5
   sh a5,-18(s0)   ; Store halfword (16-bit) from a5 to address (s0-18)
   li a5,1
   sh a5,-20(s0)   ; Store halfword (16-bit) from a5 to address (s0-20)
   li a5,2
   sw a5,-24(s0)   ; Store word (32-bit) from a5 to address (s0-24)
   li a5,1
   sw a5,-28(s0)   ; Store word (32-bit) from a5 to address (s0-28)
   ```

### Compare and update memory values

4. **Load and compare halfwords:**
   ```assembly
   lh a4,-18(s0)   ; Load halfword from address (s0-18) into a4
   lh a5,-20(s0)   ; Load halfword from address (s0-20) into a5
   sext.w a4,a4    ; Sign-extend a4 to 32-bit
   sext.w a5,a5    ; Sign-extend a5 to 32-bit
   bne a4,a5,48    ; Branch to offset 48 if a4 != a5
   ```

5. **Increment and store back if equal:**
   ```assembly
   lhu a5,-18(s0)  ; Load unsigned halfword from (s0-18) into a5
   addiw a5,a5,1   ; Increment a5 by 1
   slli a5,a5,48   ; Shift left logical immediate by 48
   srli a5,a5,48   ; Shift right logical immediate by 48 (zero extension)
   sh a5,-20(s0)   ; Store halfword from a5 to address (s0-20)
   ```

### Repeat comparisons and updates

6. **Repeat comparison and updates in a loop:**
   ```assembly
   lh a4,-20(s0)
   lh a5,-18(s0)
   sext.w a4,a4
   sext.w a5,a5
   blt a4,a5,48    ; Branch if a4 < a5

   lhu a5,-20(s0)
   addiw a5,a5,1
   slli a5,a5,48
   srli a5,a5,48
   sh a5,-18(s0)

   lwu a5,-24(s0)  ; Load unsigned word from (s0-24)
   mv a4,a5        ; Move a5 to a4
   lwu a5,-28(s0)  ; Load unsigned word from (s0-28)
   sext.w a4,a4
   sext.w a5,a5
   bltu a4,a5,32   ; Branch if a4 < a5 (unsigned comparison)

   lwu a5,-24(s0)
   addiw a5,a5,1
   sw a5,-28(s0)

   lh a4,-20(s0)
   lh a5,-18(s0)
   sext.w a4,a4
   sext.w a5,a5
   bge a4,a5,24    ; Branch if a4 >= a5

   lhu a5,-18(s0)
   sh a5,-20(s0)
   ```

### Final comparisons and cleanup

7. **Final comparison and potential update:**
   ```assembly
   lwu a5,-24(s0)
   mv a4,a5
   lwu a5,-28(s0)
   sext.w a4,a4
   sext.w a5,a5
   bgeu a4,a5,32   ; Branch if a4 >= a5 (unsigned comparison)

   lwu a5,-28(s0)
   addiw a5,a5,1
   sw a5,-24(s0)
   ```

8. **Final check and exit:**
   ```assembly
   lwu a5,-24(s0)
   mv a4,a5
   lwu a5,-28(s0)
   sext.w a4,a4
   sext.w a5,a5
   beq a4,a5,24    ; Branch if a4 == a5

   lwu a5,-28(s0)
   sw a5,-24(s0)
   li a5,0         ; Load immediate 0 into a5
   mv a0,a5        ; Move a5 to a0 (return value)
   ```

### Restore and return

9. **Restore register s0 and stack pointer, then return:**
   ```assembly
   ld s0,24(sp)    ; Load double word from address 24(sp) to s0
   addi sp,sp,28   ; Adjust sp by adding 28 (deallocate stack space)
   addi x1,x0,1    ; Add immediate 1 to x0 and store in x1 (setup for return)
   sw x1,0(sp)     ; Store word from x1 to address 0(sp)
   addi sp,sp,4    ; Adjust sp by adding 4
   fence           ; Synchronize memory and I/O
   fence           ; Synchronize memory and I/O
   jr ra           ; Jump to return address (return from function)
   ```

### Summary

The program performs a series of memory operations including loading, storing, comparing, and updating values in memory. It repeatedly checks conditions and updates values in a loop-like structure. Finally, it restores the saved register and stack pointer before returning from the function.
