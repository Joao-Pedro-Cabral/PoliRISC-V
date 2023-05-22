files = [
    "RV64I_tb.v",
    "RV32I_tb.v"
]

modules = {
    "local" : [
        "../../../rtl/memory",
        "../../../rtl/core/core",
        "../../../rtl/core/RegisterFile",
        "../../../rtl/core/ImmediateExtender",
        "../../../rtl/memory/Cache"
    ],
}
