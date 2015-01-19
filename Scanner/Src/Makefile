
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#
.ONESHELL:
#SHELL=/bin/bash

USER := ${shell whoami}

targets = wipmi   wstorcli   wshutdown
sources = wipmi.c wstorcli.c wshutdown.c

wrapper: $(targets)

$(targets) : $(sources)
	if [[ "$(USER)" != "root" ]] ; then		\
	    echo "Only root can create wrappers.";	\
	    echo "run as: sudo make";	\
	else				\
	    gcc -g -o ../$@ $@.c;	\
	    chown root:root ../$@;	\
	    chmod 755  ../$@; 		\
	    chmod u+s  ../$@;		\
	fi


clean:
	-rm -f *~ \#* *.bak *.tdy *.o 

distclean : clean
	rm -f $(targets) $(objects)

# ----------------------------------------------------------------------
# End of file
