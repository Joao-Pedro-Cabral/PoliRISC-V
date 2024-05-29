files = [
    "control_unit.sv",
    "control_unit_pkg.sv"
]

modules = {
    "local": [
        "../BranchDecoderUnit",
        "../ForwardingUnit",
        "../HazardUnit",
        "../ALU",
        "../CSR"
    ],
}
