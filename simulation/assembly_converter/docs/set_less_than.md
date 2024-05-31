# RISC-V Assembly Program Description

This markdown document provides a detailed description of two RISC-V assembly programs that demonstrate various integer and comparison operations, followed by the differences between the two programs.

## Program Description

The first program demonstrates various operations using 32-bit instructions and stores the results in memory. Here is a step-by-step breakdown:

### Main Function

1. **Initialize stack and save registers:**
   ```assembly
   lui sp,4096      ; Load upper immediate for sp with 4096
   lui x5,1         ; Load upper immediate for x5 with 1
   or sp,sp,x5      ; sp = sp | x5 (logical OR)
   addi sp,sp,-64   ; Decrement sp by 64 (allocate stack space)
   sw s0,30(sp)     ; Save s0 to the stack at offset 30(sp)
   addi s0,sp,64    ; Set s0 to the new stack base
   ```

2. **Initialize memory locations:**
   ```assembly
   sw zero,-20(s0)  ; Store zero at offset -20(s0)
   li a5,3
   sw a5,-24(s0)    ; Store 3 at offset -24(s0)
   sb zero,-25(s0)  ; Store zero byte at offset -25(s0)
   li a5,-56
   sb a5,-26(s0)    ; Store -56 byte at offset -26(s0)
   ```

3. **Perform various comparisons and store results:**
   ```assembly
   lw a4,-20(s0)
   lw a5,-24(s0)
   slt a5,a4,a5
   andi a5,a5,0xff
   sw a5,-32(s0)    ; Store result of comparison (-20 < -24)

   lw a4,-24(s0)
   lw a5,-20(s0)
   slt a5,a4,a5
   andi a5,a5,0xff
   sw a5,-36(s0)    ; Store result of comparison (-24 < -20)

   lbu a4,-25(s0)
   lbu a5,-26(s0)
   sltu a5,a4,a5
   andi a5,a5,0xff
   sb a5,-37(s0)    ; Store result of unsigned comparison (-25 < -26)

   lbu a4,-26(s0)
   lbu a5,-25(s0)
   sltu a5,a4,a5
   andi a5,a5,0xff
   sb a5,-38(s0)    ; Store result of unsigned comparison (-26 < -25)

   lw a5,-20(s0)
   slti a5,a5,-1
   andi a5,a5,0xff
   sw a5,-44(s0)    ; Store result of comparison (-20 < -1)

   lw a5,-24(s0)
   slti a5,a5,-3
   sltiu a5,a5,1
   andi a5,a5,0xff
   sw a5,-48(s0)    ; Store result of unsigned comparison (-24 < -3)

   lbu a5,-26(s0)
   sltiu a5,a5,100
   andi a5,a5,0xff
   sb a5,-49(s0)    ; Store result of unsigned comparison (-26 < 100)

   lbu a5,-26(s0)
   sltiu a5,a5,101
   sltiu a5,a5,1
   andi a5,a5,0xff
   sb a5,-50(s0)    ; Store result of unsigned comparison (-26 < 101)
   ```

4. **Finish and return:**
   ```assembly
   li a5,0
   mv a0,a5         ; Set return value to 0
   lw s0,60(sp)     ; Restore s0
   addi sp,sp,60    ; Deallocate stack space
   addi x1,x0,1     ; Prepare for return
   sw x1,0(sp)      ; Store word from x1 to address 0(sp)
   addi sp,sp,4     ; Adjust sp by adding 4
   jr ra            ; Return from function
   ```

### Differences Between the Two Assembly Codes (32 and 64)

1. **Stack Allocation and Register Saving:**
   - **32 bits:** Allocates 64 bytes of stack space and uses `sw` instructions to save registers.
   - **64 bits:** Allocates 96 bytes of stack space and uses `sd` instructions to save registers.

2. **Memory Initialization:**
   - **32 bits:** Uses `sw` and `sb` for storing initial values in memory.
   - **64 bits:** Uses `sd` and `sb` for storing initial values in memory.

3. **Comparison Operations:**
   - **32 bits:** Uses 32-bit instructions (`lw`, `sw`) for comparisons.
   - **64 bits:** Uses 64-bit instructions (`ld`, `sd`) for comparisons,

 and sign-extends bytes before performing unsigned comparisons (`sext.w`).

4. **Handling Immediate Values in Comparisons:**
   - **32 bits:** Uses `slti` and `sltiu` for comparisons with immediate values.
   - **64 bits:** Uses `slti` and `xori` for signed comparisons with immediate values, ensuring proper handling of sign extension.

5. **Result Storage:**
   - **32 bits:** Stores comparison results using `sw` and `sb`.
   - **64 bits:** Stores comparison results using `sd` and `sb`.

6. **Unsigned Comparisons:**
   - **32 bits:** Directly compares byte values.
   - **64 bits:** Sign-extends byte values before performing comparisons (`sext.w`).
