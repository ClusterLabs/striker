#!/bin/bash
#
# Micro-script for touching /var/log/striker.log and setting it's ownership to
# apache:apache.

touch /var/log/striker.log
chown apache:apache /var/log/striker.log

