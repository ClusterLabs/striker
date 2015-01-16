
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#

.ONESHELL:
#SHELL := /bin/bash

USER  := ${shell /usr/bin/whoami}

SYSTEMNAME = striker
TEXTBASE   = /etc/$(SYSTEMNAME)
CONFDIR    = $(TEXTBASE)/Config
MSGDIR     = $(TEXTBASE)/Messages
CODEBASE   = /usr/share/$(SYSTEMNAME)
BINDIR     = $(CODEBASE)/bin
AGENTDIR   = $(CODEBASE)/agents
LIBDIR     = $(CODEBASE)/lib
LOGDIR     = /var/log/$(SYSTEMNAME)

DIRS       = $(TEXTBASE) $(CONFDIR) $(MSGDIR) $(CODEBASE) $(BINDIR) \
	     $(AGENTDIR) $(LIBDIR) $(LOGDIR)

WRAPPERS   = wipmi wstorcli 

wrapper: 
	cd Src && $(MAKE) $(WRAPPERDEST)

dirs    : $(DIRS)

$(DIRS)	:
	[[ -x $@ ]] || mkdir -p $@

files 	: scanner agents libs configs messages $(WRAPPERS)

$(WRAPPERS): wrapper
	cp $@ $(BINDIR)
	chown root:root $(BINDIR)/$@; 
	chmod 755  $(BINDIR)/$@;
	chmod u+s  $(BINDIR)/$@;

scanner	:
	cp scanner $(BINDIR)

agents	: 
	cp Agents/* $(AGENTDIR)
	rm -f $(AGENTDIR)/random-agent

libs	:
	cp -r lib/* $(LIBDIR)


configs	:
	cp Config/* $(CONFDIR)

messages:
	cp Messages/* $(MSGDIR)



install: wrapper dirs files scanner
	@if [[ "$(USER)" == "root" ]] ; then		\
	    cp scanner $(BINDIR);			\
	else						\
	    echo "Need to be root to create wrappers.";	\
	    echo "run as: sudo make";			\
	fi


clean:
	-rm -f *~ \#* *.bak *.tdy
	cd Src && $(MAKE) clean

distclean: clean
	rm -f $(WRAPPERS)
	cd Src && $(MAKE) distclean

uninstall: clean distclean
	rm -rf $(TEXTBASE) $(CODEBASE) $(LOGDIR)


# ----------------------------------------------------------------------
# End of file

