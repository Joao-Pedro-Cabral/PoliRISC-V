onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Entradas
add wave -noupdate -color white /memory_controller_tb/DUT/inst_cache_data
add wave -noupdate -color white /memory_controller_tb/DUT/inst_cache_busy
add wave -noupdate -color white /memory_controller_tb/DUT/ram_read_data
add wave -noupdate -color white /memory_controller_tb/DUT/ram_busy
add wave -noupdate -color white /memory_controller_tb/DUT/mem_rd_en
add wave -noupdate -color white /memory_controller_tb/DUT/mem_wr_en
add wave -noupdate -color white /memory_controller_tb/DUT/mem_byte_en
add wave -noupdate -color white /memory_controller_tb/DUT/wr_data
add wave -noupdate -color white /memory_controller_tb/DUT/mem_addr
add wave -noupdate -divider Saidas
add wave -noupdate -color yellow /memory_controller_tb/DUT/inst_cache_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/inst_cache_addr
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_address
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_write_data
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_output_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_write_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_chip_select
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_byte_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/rd_data
add wave -noupdate -color yellow /memory_controller_tb/DUT/mem_busy
add wave -noupdate -divider Entradas
add wave -noupdate -color white /memory_controller_tb/DUT/inst_cache_data
add wave -noupdate -color white /memory_controller_tb/DUT/inst_cache_busy
add wave -noupdate -color white /memory_controller_tb/DUT/ram_read_data
add wave -noupdate -color white /memory_controller_tb/DUT/ram_busy
add wave -noupdate -color white /memory_controller_tb/DUT/mem_rd_en
add wave -noupdate -color white /memory_controller_tb/DUT/mem_wr_en
add wave -noupdate -color white /memory_controller_tb/DUT/mem_byte_en
add wave -noupdate -color white /memory_controller_tb/DUT/wr_data
add wave -noupdate -color white /memory_controller_tb/DUT/mem_addr
add wave -noupdate -divider Saidas
add wave -noupdate -color yellow /memory_controller_tb/DUT/inst_cache_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/inst_cache_addr
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_address
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_write_data
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_output_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_write_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_chip_select
add wave -noupdate -color yellow /memory_controller_tb/DUT/ram_byte_enable
add wave -noupdate -color yellow /memory_controller_tb/DUT/mem_busy
add wave -noupdate -color yellow /memory_controller_tb/DUT/rd_data
add wave -noupdate -divider {Cache in}
add wave -noupdate -color White /memory_controller_tb/cache/clock
add wave -noupdate -color White /memory_controller_tb/cache/inst_busy
add wave -noupdate -color White /memory_controller_tb/cache/inst_cache_addr
add wave -noupdate -color White /memory_controller_tb/cache/inst_cache_enable
add wave -noupdate -color White /memory_controller_tb/cache/inst_data
add wave -noupdate -color White /memory_controller_tb/cache/reset
add wave -noupdate -divider {Cache out}
add wave -noupdate -color Yellow /memory_controller_tb/cache/inst_addr
add wave -noupdate -color Yellow /memory_controller_tb/cache/inst_cache_busy
add wave -noupdate -color Yellow /memory_controller_tb/cache/inst_cache_data
add wave -noupdate -color Yellow /memory_controller_tb/cache/inst_enable
add wave -noupdate -color Yellow /memory_controller_tb/cache/hit
add wave -noupdate -divider {Cache internals}
add wave -noupdate /memory_controller_tb/cache/cache_data
add wave -noupdate /memory_controller_tb/cache/cache_tag
add wave -noupdate /memory_controller_tb/cache/index
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {60600 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 316
configure wave -valuecolwidth 172
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
WaveRestoreZoom {0 ps} {223100 ps}
