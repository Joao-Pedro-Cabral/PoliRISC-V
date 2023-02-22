add wave -divider Entradas
add wave -in -color white /DUT/*
add wave -divider Saidas
add wave -out -color yellow /DUT/*
add log -r /*
run -all