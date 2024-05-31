# RISC-V Assembly Program Description

This RISC-V assembly program calculates the power of one number raised to another (i.e., \( a^b \)). The program consists of a recursive function to compute the power and a main function to set up and call this power function. Below is a detailed explanation of the program.

### Main Function

1. **Jump to setup (skip the main function setup initially):**
   ```assembly
   j 148
   ```

2. **Set up stack and save return address and register s0:**
   ```assembly
   lui sp,4096      ; Load upper immediate for sp with 4096
   lui x5,1         ; Load upper immediate for x5 with 1
   or sp,sp,x5      ; sp = sp | x5 (logical OR)
   addi sp,sp,-32   ; Decrement sp by 32 (allocate stack space)
   sw ra,24(sp)     ; Save return address to the stack at offset 24(sp)
   sw s0,20(sp)     ; Save s0 to the stack at offset 20(sp)
   addi s0,sp,32    ; Set s0 to the new stack base
   ```

3. **Initialize arguments and call the power function:**
   ```assembly
   addi a1,x0,4     ; Load immediate 4 into a1 (exponent)
   addi a0,x0,2     ; Load immediate 2 into a0 (base)
   auipc x1,0       ; Adjust for function call
   jalr x1,-180(x1) ; Call power function
   ```

4. **Store result and clean up stack:**
   ```assembly
   sw a0,-28(s0)    ; Store result of power function at offset -28(s0)
   li a5,0          ; Load immediate 0 into a5
   mv a0,a5         ; Move a5 to a0 (return value)
   lw ra,28(sp)     ; Restore return address
   lw s0,24(sp)     ; Restore s0
   addi sp,sp,28    ; Deallocate stack space
   addi x1,x0,1     ; Prepare for return
   sw x1,0(sp)      ; Store word from x1 to address 0(sp)
   addi sp,sp,4     ; Adjust sp by adding 4
   jr ra            ; Return from function
   ```

### Power Function

1. **Function prologue:**
   ```assembly
   addi sp,sp,-48   ; Allocate stack space
   sw ra,44(sp)     ; Save return address
   sw s0,40(sp)     ; Save s0
   addi s0,sp,48    ; Set s0 to the new stack base
   sw a0,-36(s0)    ; Save base (a0) to -36(s0)
   sw a1,-40(s0)    ; Save exponent (a1) to -40(s0)
   ```

2. **Check if exponent is zero (base case):**
   ```assembly
   lw a5,-40(s0)    ; Load exponent into a5
   bne a5,zero,12   ; If exponent is not zero, jump to L2
   li a5,1          ; Load immediate 1 into a5 (base^0 = 1)
   j 88             ; Jump to L3 to return result
   ```

3. **Recursive case (L2):**
   ```assembly
   lw a5,-40(s0)    ; Load exponent into a5
   addi a5,a5,-1    ; Decrement exponent by 1
   mv a1,a5         ; Move decremented exponent to a1
   lw a0,-36(s0)    ; Load base into a0
   auipc x1,0       ; Adjust for function call
   jalr x1,-56(x1)  ; Call power function recursively
   ```

4. **Store intermediate result and initialize loop variables:**
   ```assembly
   sw a0,-28(s0)    ; Store result of recursive call at -28(s0)
   sw zero,-20(s0)  ; Initialize multiplication accumulator to 0 at -20(s0)
   sw zero,-24(s0)  ; Initialize loop counter to 0 at -24(s0)
   j 32             ; Jump to L4 to start loop
   ```

5. **Loop to multiply the base with itself (L4 and L5):**
   ```assembly
   lw a4,-20(s0)    ; Load accumulator into a4 (L5)
   lw a5,-28(s0)    ; Load recursive result into a5
   add a5,a4,a5     ; Add a4 and a5
   sw a5,-20(s0)    ; Store result back to -20(s0)
   lw a5,-24(s0)    ; Load loop counter into a5
   addi a5,a5,1     ; Increment loop counter
   sw a5,-24(s0)    ; Store loop counter
   lw a4,-24(s0)    ; Load loop counter into a4 (L4)
   lw a5,-36(s0)    ; Load base into a5
   blt a4,a5,-36    ; If loop counter < base, jump to L5
   ```

6. **Finish and return (L3):**
   ```assembly
   lw a5,-20(s0)    ; Load final result into a5
   mv a0,a5         ; Move result to a0
   lw ra,44(sp)     ; Restore return address
   lw s0,40(sp)     ; Restore s0
   addi sp,sp,48    ; Deallocate stack space
   jr ra            ; Return from function
   ```

### Differences Between the Two Assembly Codes (32 and 64)

1. **Stack Allocation and Register Saving:**
   - **32 bits:** Allocates 48 bytes of stack space and uses `sw` instructions to save registers.
   - **64 bits:** Allocates 64 bytes of stack space and uses `sd` instructions to save registers.

2. **Parameter Handling:**
   - **32 bits:** Saves base and exponent directly using `sw`.
   - **64 bits:** Moves the values of base and exponent to `a5` and then saves them using `sw`.

3. **Base Case Handling:**
   - **32 bits:** Uses `bne` to check if the exponent is zero.
   - **64 bits:** Uses `sext.w` to sign-extend the exponent and then checks if it is zero with `bne`.

4. **Recursive Case Handling:**
   - **32 bits:** Directly decrements the exponent and calls the power function.
   - **64 bits:** Sign-extends the decremented exponent before the recursive call.

5. **Intermediate Result Storage:**
   - **32 bits:** Stores intermediate results using `sw`.
   - **64 bits:** Stores intermediate results using `sd`.

6. **Loop Variables Initialization:**
   - **32 bits:** Initializes loop variables using `sw`.
   - **64 bits:** Initializes loop variables using `sd` for the accumulator and `sw` for the loop counter.

7. **Loop to Multiply the Base with Itself:**
   - **32 bits:** Uses `lw` to load values and `sw` to store results.
   - **64 bits:** Uses `ld` to load values and `sd` to store results.

8. **Final Result Handling:**
   - **32 bits:** Uses `lw` to load the final result and `mv` to move it to `a0`.
   - **64 bits:** Uses `ld` to load the final result and `mv` to move it to `a0`.

9. **Main Function Stack Management:**
   - **32 bits:** Allocates 32 bytes of stack space and uses `sw` to save registers.
   - **64 bits:** Allocates 48 bytes of stack space and uses `sd` to save registers.

10. **Function Call Arguments:**
    - **32 bits:** Directly loads and passes the base and exponent.
    - **64 bits:** Uses `ld` to load base and exponent from memory before the function call.
