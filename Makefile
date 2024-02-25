create:
	touch simulation/macros.vh
	touch simulation/extensions.vh
	./edit_symbolic_links.sh create macros
	./edit_symbolic_links.sh create extensions
clean:
	./edit_symbolic_links.sh remove macros
	./edit_symbolic_links.sh remove extensions