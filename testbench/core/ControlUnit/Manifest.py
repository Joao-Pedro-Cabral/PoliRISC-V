files = [
    "control_unit_tb.sv"
]

modules = {
    "local": [
        "../../../rtl/core/ControlUnit",
        "../../../rtl/core/BranchDecoderUnit",
        "../../../rtl/core/ForwardingUnit",
        "../../../rtl/core/HazardUnit",
        "../../../rtl/core/ALU",
        "../../../utils/globals"
    ],
}
