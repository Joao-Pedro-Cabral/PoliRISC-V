files = [
    "Dataflow_RV64I_tb.v",
    "Dataflow_RV32I_tb.v"
]

modules = {
    "local": [
        "../../../rtl/core/Dataflow",
        "../../../rtl/core/ImmediateExtender",
        "../../../rtl/core/RegisterFile",
        "../../../rtl/memory/ROM",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/Controller"
    ],
}
