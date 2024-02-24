create:
	touch simulation/macros.vh
	touch simulation/extensions.vh
	touch synthesis/Vivado/boards.vh
	./edit_symbolic_links.sh create macros
	./edit_symbolic_links.sh create extensions
	./edit_symbolic_links.sh create boards
clean:
	./edit_symbolic_links.sh remove macros
	./edit_symbolic_links.sh remove extensions
	./edit_symbolic_links.sh remove boards