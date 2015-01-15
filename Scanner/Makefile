
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#

.ONESHELL:
#SHELL := /bin/bash

USER  := ${shell /usr/bin/whoami}

wrapper:
	@echo "running as $(USER) - shell is $(SHELL)"
	@if [[ "$(USER)" == "root" ]] ; then			\
	    echo "Entering Src directory to make wrappers";	\
	    cd Src && $(MAKE);					\
	else							\
	    echo "Need to be root to create wrappers.";		\
	    echo "run as: sudo make";				\
	fi

test:
	prove t/*.t

clean:
	-rm -rf *~ \#* *.bak *.tdy


