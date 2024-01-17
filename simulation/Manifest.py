import subprocess

action = "simulation"
sim_tool = "modelsim"
sim_top = "CSR_mem" + "_tb"
use_mif = True
gui_mode = True
mif_name = "zicsr" + ".mif"
rom_mif_path = "./MIFs/memory/ROM/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/" + mif_name
lista_de_macros = ["ZICSR", "TrapReturn"]
vsim_args = " -do vsim_gui.do -voptargs=+acc " if gui_mode else " -quiet -c -do vsim_tcl.do "

# gerar arquivo de macros
macros_file = open("macros.vh", 'w')
for macro in lista_de_macros:
    macros_file.write("`define " + macro + ' \n')
macros_file.close()

vlog_opt = " -vlog01compat +define+program_size=" + \
    str(int(subprocess.check_output(["wc", "-l", rom_mif_path]).split()[0]))

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
