files = [
    "litex_core_top.v",
    "litedram_core.v",
    "csr_and_clint.v"
]

modules = {
    "local": [
        "../../../rtl/peripheral/UART",
        "../../../rtl/core/core",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/SD"
    ]
}
