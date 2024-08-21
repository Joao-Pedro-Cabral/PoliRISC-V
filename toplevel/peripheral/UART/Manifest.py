files = [
    "uart_echo_top.v",
    "uart_top.sv",
    "uart_top_pkg.sv"
]

modules = {
    "local": [
        "../../../rtl/peripheral/UART",
        "../../../utils/7_segments",
        "../../../utils/components",
        "../../../utils/globals",
    ]
}
