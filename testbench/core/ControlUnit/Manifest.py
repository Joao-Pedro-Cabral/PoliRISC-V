files = [
    "control_unit_RV64I_tb.v",
    "control_unit_RV32I_tb.v"
]

modules = {
    "local": [
        "../../../rtl/core/ControlUnit",
        "../../../rtl/core/Dataflow",
        "../../../rtl/memory/Controller",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/ROM",
    ],
}
