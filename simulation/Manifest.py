TOPLEVEL = "sklansky_adder"
MODULES  = "../testbench/core/Adder"

action   = "simulation"
sim_tool = "modelsim"
sim_top  = TOPLEVEL + "_tb"

sim_post_cmd = "vsim -do vsim.do -voptargs=+acc " + sim_top

modules = {
    "local" : [
        MODULES
    ],
}