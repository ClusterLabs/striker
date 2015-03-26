#!/bin/sh

# 19-Dec-2014: Subu - Reenables passphraseless boot by changing the securitykey and not requiring a passphrase

# Need to run as root
if [[ $EUID -ne 0 ]]; then
   echo "$0 must be run as root" 1>&2
   exit 1
fi

# Need the old and the new keys as well as a passphrase
if [ "$#" -ne 2 ]; then
   echo "Usage: $0 <old_key> <new_key>"
   exit 1
fi

STORCLI="/opt/MegaRAID/storcli/storcli64"

if [ ! -x ${STORCLI} ]; then
   echo "${STORCLI} not found."
   exit 2
fi

OLDKEY=$1
NEWKEY=$2

${STORCLI} /c0 set securitykey=${NEWKEY} oldsecuritykey=${OLDKEY} && exit 0

# The storcli command was not successful
exit 3


