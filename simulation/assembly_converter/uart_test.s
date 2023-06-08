lui  sp,4096     ; ram base address 
lui  s0,65555    ; uart_0 base address
lui  x28,112     ; receive watermark level
ori  x28,x28,1   ; rxen
sw   x28,12(s0)  ; configuring receive control register
andi x28,x28,-3  ; {nstop,txen}
sw   x28,8(s0)   ; configuring transmit control register
ori  x28,x28,2   ; {txwm, rxwm}
sw   x28,16(s0)  ; configuring interrupt enable register
or   x28,x0,x0   ; inicialização do loop infinito
lw   x29,0(s0)   ; loop infinito
srli x29,x29,31  ; tx fifo full
bne  x29,x0,-4   ; if fifo full, check again
sw   x28,0(s0)   ; store word
lui  x30,-524288 ; bit mask for rx fifo's empty flag
lw   x29,4(s0)   ; read rx fifo
and  x31,x29,x30 ; apply mask
beq  x31,x0,-2   ; if fifo empty, check again
sub  x6,x28,x29  ; if equal to 0, value sent and received are the same
sw   x6,0(sp)    ; stores result in RAM
addi x28,x28,1   ; loop increment
jal  x0,-20      ; loop
