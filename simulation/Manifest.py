import subprocess

action   = "simulation"
sim_tool = "modelsim"
sim_top  = "ROM" + "_tb"
use_mif  = True
mif_name = "rom_init_file_tb" + ".mif"
rom_mif_path = "./MIFs/memory/ROM/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/" + mif_name
lista_de_macros = ["UART_0"]

#gerar arquivo de macros
macros_file = open("macros.vh", 'w')
for macro in lista_de_macros:
    macros_file.write("`define " + macro + ' \n')
macros_file.close()

vlog_opt = " -vlog01compat +define+program_size=" + str(int(subprocess.check_output(["wc", "-l", rom_mif_path]).split()[0]))

if use_mif: #if the testbench needs a mif file
    sim_pre_cmd  = ("ln -s " + rom_mif_path + " ./ROM.mif" + ";"
    		    "ln -s " + ram_mif_path + " ./RAM.mif")

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
