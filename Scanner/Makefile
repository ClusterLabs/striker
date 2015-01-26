
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
TOOLDIR    = /var/www/tools

DIRS       = $(TEXTBASE) $(CONFDIR) $(MSGDIR) $(CODEBASE) $(BINDIR) \
	     $(AGENTDIR) $(LIBDIR) $(LOGDIR)

WRAPPERS   = wipmi wstorcli 
SHUTDOWN   = wshutdown

wrapper: 
	cd Src && $(MAKE) 

dirs    : $(DIRS)

$(DIRS)	:
	[[ -x $@ ]] || mkdir -p $@

files 	: scanner agents libs configs messages $(WRAPPERS) $(SHUTDOWN)

$(WRAPPERS): wrapper
	cp $@ $(BINDIR)
	chown root:root $(BINDIR)/$@; 
	chmod 755  $(BINDIR)/$@;
	chmod u+s  $(BINDIR)/$@;

$(SHUTDOWN): wrapper
	cp $@ $(TOOLDIR)
	chown root:root $(TOOLDIR)/$@; 
	chmod 755  $(TOOLDIR)/$@;
	chmod u+s  $(TOOLDIR)/$@;

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



install: wrapper dirs files scanner  $(SHUTDOWN)
	@if [[ "$(USER)" == "root" ]] ; then		\
	    cp scanner $(BINDIR);			\
            chmod 777 /var/log/striker;			\
	else						\
	    echo "Need to be root to create wrappers.";	\
	    echo "run as: sudo make";			\
	fi


clean:
	-rm -rf *~ #* .#*  *.bak *.tdy
	cd Src && $(MAKE) clean

distclean: clean
	rm -rf $(WRAPPERS)
	cd Src && $(MAKE) distclean

uninstall: clean distclean
	rm -rf $(TEXTBASE) $(CODEBASE) $(LOGDIR)


# ----------------------------------------------------------------------
# End of file

