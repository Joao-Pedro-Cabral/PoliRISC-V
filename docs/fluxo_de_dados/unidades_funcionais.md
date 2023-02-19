# Identificação das Unidades Funcionais do Fluxo de Dados

A partir do [pseudocódigo do estado de Execute](../pseudocodigos/pseudocodigos_execute.md) da Unidade de Controle, obtiveram-se as seguintes Unidades Funcionais:

- Banco de Registradores (RegFile)
- Contador de Programa (PC)
- Memória de Dados (DataMem)
- Multiplexador 2x1
- Multiplexador 4x1
- Multiplexador 8x1
- Somador
- ULA com flags
- Unidade de Estensão de Sinal (signExt)

A seguir, definiram-se as interfaces iniciais de cada componente. Salvo menção em contrário, todos as entradas e saídas são de 64 bits para as arquiteturas RV64 e de 32 bits para as arquiteturas RV32.

## Banco de Registradores

Entradas:

    - Entrada de dados `rs1`;
    - Entrada de dados `rs2`.

Saídas:

    - Saída de dados `rsd`.

## Contador de Programa

Entradas:

    - Entrada de dados `pc_in`.

Saídas:

    - Saída de dados `pc_out`.

## Memória de Dados

Entradas:

    - Entrada de endereçamento `data_addr`;
    - Entrada de dados `data_in`;
    - Entrada de tamanho de transferência `transf_size`, de __3 bits__.

`transf_size` define se a escrita ou leitura será de um byte, meia palavra (16 bytes), uma palavra (32 bits) ou uma dupla palavra (64 bits).

Saídas:

    - Saída de dados `data_out`.


## Multiplexador 2x1

Dado que é comum que haja muitos multiplexadores em um circuito digital, pode-se nomeá-los de acordo com suas funções. Esse será nomeado de `alu_out` por motivos explicados [aqui](interconexoes_do_fluxo_de_dados.md).

Entradas:

    - Entrada de dados `a`.
    - Entrada de dados `b`;
    - seletor `s`, de __1 bit__.

Saídas:

    - Saída de dados `y`.

O seletor escolhe qual entrada será direcionada a saída `y` do multiplexador.

## Multiplexador 4x1

Multiplexador `mem_in`

Entradas:

    - Entrada de dados `a`;
    - Entrada de dados `b`;
    - Entrada de dados `c`;
    - Entrada de dados `d`;
    - seletor `s`, de __2 bits__.


Saídas:

    - Saída de dados `y`.

## Multiplexador 8x1

Multiplexador `mem_out`

Entradas:

    - Entrada de dados `a`;
    - Entrada de dados `b`;
    - Entrada de dados `c`;
    - Entrada de dados `d`;
    - Entrada de dados `e`;
    - Entrada de dados `f`;
    - Entrada de dados `g`;
    - Entrada de dados `h`;
    - seletor `s` de __3 bits__.


Saídas:

    - Saída de dados `y`.

## Somador

Entradas:

    - Entrada de dados `a`;
    - Entrada de dados `b`.
    - Entrada de _carry_ `c_in`, de __1 bit__.

Saídas:

    - Saída de dados `y`
    - Saída de _carry_ `c_out`, de __1 bit__.


## ULA com Flags

Entradas:

    - Entrada de dados `a`;
    - Entrada de dados `b`;
    - Seletor de operação `seletor`, de __4 bits__.

Saídas:

    - Saída de dados `y`;
    - Saída de _carry_/_flag_ `c_out`, de __1 bit__;
    - Saída de _flag_ `zero`, de __1 bit__;
    - Saída de _flag_ `negative`, de __1 bit__;
    - Saída de _flag_ `overflow`, de __1 bit__.

## Unidade de Estensão de Sinal

Entradas:

    - Entrada para a instrução `instruction`, de __32 bits__;

Saídas:

    - Saída para o imediato da instrução com sinal estendido `immediate`.
