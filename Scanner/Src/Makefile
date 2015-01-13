
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#
.ONESHELL:
SHELL=/usr/bin/bash

USER := ${shell whoami}

wrapper: objects
	@ echo running as $(USER)
	@if [ "$(USER)" == "root" ] ; then
	    cp wipmi wstorcli ..
	    chown root:root ../wipmi ../wstorcli
	    sudo chmod 755 ../wipmi ../wstorcli
	    sudo chmod u+s ../wipmi ../wstorcli
	else
	    echo "Need to be root to create wrappers.";
	    echo "run as: sudo make";
	fi

objects  : wipmi wstorcli

wipmi    : wipmi.o

wstorcli :  wstorcli.o

clean:
	-rm -rf *~ \#* *.bak *.tdy

objects : wipmi.o wstorcli.o	
