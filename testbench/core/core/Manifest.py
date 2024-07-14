files = [
    "core_tb.sv"
]

modules = {
    "local": [
        "../../../rtl/core/core",
        "../../../rtl/core/CSR",
        "../../../rtl/memory/Cache",
        "../../../rtl/memory/Controller",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/ROM"
    ],
}
