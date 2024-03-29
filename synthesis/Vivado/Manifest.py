# Board: Xilinx Nexys 4-DDR
target = "xilinx"
action = "synthesis"

syn_family = "Artix 7"
syn_device = "xc7a100t"
syn_grade = "-1"
syn_package = "csg324"
syn_top = "litex_core" + "_top"
syn_project = syn_top
syn_tool = "vivado"
program_fpga = False  # False: open Vivado
lista_de_macros = ["NEXYS4", "LITEX", "ZICSR", "M", "TrapReturn"]
lista_de_mifs = ["memory/ROM/zeros.mif", "memory/ROM/bios/nexys4ddr_bios.mif"]

# gerar arquivo de macros
macros_file = open("../../simulation/extensions.vh", 'w')
for macro in lista_de_macros:
    macros_file.write("`define " + macro + '\n')
macros_file.close()

# generate constraints tcl file
constrains_file = open("constraints.tcl", 'w')
constrains_file.write("open_project " + syn_top +
                      ".xpr\nadd_files -fileset constrs_1 -norecurse ./constraints/" + syn_top + ".xdc\n")
for mif in lista_de_mifs:
    constrains_file.write(
        "add_files -norecurse ../../simulation/MIFs/" + mif + "\n")
constrains_file.write(
    "set_property target_language Verilog [current_project]\nexit")

# generate program tcl file
hw_device = syn_device + "_0"
program_comands = ["open_project " + syn_top + ".xpr\n",
                   "open_hw_manager\n",
                   "connect_hw_server -allow_non_jtag\n",
                   "open_hw_target\n",
                   "set_property PROGRAM.FILE {./" + syn_top + ".runs/impl_1/" +
                   syn_top + ".bit} [get_hw_devices " + hw_device + "]\n",
                   "current_hw_device [get_hw_devices " + hw_device + "]\n",
                   "refresh_hw_device -update_hw_probes false [lindex [get_hw_devices " + hw_device + "] 0]\n",
                   "set_property PROBES.FILE {}  [get_hw_devices " +
                   hw_device + "]\n",
                   "set_property FULL_PROBES.FILE {} [get_hw_devices " +
                   hw_device + "]\n",
                   "program_hw_devices [get_hw_devices " + hw_device + "]\n",
                   "refresh_hw_device -update_hw_probes false [lindex [get_hw_devices " + hw_device + "] 0]\n",
                   "exit"]
program_file = open("program.tcl", "w")
if program_fpga:
    program_file.writelines(program_comands)
else:
    program_file.write("open_project " + syn_top + ".xpr\n")

syn_post_project_cmd = "vivado -mode tcl -source constraints.tcl"
if program_fpga:
    syn_post_bitstream_cmd = "vivado -mode tcl -source program.tcl"
else:
    syn_post_bitstream_cmd = "vivado -source program.tcl"

modules = {
    "local": [
        "../../toplevel/core/core"
    ],
}
