import subprocess

action   = "simulation"
sim_tool = "modelsim"
sim_top  = "sdram_controller_tb"
use_mif  = True
mif_name = "set_less_than.mif"
rom_mif_path = "./MIFs/memory/ROM/" + mif_name
ram_mif_path = "./MIFs/memory/RAM/" + mif_name

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
