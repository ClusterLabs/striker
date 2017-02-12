#!/bin/bash
#
# This is a little script used to rebuild the repodata on a Striker dashboard's
# local repository. It had to be written in bash as it is invoked by the 
# Striker kickstart scripts.
# 
# Exit codes:
# Exit codes:
# 0 = Success
# 1 = Failed to find the source directory or it doesn't exist.
# 2 = Failed to find the disc ID
# 3 = Failed to indentify XML file 1

echo "-=] Preparing to build our repo"
XML_FILE1="";
XML_FILE2="";
OS_DIR="rhel6";
if $(grep -q -i CentOS /etc/redhat-release)
then
    OS_DIR="centos6";
fi
echo "OS directory is: [$OS_DIR]"
SOURCE="/var/www/html/${OS_DIR}/x86_64/img";
if [ ! -e "$SOURCE" ]
then
    echo "Source directory: [$SOURCE] not found."
    exit 1
fi
REPO_DIR="${SOURCE}/repodata";
DISC_ID_FILE="${SOURCE}/.discinfo";

# This isn't needed, per-se, but it cleans things up. TRANS.TBL is CD thing.
echo -n "Removing all TRANS.TBL files..."
for file in $(find ${SOURCE} | grep TRANS.TBL)
do
    rm -f $file
done
echo " Done."

echo -n "Finding the disc ID...";
DISC_ID=$(cat ${DISC_ID_FILE} | grep -P '^\d\d+')
if [ -z "$DISC_ID" ];
then
    echo
    echo "[ Error ] - Failed to read disc ID from: [${DISC_ID_FILE}]";
    echo "[ Error ]   Unable to proceed.";
    exit 2;
else
    echo " [${DISC_ID}]"
fi;

# Find our files
echo "Finding XML file(s) and purging stale repo files..."
for file in $(ls ${REPO_DIR})
do
    #echo $file
    if $(echo $file | grep -q 'Server\.x86_64\.xml$')
    then
        XML_FILE2="${REPO_DIR}/$file";
    elif $(echo $file | grep -q 'c6-x86_64-comps\.xml$')
    then
        XML_FILE2="${REPO_DIR}/$file";
    elif $(echo $file | grep -q -e '\.gz$' -e '\.bz2' -e '\.repomd\.xml')
    then
        #echo "Stale repodata file: [${REPO_DIR}/$file], deleting it."
        rm -f ${REPO_DIR}/$file
    elif $(echo $file | grep -q 'comps\.xml$')
    then
        XML_FILE1="${REPO_DIR}/$file";
    elif $(echo $file | grep -q 'repomd\.xml$')
    then
        XML_FILE1="${REPO_DIR}/$file";
    else
        echo "Ignoring unknown file: [$file]";
    fi
done

echo "- XML File 1: [${XML_FILE1}]";
echo "- XML File 2: [${XML_FILE2}]";

if [ -z "$XML_FILE1" ];
then 
    echo "[ Error ] - Failed to find XML file 1, which is required.";
    echo "[ Error ]   Unable to proceed.";
    exit 3;
fi

echo "Building the repo now."
if [ -z "$XML_FILE2" ]
then
    /usr/bin/createrepo -u media://$DISC_ID -g $XML_FILE1 -g $XML_FILE2 $SOURCE/
else
    /usr/bin/createrepo -u media://$DISC_ID -g $XML_FILE1 $SOURCE/
fi
