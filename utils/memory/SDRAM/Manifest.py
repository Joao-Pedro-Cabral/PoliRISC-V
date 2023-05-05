files = [
    "edge_detector.v",
    "hexa7seg.v",
    "sdram_tester_df.v",
    "sdram_tester_uc.v",
    "sdram_tester.v"
]

modules = {
    "local" : [
        "../../../rtl/memory/SDRAM",
        "../../../rtl/core/RegisterFile"
    ],
}