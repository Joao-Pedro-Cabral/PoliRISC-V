TOPLEVEL= "left_barrel_shifter"

action   = "simulation"
sim_tool = "modelsim"
sim_top  = TOPLEVEL + "_tb"

vlog_opt = " -vlog01compat"

sim_post_cmd = "vsim -do vsim.do -voptargs=+acc " + sim_top

modules = {
    "local" : [
        "../testbench"
    ],
}
