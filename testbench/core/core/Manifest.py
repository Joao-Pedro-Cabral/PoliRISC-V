files = [
    "core_tb.sv",
    "core_litex_de10nano_tb.sv",
    "core_litex_nexys4ddr_tb.sv",
    "core_uart_tb.sv"
]

modules = {
    "local": [
        "../../../rtl/core/core",
        "../../../rtl/core/CSR",
        "../../../rtl/memory/Cache",
        "../../../rtl/memory/Controller",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/ROM",
        "../../../rtl/peripheral/UART/",
    ],
}
