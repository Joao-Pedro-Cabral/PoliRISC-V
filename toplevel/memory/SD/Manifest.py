files = [
    "sd_controller_top.sv",
    "sd_controller_test_driver.sv",
    "sd_controller_test_driver_pkg.sv"
]

modules = {
    "local": [
        "../../../rtl/memory/SD",
        "../../../utils/components",
        "../../../utils/globals",
    ]
}
