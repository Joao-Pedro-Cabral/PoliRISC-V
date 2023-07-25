open_project sd_controller_top.xpr
add_files -fileset constrs_1 -norecurse ./constraints/sd_controller_top.xdc
set_property target_language Verilog [current_project]
exit