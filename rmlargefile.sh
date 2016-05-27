#!/bin/bash

###Changeable variables
WORKPATH=/home
SERVERNAME=$1
LOGFILENAME=~/removedfiles.log

###Variable logic
LARGESTSIZE=`ssh $SERVERNAME "find $WORKPATH -type f -exec du -ka {} + " | sort -n | tail -1 | awk '{print $1}' | awk -F\\\ '{print $1}'`
LARGESTNAME=`ssh $SERVERNAME "find $WORKPATH -type f -exec du -ka {} + " | sort -n | tail -1 | awk '{print $2}' | awk -F\\\ '{print $1}'`
VARLOGSIZE=`ssh $SERVERNAME "df -k $WORKPATH" | tail -1 | awk '{print $2}' | awk -F\\\ '{print $1}'`
VARLOGFS=`ssh $SERVERNAME "df -k $WORKPATH" | tail -1 | awk '{print $6}' | awk -F\\\ '{print $1}'`
PERCENTUSED=$((100*$LARGESTSIZE/$VARLOGSIZE))
 
### Informational output
echo "$LARGESTNAME  is $LARGESTSIZE k"
#echo "$WORKPATH is $VARLOGSIZE k on $VARLOGFS"
echo "$LARGESTNAME is taking up $PERCENTUSED % of $VARLOGFS"

### Is file large enough? Do we still want to delete it?
if [ "$PERCENTUSED" -lt "50" ]; then
echo "No single file is not using more than 50% of the filesystem."
echo "$LARGESTNAME is the largest, using $PERCENTUSED of $VARLOGFS."
read -p "Remove $LARGESTNAME? (y/n}: " YN
if [ "$YN" == "y" ]; then
ssh -t $SERVERNAME rm -Iv $LARGESTNAME
echo "Other large files may remain, investigate."
echo "$USER removed $LARGESTNAME on $(date). Other large files may remain." >> $LOGFILENAME
exit 0
elif [ "$YN" == "n" ]; then
echo "Nothing removed."
exit 1
fi
fi

### Verification Prompt
read -p "Remove $LARGESTNAME? (y/n}" YN
if [ "$YN" == "y" ]; then
ssh -t $SERVERNAME rm -Iv $LARGESTNAME
echo "$USER removed $LARGESTNAME on $(date)." >> $LOGFILENAME
exit 0
elif [ "$YN" == "n" ]; then
echo "Nothing removed."
exit 1
fi

### Log removal
echo "$USER removed $LARGESTNAME on $(date)." >> $LOGFILENAME
