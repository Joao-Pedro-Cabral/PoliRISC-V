# PoliRISC-V

## Description

This project hosts the Verilog description of a RISC-V processor developed at the Polytechnic School of the University of São Paulo. The following extensions are implemented:

- RV32I
- RV64I
- Zicsr

## Directory Structure

The repository's structure is organized as follows:
```
.
├── docs/
├── README.md
├── rtl/
├── simulation/
├── synthesis/
├── testbench/
├── toplevel/
├── utils/
└── verible.filelist
```

Each directory hosts the following resources:

- docs: documentation for the project;
- rtl: Verilog descriptions of the processor's components;
- simulation: simulation files and scripts;
- synthesis: synthesis files and scripts;
- testbench: Verilog testbenches for the processor's components;
- toplevel: toplevel Verilog descriptions for synthesis;
- utils: project-wide utilities

## Basic Usage

### Pre-requisites

- [Hdlmake](https://hdlmake.readthedocs.io/en/master/): Framework for organize the repository.

- [Modelsim](https://www.intel.com/content/www/us/en/software-kit/750666/modelsim-intel-fpgas-standard-edition-software-version-20-1-1.html?): Simulation software.

- [Quartus](https://www.intel.com/content/www/us/en/software-kit/785086/intel-quartus-prime-lite-edition-design-software-version-22-1-2-for-windows.html?)/[Vivado](https://www.xilinx.com/support/download.html): Synthesis software.

### Simulation

Edit the sim_top and mif_name variables of the file simulation/Manifest.py for configure the testbench.

## License

## Authors

- [Igor Pontes Tresolavy](https://www.linkedin.com/in/ipt/)
- [João Pedro Cabral Miranda](https://www.linkedin.com/in/jo%C3%A3o-pedro-cabral-miranda-390568212/)

## Acknowledgments

Many thanks to Prof. [Dr. Bruno Albertini](https://www.linkedin.com/in/bruno-albertini-b7baa58/).
