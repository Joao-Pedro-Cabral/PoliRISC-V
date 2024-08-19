extensions_map = {"control_unit_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "core_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "dataflow_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "uart_tb": ["LITEX"]}

tops_with_mifs = ["core_tb", "dataflow_tb"]

excluded_tops = ["RV32I_litex_de10nano_tb", "RV32I_litex_nexys4ddr_tb", "RV32I_uart_tb",
                 "multiplier_top_tb", "sdram_controller_tb"]
