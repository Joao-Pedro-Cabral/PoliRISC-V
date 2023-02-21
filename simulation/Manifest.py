TOPLEVEL = 'Dataflow'

action   = "simulation"
sim_tool = "model_sim"
sim_top  = TOPLEVEL + "_tb"

sim_post_cmd = "vsim -do vsim.do -voptargs=+acc" + sim_top

modules = {
    "local" : [
        "../testbench"
    ],
}