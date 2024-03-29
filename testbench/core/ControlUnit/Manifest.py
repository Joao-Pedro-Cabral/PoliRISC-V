files = [
    "control_unit_tb.v"
]

modules = {
    "local": [
        "../../../rtl/core/ControlUnit",
        "../../../rtl/core/Dataflow",
        "../../../rtl/memory/Controller",
        "../../../rtl/memory/RAM",
        "../../../rtl/memory/ROM",
        "../../../utils/globals"
    ],
}
