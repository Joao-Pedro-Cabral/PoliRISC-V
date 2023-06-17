files = [
    "sdram_controller_tb.v",
    "sdram_tester_tb.v",
    "sdram_tester2_tb.v",
    "sync_parallel_counter_tb.v"
]

modules = {
    "local" : [
        "../../../rtl/memory/SDRAM",
        "../../../utils/memory/SDRAM"
    ]
}
