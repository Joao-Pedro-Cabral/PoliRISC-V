extensions_map = {"control_unit_tb": ["RV64I", "ZICSR", "TrapReturn"],
                  "core_tb": ["RV64I", "ZICSR", "TrapReturn"],
                  "Dataflow_tb": ["RV64I", "ZICSR", "TrapReturn"],
                  "memory_controller_tb": ["UART_0"],
                  "RV32I_uart_tb": ["UART_0"]}

tops_with_mifs = ["core_tb", "Dataflow_tb", "control_unit_tb"]
