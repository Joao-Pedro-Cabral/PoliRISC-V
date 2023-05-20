files = [
    "control_unit_RV64I_tb.v",
    "control_unit_RV32I_tb.v"
]

modules = {
    "local": [
        "../../../rtl/core/ControlUnit",
        "../../../rtl/core/ImmediateExtender",
        "../../../rtl/core/RegisterFile",
        "../../../rtl/memory/ROM",
        "../../../rtl/memory/Cache"
    ],
}
