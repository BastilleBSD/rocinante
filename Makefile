.PHONY: all
all:
	@echo "Nothing to be done. Please use make install or make uninstall"
.PHONY: install
install:
	@echo "Installing Rocinante"
	@echo
	@cp -Rv usr /
	@echo
	@echo "This method is for testing / development."

.PHONY: uninstall
uninstall:
	@echo "Removing Rocinante command"
	@rm -vf /usr/local/bin/rocinante
	@echo
	@echo "Removing Bastille sub-commands"
	@rm -rvf /usr/local/libexec/rocinante
	@echo
	@echo "removing configuration file"
	@rm -rvf /usr/local/etc/rocinante.conf.sample
	@echo
	@echo "You may need to manually remove /usr/local/etc/rocinante.conf if it is no longer needed."
