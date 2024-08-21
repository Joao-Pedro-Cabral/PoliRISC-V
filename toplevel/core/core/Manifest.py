files = [
    "litex_core_top.sv",
    "litedram_core.v",
    "csr_and_clint.sv"
]

modules = {
    "local": [
        "../../../rtl/peripheral/UART",
        "../../../rtl/core/core",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/SD"
    ]
}
