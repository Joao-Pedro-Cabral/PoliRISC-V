
action = "simulation"
sim_tool = "modelsim"
sim_top = "sync_parallel_counter" + "_tb"
use_mif = True
gui_mode = True
mif_name = "set_less_than32" + ".mif"
rom_mif_path = "./MIFs/memory/ROM/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/" + mif_name
lista_de_macros = ["UART_0"]
vsim_args = " -do vsim_gui.do -voptargs=+acc " if gui_mode else " -quiet -c -do vsim_tcl.do "

# gerar arquivo de macros
macros_file = open("macros.vh", 'w')
macros_file.write("`default_nettype none\n")
macros_file.write("`timescale 1ns / 1ns\n")
for macro in lista_de_macros:
    macros_file.write("`define " + macro + '\n')
macros_file.close()

vlog_opt = " -vlog01compat"

if use_mif:  # if the testbench needs a mif file
    sim_pre_cmd = ("ln -fs " + rom_mif_path + " ./ROM.mif" + ";"
                   "ln -fs " + ram_mif_path + " ./RAM.mif")

if use_mif:
    sim_post_cmd = ("vsim" + vsim_args + sim_top + ";"
                    "rm " + " ./ROM.mif" + ";"
                    "rm " + " ./RAM.mif")
else:
    sim_post_cmd = "vsim" + vsim_args + sim_top

modules = {
    "local": [
        "../testbench"
    ],
}
