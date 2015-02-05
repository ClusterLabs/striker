
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
SHAREDDIR  = /shared/status

DIRS       = $(TEXTBASE) $(CONFDIR) $(MSGDIR) $(CODEBASE) $(BINDIR) \
	     $(AGENTDIR) $(LIBDIR) $(LOGDIR) $(SHAREDDIR) $(TOOLDIR) 

SPECSDIR   = $(HOME)/rpmbuild/SPECS 

SOURCESDIR = $(HOME)/rpmbuild/SOURCES

RPMDIRS    = $(HOME)/rpmbuild/BUILD   $(HOME)/rpmbuild/RPMS \
             $(SOURCESDIR) $(SPECSDIR) $(HOME)/rpmbuild/SRPMS

RPMBUILD   = $(HOME)/rpmbuild/BUILD/Scanner

WRAPPERS   = wipmi wstorcli 
SHUTDOWN   = wshutdown

wrapper: 
	cd Src && $(MAKE) 

dirs    : $(DIRS)

$(DIRS) :
	[[ -x $@ ]] || mkdir -p $@

$(RPMDIRS) :
	[[ -x $@ ]] || mkdir -p $@

$(RPMBUILD): $(RPMDIRS)
	[[ -x $@ ]] || mkdir -p $@

files 	: scanner agents libs configs messages $(WRAPPERS) $(SHUTDOWN) wipmi_power




env:
	perl -E"say "$_	= $ENV{$_} for sort keys %ENV;" > /tmp/env

$(WRAPPERS): wrapper
	cp $@ $(BINDIR)
	chown root:root $(BINDIR)/$@; 
	chmod 755  $(BINDIR)/$@;
	chmod u+s  $(BINDIR)/$@;

$(SHUTDOWN): wrapper $(TOOLDIR)
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
	if [[ "$(USER)" == "root" ]] ; then		\
	    cp scanner wipmi_power  $(BINDIR);		\
            chmod 777 /var/log/striker;			\
            chmod 777 /shared/status;			\
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

RPM: distclean $(RPMDIRS) $(RPMBUILD)
	rm -f Scanner.files
	find . -type d                \
		     -name RPMS  -o   \
	             -name cover_db   \
	                  -prune -o   \
		 -type f              \
	             -name '*.rpm'              -o \
	             -name load_rpm_packages.sh -o \
		     -name '*.c'      \
	                  -prune -o   \
	         -print             | \
	perl -n -e 's{\A\.}{};       \
                     print if length' > Scanner.files
	tar --exclude='*.rpm' -czf $(SOURCESDIR)/scanner.tar.gz .
	cp SPECS/scanner.spec $(SPECSDIR)

test:
	prove t/*.t

# ----------------------------------------------------------------------
# End of file

