
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#
.ONESHELL:
#SHELL=/bin/bash

WRAPPERDEST=..

USER := ${shell whoami}

targets = wipmi   wstorcli
sources = wipmi.c wstorcli.c

wrapper: $(targets)

$(targets) : $(sources)
	if [[ "$(USER)" != "root" ]] ; then		\
	    echo "Only root can create wrappers.";	\
	    echo "run as: sudo make";			\
	else						\
	    cc -o $@ $<;				\
	    cp $@ $(WRAPPERDEST);			\
	    chown root:root $(WRAPPERDEST)/$@;		\
	    chmod 755  $(WRAPPERDEST)/$@; 		\
	    chmod u+s  $(WRAPPERDEST)/$@;		\
	fi


clean:
	-rm -f *~ \#* *.bak *.tdy *.o 

distclean : clean
	rm -f $(targets) $(objects)

# ----------------------------------------------------------------------
# End of file