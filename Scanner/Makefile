
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#

.ONESHELL:
#SHELL := /bin/bash

USER  := ${shell /usr/bin/whoami}

PREFIX = $(if $(RPM_BUILD_ROOT), $(RPM_BUILD_ROOT),)

SYSTEMNAME = striker

TEXTBASE   = $(PREFIX)/etc/$(SYSTEMNAME)
CONFDIR    = $(TEXTBASE)/Config
MSGDIR     = $(TEXTBASE)/Messages

CODEBASE   = $(PREFIX)/usr/share/$(SYSTEMNAME)
BINDIR     = $(CODEBASE)/bin
AGENTDIR   = $(CODEBASE)/agents
LIBDIR     = $(CODEBASE)/lib

LOGDIR     = $(PREFIX)/var/log/$(SYSTEMNAME)
TOOLDIR    = $(PREFIX)/var/www/tools
SHAREDDIR  = $(PREFIX)/shared/status

DIRS       = $(TEXTBASE) $(CONFDIR) $(MSGDIR) $(CODEBASE) $(BINDIR) \
	     $(AGENTDIR) $(LIBDIR) $(LOGDIR) $(SHAREDDIR) $(TOOLDIR) 

SPECSDIR   = $(HOME)/rpmbuild/SPECS 

SOURCESDIR = $(HOME)/rpmbuild/SOURCES

RPMDIRS    = $(HOME)/rpmbuild/BUILD   $(HOME)/rpmbuild/RPMS \
             $(SOURCESDIR) $(SPECSDIR) $(HOME)/rpmbuild/SRPMS

RPMBUILD   = $(HOME)/rpmbuild/BUILD/Scanner

WRAPPERS   = wipmi wstorcli 
SHUTDOWN   = wshutdown

TAR_EXCLUDE = --exclude='*.rpm' --exclude='25-an-screen.t' --exclude='30-an-email.t' --exclude='45-an-listener.t'

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

install: wrapper dirs libs files scanner  $(SHUTDOWN)
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

Scanner.files:
	@echo "If you have to rebuild 'Scanner.files' list"
	@echo "The first do a "make install", so the files"
	@echo "are delivered to /usr/share/strike, etc. Then"
	@echo "run 'make RPM' to generate and deliver the file."
	@echo "Finally, perform 'make uninstall' to remove"
	@echo "the installed files."
	@echo ""
	find /usr/share/striker/* /etc/striker/Messages \
		-type f   -print 	       | \
	egrep '/agents/|/bin/|/lib/|/Config/|/Messages/' > Scanner.files
	echo "/var/www/tools/wshutdown" >> Scanner.files

RPM: distclean $(RPMDIRS) $(RPMBUILD) Scanner.files
	tar $(TAR_EXCLUDE) -czf $(SOURCESDIR)/scanner.tar.gz .
	cp SPECS/scanner.spec $(SPECSDIR)

test:
	prove t/*.t

tags:
	ctags -e --language-force=perl scanner dashboard Agents/* t/*.t lib/AN/*.pm lib/AN/*/*.pm
# ----------------------------------------------------------------------
# End of file

