open_project uart_top.xpr
add_files -fileset constrs_1 -norecurse ./constraints/uart_top.xdc
set_property target_language Verilog [current_project]
exit