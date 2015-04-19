
# Makefile for Alteeve's Scanner subsystem

# Pass all lines in a 'recipe' to a single shell instance, rather than
# one shell per line. Make the shell be bash.
#

.ONESHELL:
SHELL := /bin/bash

SQLUSER    = striker
SQLDB      = scanner
SQL00      = SQL/00_drop_db.sql 
SQLFILES   = SQL/01_create_node.sql SQL/02_create_alerts.sql \
	SQL/03_create_alert_listeners.sql SQL/04_load_alert_listeners.sql    \
	SQL/05_create_random_agent.sql SQL/06a_create_snm_apc_pdu.sql 	     \
	SQL/06b_create_snmp_brocade_switch.sql SQL/06_create_snm_apc_ups.sql \
	SQL/07_create_ipmi.sql SQL/08_create_raid.sql SQL/09_create_bonding.sql

.PHONY: SQL $(SQL00) $(SQLFILES)

~/.pgpass: 
	echo "*:*:*:*:postgres\n*:*:*:*:striker" > ~/.pgpass;
	chmod 700 ~/.pgpass

SQL     : $(SQL00) $(SQLFILES) ~/.pgpass
	if [[ -x /usr/bin/postgres ]];				\
	then							\
	    psql -U postgres -d template1 -f $(SQL00);		\
	    for sql in $(SQLFILES); 				\
	    do							\
	        psql -U $(SQLUSER) -d $(SQLDB) -f $$(sql);	\
	    done						\
	else							\
	    echo "postgres not installed on this machine.";	\
	fi
	rm -f ~/.pgpass

# ----------------------------------------------------------------------
# End of file

