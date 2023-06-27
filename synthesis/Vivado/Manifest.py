# Board: Xilinx Nexys 4-DDR
target = "xilinx"
action = "synthesis"

syn_family = "Artix 7"
syn_device = "xc7a100t"
syn_grade = "-1"
syn_package = "csg324"
syn_top = "uart_echo" + "_top"
syn_project = syn_top
syn_tool = "vivado"

# generate constrains tcl file
constrains_tcl_file = open("my_constrains_tcl.tcl", 'w')
constrains_tcl_file.write("open_project " + syn_top + ".xpr\nadd_files -fileset constrs_1 -norecurse ./constrains/" + syn_top + ".xdc\nexit")

# generate program tcl file
hw_device = syn_device + "_0"
program_comands = ["open_project " + syn_top + ".xpr\n",
                   "open_hw_manager\n",
                   "connect_hw_server -allow_non_jtag\n",
                   "open_hw_target\n", 
                   "set_property PROGRAM.FILE {./" + syn_top + ".runs/impl_1/" + syn_top + ".bit} [get_hw_devices " + hw_device + "]\n",
                   "current_hw_device [get_hw_devices " + hw_device + "]\n",
                   "refresh_hw_device -update_hw_probes false [lindex [get_hw_devices " + hw_device + "] 0]\n",
                   "set_property PROBES.FILE {}  [get_hw_devices " + hw_device +"]\n",
                   "set_property FULL_PROBES.FILE {} [get_hw_devices " + hw_device +"]\n",
                   "program_hw_devices [get_hw_devices " + hw_device +"]\n",
                   "refresh_hw_device -update_hw_probes false [lindex [get_hw_devices " + hw_device + "] 0]\n",
                   "exit"]
program_tcl_file = open("program_file.tcl", "w")
program_tcl_file.writelines(program_comands)

syn_post_project_cmd = "vivado -mode tcl -source my_constrains_tcl.tcl"
syn_post_bitstream_cmd = "vivado -mode tcl -source program_file.tcl"

modules = {
    "local" : [ 
        "../../toplevel" 
    ],
}
