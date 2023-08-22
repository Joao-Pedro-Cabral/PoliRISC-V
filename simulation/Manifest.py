import subprocess
import os

action   = "simulation"
sim_tool = "modelsim"
sim_top  = "core" + "_tb"
use_mif  = True
mif_name = "set_less_than32" + ".mif"
rom_mif_path = "./MIFs/memory/ROM/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/" + mif_name
lista_de_macros = ["RV64I"]

#gerar arquivo de macros
macros_file = open("macros.vh", 'w')
for macro in lista_de_macros:
    macros_file.write("`define " + macro + ' \n')
macros_file.close()

vlog_opt = " -vlog01compat +define+program_size=" + str(int(subprocess.check_output(["wc", "-l", rom_mif_path]).split()[0]))

if use_mif: #if the testbench needs a mif file
  sim_pre_cmd  = ("ln -fs " + rom_mif_path + " ./ROM.mif" + ";"
    		  "ln -fs " + ram_mif_path + " ./RAM.mif")

if use_mif: 
    sim_post_cmd = ("vsim -do vsim.do -voptargs=+acc " + sim_top + ";"
                    "rm " + " ./ROM.mif" + ";"
                    "rm " + " ./RAM.mif")
else:
    sim_post_cmd = "vsim -do vsim.do -voptargs=+acc " + sim_top

modules = {
    "local" : [
        "../testbench"
    ],
}
