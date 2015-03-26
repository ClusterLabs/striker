#!/bin/sh

# 19-Dec-2014: Subu - Disables boot by changing the securitykey and requiring a passphrase

# Need to run as root
if [[ $EUID -ne 0 ]]; then
   echo "$0 must be run as root" 1>&2
   exit 1
fi

# Need the old and the new keys as well as a passphrase
if [ "$#" -ne 3 ]; then
   echo "Usage: $0 <old_key> <new_key> <passphrase>"
   exit 1
fi

STORCLI="/opt/MegaRAID/storcli/storcli64"

if [ ! -x ${STORCLI} ]; then
   echo "${STORCLI} not found."
   exit 2
fi

OLDKEY=$1
NEWKEY=$2
PASS=$3

${STORCLI} /c0 set securitykey=${NEWKEY} oldsecuritykey=${OLDKEY} passphrase=${PASS} && (echo o > /proc/sysrq-trigger)

# Not reached if successful
exit 3


