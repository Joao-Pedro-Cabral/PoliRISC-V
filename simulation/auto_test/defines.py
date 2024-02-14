extensions_map = {"control_unit_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "core_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "Dataflow_tb": ["RV64I", "ZICSR", "TrapReturn", "M"],
                  "memory_controller_tb": ["UART_0"],
                  "RV32I_uart_tb": ["UART_0"]}

tops_with_mifs = ["core_tb", "Dataflow_tb", "control_unit_tb"]

excluded_tops = ["RV32I_litex_tb", "multiplier_top_tb", "sdram_controller_tb"]
