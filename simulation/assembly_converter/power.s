  j 92
  addi sp,sp,-64 ; power
  sd ra,56(sp)
  sd s0,48(sp)
  addi s0,sp,64
  mv a5,a0
  mv a4,a1
  sw a5,-52(s0)
  mv a5,a4
  sw a5,-56(s0)
  lw a5,-56(s0)
  sext.w a5,a5
  bne a5,zero,6  ; 6 --> L2
  li a5,1
  j 54           ; 54 --> L3
  lw a5,-56(s0)  ; L2
  addiw a5,a5,-1
  sext.w a4,a5
  lw a5,-52(s0)
  mv a1,a4
  mv a0,a5
  auipc x1,0     ; call power
  jalr x1,x1,-80 ; watch out!
  sd a0,-40(s0)
  sd zero,-24(s0)
  sw zero,-28(s0)
  j 16           ; 16 --> L4
  ld a4,-24(s0)  ; L5
  ld a5,-40(s0) 
  add a5,a4,a5
  sd a5,-24(s0) 
  lw a5,-28(s0) 
  addiw a5,a5,1 
  sw a5,-28(s0) 
  lw a5,-28(s0)  ; L4
  mv a4,a5
  lw a5,-52(s0) 
  sext.w a4,a4
  sext.w a5,a5
  blt a4,a5,-24  ; -12 --> L5
  ld a5,-24(s0) 
  mv a0,a5       ; L3
  ld ra,56(sp)
  ld s0,48(sp)
  addi sp,sp,64
  jr ra
  lui sp,16777216 ; main 
  lui x5,4096     
  or sp,sp,x5     
  addi sp,sp,-48  
  sd ra,40(sp)    
  sd s0,32(sp)
  addi s0,sp,48
  ld a5,-24(s0)
  lw a4,0(a5)
  ld a5,-32(s0)
  lw a5,0(a5)
  mv a1,a5
  mv a0,a4
  auipc x1,0      ; call power
  jalr x1,x1,-232 ; corrigir
  mv a4,a0
  ld a5,-40(s0)
  sd a4,0(a5)
  li a5,0
  mv a0,a5
  ld ra,40(sp)
  ld s0,32(sp)
  addi sp,sp,48
  jr ra
