# Pseudocódigo para o Estado Execute da Unidade de Controle

Também são inclusas as identificações das unidades funcionais necessárias para a execução de cada instrução.

Os pseudocódigos se dividem por categoria de instrução. Atente-se ao fato de que, salvo menção em contrário, as operações são realizadas paralelamente, mesmo que estejam escritas sequencialmente no pseudocódigo.

## Registrador-Registrador

```c

if( opcode[3] == 0 )
    RegFile[rd] = ULA(funct7[5] & funct3, RegFile[rs1], RegFile[rs2]).result
else
    RegFile[rd] = ULA(funct7[5] & funct3, RegFile[rs1], RegFile[rs2]).result[31:0]

PC = PC + 4

```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- ULA
- Somador
- Contador de Programa (PC)
- Multiplexador 2x1

## Registrador-Immediato

- LUI

```c

RegFile[rd] = signExt(Imm[31:12] & 0b000000000000)
PC = PC + 4

```

- AUIPC

```c

RegFile[rd] = PC + signExt(Imm[31:12] & 0b000000000000)
PC = PC + 4

```

- Outras

```c

if( opcode[3] == 0 )
    RegFile[rd] = ULA(funct7[5] & funct3, RegFile[rs1], signExt(Imm[11:0])).result
else
    RegFile[rd] = ULA(funct7[5] & funct3, RegFile[rs1], signExt(Imm[11:0])).result[31:0]

PC = PC + 4

```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- Unidade de Estensão de Sinal (signExt)
- ULA
- Somador
- Contador de Programa (PC)
- Multiplexador 2x1

## Desvio Incondicional

- JAL

```c

RegFile[rd] = PC + 4
PC = ULA(0b0000, PC,  signExt(Imm[20:1] & 0b0)).result

```

- JALR

```c

RegFile[rd] = PC + 4
PC = ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result[63:1] & 0b0


```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- Unidade de Estensão de Sinal (signExt)
- ULA
- Somador
- Contador de Programa (PC)

## Desvio Condicional

```c

Cond = false

if( funct3 == 000 ) // BEQ
    Cond = ULA(0b1000, RegFile[rs1], RegFile[rs2]).zeroFlag

else if( funct3 == 001 ) // BNE
    Cond = not ULA(0b1000, RegFile[rs1], RegFile[rs2]).zeroFlag

else if( funct3 == 100 ) // BLT
    Cond = ULA(0b1000, RegFile[rs1], RegFile[rs2]).negativeFlag xor ULA(0b1000, RegFile[rs1], RegFile[rs2]).overflowFlag

else if( funct3 == 101 ) // BGE
    Cond = ULA(0b1000, RegFile[rs1], RegFile[rs2]).negativeFlag xnor ULA(0b1000, RegFile[rs1], RegFile[rs2]).overflowFlag

else if( funct3 == 110 ) // BLTU
    Cond = not ULA(0b1000, RegFile[rs1], RegFile[rs2]).carryFlag

else if( funct3 == 111 ) // BGEU
    Cond = ULA(0b1000, RegFile[rs1], RegFile[rs2]).carryFlag

PC = PC + (Cond ? signExt(Imm[12:1] & 0b0) : 4)

```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- ULA com flags
- Somador
- Unidade de Estensão de Sinal (signExt)
- Contador de Programa (PC)
- Multiplexador 8x1

## Load --- Carregamento de Dados da Memória

```c

if( funct3 == 000 ) // LB
    RegFile[rd] = signExt(DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][7:0])

else if( funct3 == 001 ) // LH
    RegFile[rd] = signExt(DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][15:0])

else if( funct3 == 010 ) // LW
    RegFile[rd] = signExt(DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][31:0])

else if( funct3 == 011 ) // LD
    RegFile[rd] = signExt(DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result])

else if( funct3 == 100 ) // LWU
    RegFile[rd] = DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][31:0]

PC = PC + 4

```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- ULA
- Somador
- Unidade de Estensão de Sinal (signExt)
- Contador de Programa (PC)
- Memória de Dados (DataMem)
- Multiplexador 4x1

## Store --- Armazenamento de Dados na Memória

```c

if( funct3 == 000 ) // SB
    DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][7:0] = RegFile[rs2][7:0]

else if( funct3 == 001 ) // SH
    DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][15:0] = RegFile[rs2][15:0]

else if( funct3 == 010 ) // SW
    DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result][31:0] = RegFile[rs2][31:0]

else if( funct3 == 011 ) // SD
    DataMem[ULA(0b0000, RegFile[rs1], signExt(Imm[11:0])).result] = RegFile[rs2]

PC = PC + 4

```

### Unidades Funcionais Identificadas

- Banco de Registradores (RegFile)
- ULA
- Somador
- Unidade de Estensão de Sinal (signExt)
- Contador de Programa (PC)
- Memória de Dados (DataMem)
- Multiplexador 4x1

