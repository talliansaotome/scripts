#!/bin/bash

###Changeable variables
WORKPATH=/home
SERVERNAME=$1
LOGFILENAME=~/removedfiles.log

###Variable logic
LARGESTSIZE=`find $WORKPATH -type f -exec du -ka {} + | sort -n | tail -1 | awk '{print $1}'`
LARGESTNAME=`find $WORKPATH -type f -exec du -ka {} + | sort -n | tail -1 | awk '{print $2}'`
VARLOGSIZE=`df -k $WORKPATH | tail -1 | awk '{print $2}'`
VARLOGFS=`df -k $WORKPATH | tail -1 | awk '{print $6}'`
PERCENTUSED=$((100*$LARGESTSIZE/$VARLOGSIZE))
 
### Informational output
echo "$LARGESTNAME  is $LARGESTSIZE k"
echo "$WORKPATH is $VARLOGSIZE k on $VARLOGFS"
echo "$LARGESTNAME is taking up $PERCENTUSED % of $VARLOGFS"

### Verification Prompt
read -p 'Press Ctrl-C to cancel or Enter to continue'

### Remove large file
rm -Iv $LARGESTNAME

### Log removal
echo "$USERNAME removed $LARGESTNAME on $(date)." > $LOGFILENAME
