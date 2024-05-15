files = [
    "dataflow_tb.sv",
    "dataflow_tb_pkg.sv"
]

modules = {
    "local": [
        "../../../rtl/core/CSR",
        "../../../rtl/core/Dataflow",
        "../../../rtl/core/ImmediateExtender",
        "../../../rtl/core/RegisterFile",
        "../../../rtl/core/ControlUnit",
        "../../../rtl/core/HazardUnit",
        "../../../rtl/core/ForwardingUnit",
        "../../../rtl/core/MemoryUnit",
        "../../../rtl/memory/Cache",
        "../../../rtl/memory/ROM",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/Controller"
    ],
}
