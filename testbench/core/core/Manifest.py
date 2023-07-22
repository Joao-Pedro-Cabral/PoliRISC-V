files = [
    "RV64I_tb.v",
    "RV32I_tb.v",
    "RV32I_uart_tb.v"
]

modules = {
    "local" : [
        "../../../rtl/core/core",
        "../../../rtl/core/ImmediateExtender",
        "../../../rtl/core/RegisterFile",
        "../../../rtl/memory/Cache",
        "../../../rtl/memory/Controller",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/ROM",
        "../../../rtl/peripheral/UART"
    ],
}
