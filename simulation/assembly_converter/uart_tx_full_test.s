lui  sp,4096     ; ram base address 
lui  s0,65555    ; uart_0 base address
lui  x28,112     ; receive watermark level
ori  x28,x28,1   ; rxen
sw   x28,12(s0)  ; configuring receive control register
ori  x28,x28,2   ; {nstop,txen}
sw   x28,8(s0)   ; configuring transmit control register
sw   x28,16(s0)  ; configuring interrupt enable register
or   x28,x0,x0   ; infinite loop initialization
lw   x29,0(s0)   ; infinite loop
srli x29,x29,31  ; tx fifo full
bne  x29,x0,8    ; if fifo full, end loop
sw   x28,0(s0)   ; store word
addi x28,x28,1   ; loop increment
jal  x0,-10      ; loop
or   x28,x0,x0   ; writes zero to RAM
sw   x28,0(sp)   
