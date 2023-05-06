import subprocess
TOPLEVEL= "sdram_tester"

action   = "simulation"
sim_tool = "modelsim"
sim_top  = TOPLEVEL + "_tb"
use_mif  = True
mif_path = "./MIFs/memory/ROM/set_less_than.mif"

vlog_opt = " -vlog01compat +define+program_size=" + str(int(subprocess.check_output(["wc", "-l", mif_path]).split()[0]))

if use_mif: #if the testbench needs a mif file
    sim_pre_cmd  = "ln -s " + mif_path + " ./" + TOPLEVEL + ".mif"

if use_mif: 
    sim_post_cmd = ("vsim -do vsim.do -voptargs=+acc " + sim_top + ";"
                    "rm " + " ./" + TOPLEVEL + ".mif")
else:
    sim_post_cmd = "vsim -do vsim.do -voptargs=+acc " + sim_top

modules = {
    "local" : [
        "../testbench"
    ],
}
