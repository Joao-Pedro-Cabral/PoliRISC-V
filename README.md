# PoliRISC-V

<!--toc:start-->
- [PoliRISC-V](#polirisc-v)
  - [Description](#description)
  - [Directory Structure](#directory-structure)
  - [Basic Usage](#basic-usage)
    - [Pre-requisites](#pre-requisites)
    - [Simulation](#simulation)
    - [Synthesis](#synthesis)
  - [Authors](#authors)
  - [Acknowledgments](#acknowledgments)
<!--toc:end-->

## Description

This project hosts the SystemVerilog description of a RISC-V processor developed at the Polytechnic School of the University of São Paulo. The following extensions are implemented:

- RV{32,64}I
- Zicsr
- TrapReturn
- RV{32,64}M

## Directory Structure

The repository's main structure is organized as follows:
```
.
├── README.md
├── rtl/
├── simulation/
├── synthesis/
├── testbench/
├── toplevel/
└── utils/
```

Each directory hosts the following resources:

- rtl: SystemVerilog descriptions of the processor's components;
- simulation: simulation files and scripts;
- synthesis: synthesis files and scripts;
- testbench: SystemVerilog testbenches for the processor's components;
- toplevel: toplevel SystemVerilog descriptions for synthesis;
- utils: project-wide utilities

## Basic Usage

### Pre-requisites

- [Hdlmake](https://hdlmake.readthedocs.io/en/master/): HDLMake is an open-source tool that automates the generation of FPGA project files and their dependencies, streamlining the build process for hardware description languages (HDLs) like VHDL, Verilog and SystemVerilog.

- [Modelsim](https://www.intel.com/content/www/us/en/software-kit/750666/modelsim-intel-fpgas-standard-edition-software-version-20-1-1.html?): Simulation software (if you wish to simulate the project).

- [Quartus](https://www.intel.com/content/www/us/en/software-kit/785086/intel-quartus-prime-lite-edition-design-software-version-22-1-2-for-windows.html?)/[Vivado](https://www.xilinx.com/support/download.html): Synthesis software (if you wish to synthesize the project).

### Simulation

Edit the `sim_top` and `mif_name` variables of the file simulation/Manifest.py to configure the testbench. After that, proceed with the usual `hdlmake` and `make` commands. If you want, you can alter the `gui_mode` variable in order to run Modelsim with GUI (waveform) or on terminal mode.

Simulations run automatic assert-based tests. In general, You can find out if the test was successful by reading the log messages on the terminal.

### Synthesis

Inside the `synthesis/` directory, you will find directories for synthesizing the project on different FPGA vendors. Choose the correspondent vendor and modify the Manifest.py accordingly. You can change the path inside the `module` variable's `local` key to choose which toplevel you wish to synthesize. In case the synthesis tool does not recognize types and variables defined inside packages, you will need to change compilation order for package (pkg) files to be compiled before the rest of the project.

The toplevels available for synthesis can be found inside the `toplevel/` directory.

## Authors

- [Igor Pontes Tresolavy](https://www.linkedin.com/in/ipt/)
- [João Pedro Cabral Miranda](https://www.linkedin.com/in/jo%C3%A3o-pedro-cabral-miranda-390568212/)

## Acknowledgments

Many thanks to Prof. [Dr. Bruno Albertini](https://www.linkedin.com/in/bruno-albertini-b7baa58/) for the support given during development.
