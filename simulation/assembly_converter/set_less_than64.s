lui sp,4096 ; main 
lui x5,1     
or sp,sp,x5     
addi sp,sp,-96
sd s0,88(sp)
addi s0,sp,96
sd zero,-24(s0)
li a5,3
sd a5,-32(s0)
sb zero,-33(s0)
li a5,-56
sb a5,-34(s0)
ld a4,-24(s0)
ld a5,-32(s0)
slt a5,a4,a5
andi a5,a5,0xff
sd a5,-48(s0)
ld a4,-32(s0)
ld a5,-24(s0)
slt a5,a4,a5
andi a5,a5,0xff
sd a5,-56(s0)
lbu a4,-33(s0)
lbu a5,-34(s0)
sext.w a4,a4
sext.w a5,a5
sltu a5,a4,a5
andi a5,a5,0xff
sb a5,-57(s0)
lbu a4,-34(s0)
lbu a5,-33(s0)
sext.w a4,a4
sext.w a5,a5
sltu a5,a4,a5
andi a5,a5,0xff
sb a5,-58(s0)
ld a5,-24(s0)
slti a5,a5,-1
andi a5,a5,0xff
sd a5,-72(s0)
ld a5,-32(s0)
slti a5,a5,-3
xori a5,a5,1
andi a5,a5,0xff
sd a5,-80(s0)
lbu a5,-34(s0)  ; a5 <-- 200
sltiu a5,a5,100 ; 200 < 100 ? 1 : 0 
andi a5,a5,0xff
sb a5,-81(s0)
lbu a5,-34(s0)  ; a5 <-- 200
sltiu a5,a5,300 ; 200 < 300 ? 1 : 0 
andi a5,a5,0xff  
sb a5,-82(s0)
li a5,0
mv a0,a5
ld s0,88(sp)
addi sp,sp,96
jr ra
