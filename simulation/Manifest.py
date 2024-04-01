
action = "simulation"
sim_tool = "modelsim"
sim_top = "memory_unit_tb"
use_mif = False
gui_mode = True
mif_name = "branches.mif"
rom_mif_path = "./MIFs/memory/ROM/core/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/core.mif"
lista_de_extensoes = ["RV64I"]
vsim_args = " -do vsim_gui.do -voptargs=+acc " if gui_mode else " -c -do vsim_tcl.do "

# gerar arquivo de extensões
extension_file = open("extensions.vh", 'w')
for extensao in lista_de_extensoes:
    extension_file.write("`define " + extensao + '\n')
extension_file.close()

vlog_opt = " -define default_nettype=none"

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
<<<<<<< HEAD
        "../testbench/core/MemoryUnit"
=======
        "../testbench/core/ControlUnit"
>>>>>>> 8c84edd (Tesbench para UC 32 bits completo)
    ],
}
