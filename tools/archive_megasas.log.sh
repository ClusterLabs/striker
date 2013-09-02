#!/bin/bash
#
# Run daily to keep 5 days worth of records.
# crontab: 0 1 * * *  /root/archive_megasas.log.sh > /dev/null

# Delete the oldest archive
if [ -e "/root/MegaSAS.log.5.bz2" ]
then
	rm -f /root/MegaSAS.log.5.bz2
fi

# Move 4 to 5
if [ -e "/root/MegaSAS.log.4.bz2" ]
then
	mv /root/MegaSAS.log.4.bz2 /root/MegaSAS.log.5.bz2
fi

# Move 3 to 4
if [ -e "/root/MegaSAS.log.3.bz2" ]
then
	mv /root/MegaSAS.log.3.bz2 /root/MegaSAS.log.4.bz2
fi

# Move 2 to 3
if [ -e "/root/MegaSAS.log.2.bz2" ]
then
	mv /root/MegaSAS.log.2.bz2 /root/MegaSAS.log.3.bz2
fi

# Move 1 to 2
if [ -e "/root/MegaSAS.log.1.bz2" ]
then
	mv /root/MegaSAS.log.1.bz2 /root/MegaSAS.log.2.bz2
fi

# Move current to 1 and compress it
if [ -e "/root/MegaSAS.log" ]
then
	mv /root/MegaSAS.log /root/MegaSAS.log.1
	bzip2 /root/MegaSAS.log.1
fi
