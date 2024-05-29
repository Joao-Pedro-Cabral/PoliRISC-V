files = [
    "dataflow.sv",
    "dataflow_pkg.sv"
]

modules = {
    "local": [
        "../Adder",
        "../CSR",
        "../ControlUnit",
        "../ImmediateExtender",
        "../RegisterFile",
        "../ALU",
        "../../../utils/components"
    ],
}
