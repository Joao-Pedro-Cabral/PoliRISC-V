onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Entradas
add wave -noupdate -color white /RV32I_uart_tb/DUT/clock
add wave -noupdate -color white /RV32I_uart_tb/DUT/reset
add wave -noupdate -color white /RV32I_uart_tb/DUT/external_interrupt
add wave -noupdate -color white /RV32I_uart_tb/DUT/msip
add wave -noupdate -color white /RV32I_uart_tb/DUT/mtime
add wave -noupdate -color white /RV32I_uart_tb/DUT/mtimecmp
add wave -noupdate -divider wish_ram
add wave -noupdate /RV32I_uart_tb/wish_ram/cyc
add wave -noupdate /RV32I_uart_tb/wish_ram/stb
add wave -noupdate /RV32I_uart_tb/wish_ram/we
add wave -noupdate /RV32I_uart_tb/wish_ram/ack
add wave -noupdate /RV32I_uart_tb/wish_ram/tgd
add wave -noupdate /RV32I_uart_tb/wish_ram/addr
add wave -noupdate /RV32I_uart_tb/wish_ram/sel
add wave -noupdate /RV32I_uart_tb/wish_ram/dat_i_p
add wave -noupdate /RV32I_uart_tb/wish_ram/dat_o_p
add wave -noupdate /RV32I_uart_tb/wish_ram/dat_i_s
add wave -noupdate /RV32I_uart_tb/wish_ram/dat_o_s
add wave -noupdate -divider wish_rom
add wave -noupdate /RV32I_uart_tb/wish_rom/cyc
add wave -noupdate /RV32I_uart_tb/wish_rom/stb
add wave -noupdate /RV32I_uart_tb/wish_rom/we
add wave -noupdate /RV32I_uart_tb/wish_rom/ack
add wave -noupdate /RV32I_uart_tb/wish_rom/tgd
add wave -noupdate /RV32I_uart_tb/wish_rom/addr
add wave -noupdate /RV32I_uart_tb/wish_rom/sel
add wave -noupdate /RV32I_uart_tb/wish_rom/dat_i_p
add wave -noupdate /RV32I_uart_tb/wish_rom/dat_o_p
add wave -noupdate /RV32I_uart_tb/wish_rom/dat_i_s
add wave -noupdate /RV32I_uart_tb/wish_rom/dat_o_s
add wave -noupdate -divider wish_uart
add wave -noupdate /RV32I_uart_tb/wish_uart/cyc
add wave -noupdate /RV32I_uart_tb/wish_uart/stb
add wave -noupdate /RV32I_uart_tb/wish_uart/we
add wave -noupdate /RV32I_uart_tb/wish_uart/ack
add wave -noupdate /RV32I_uart_tb/wish_uart/tgd
add wave -noupdate /RV32I_uart_tb/wish_uart/addr
add wave -noupdate /RV32I_uart_tb/wish_uart/sel
add wave -noupdate /RV32I_uart_tb/wish_uart/dat_i_p
add wave -noupdate /RV32I_uart_tb/wish_uart/dat_o_p
add wave -noupdate /RV32I_uart_tb/wish_uart/dat_i_s
add wave -noupdate /RV32I_uart_tb/wish_uart/dat_o_s
add wave -noupdate -divider uart
add wave -noupdate /RV32I_uart_tb/uart_0/div_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_pending_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_pending_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_pending_en_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_pending_en_db
add wave -noupdate /RV32I_uart_tb/uart_0/txcnt_db
add wave -noupdate /RV32I_uart_tb/uart_0/rxcnt_db
add wave -noupdate /RV32I_uart_tb/uart_0/txen_db
add wave -noupdate /RV32I_uart_tb/uart_0/rxen_db
add wave -noupdate /RV32I_uart_tb/uart_0/nstop_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_fifo_empty_db
add wave -noupdate /RV32I_uart_tb/uart_0/rxdata_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_fifo_full_db
add wave -noupdate /RV32I_uart_tb/uart_0/txdata_db
add wave -noupdate /RV32I_uart_tb/uart_0/present_state_db
add wave -noupdate /RV32I_uart_tb/uart_0/addr_db
add wave -noupdate /RV32I_uart_tb/uart_0/wr_data_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_data_valid_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_data_valid_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_rdy_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_watermark_reg_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_watermark_reg_db
add wave -noupdate /RV32I_uart_tb/uart_0/tx_status_db
add wave -noupdate /RV32I_uart_tb/uart_0/rx_status_db
add wave -noupdate -divider wish_cache_data0
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/cyc
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/stb
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/we
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/ack
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/tgd
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/addr
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/sel
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/dat_i_p
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/dat_o_p
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/dat_i_s
add wave -noupdate /RV32I_uart_tb/wish_cache_data0/dat_o_s
add wave -noupdate -divider other
add wave -noupdate /RV32I_uart_tb/DUT/controlUnit/opcode
add wave -noupdate -radix decimal /RV32I_uart_tb/DUT/data_flow/pc
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 344
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {2254 ns}
