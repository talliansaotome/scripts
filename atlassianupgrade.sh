#!/bin/bash
###COMBINED UPGRADE


###Put ourselves in a screen session
if [[ $STY = "" ]]; then
	echo "Running ourself in a screen session."
	screen -S $(basename $0) -L "$0"
	mv screenlog.? $(basename $0).log
	exit
fi

##Collect info we will need

# What are we working with?
echo "Detecting which app we are using..."
if [[ -f data/confluence.cfg.xml ]] ; then
	APP=confluence
	CONFIGFILE=data/confluence.cfg.xml
	APPLOG=data/logs/atlassian-confluence.log
	echo "We are working with Confluence."
	FILEOWNER=$(stat -c '%U' data/confluence.cfg.xml)
	echo "Files are owned by $FILEOWNER"
	SHAREDOPTS=--exclude={attachments,bundled-*,plugins-*,logs,temp,backups,clear-cache,cacheclear,import,export,backup,recovery,webresource-temp}
elif [[ -f data/dbconfig.xml ]] ; then
	APP=jira
	CONFIGFILE=data/dbconfig.xml
	APPLOG=data/log/atlassian-jira.log
	echo "We are working with Jira."
	FILEOWNER=$(stat -c '%U' data/dbconfig.xml)
	echo "Files are owned by $FILEOWNER"
	SHAREDOPTS=--exclude={data/attachments,analytics-logs,backup,caches,*.bak,tmp,temp,export,import,log,logs,plugins/.??*,CACHECLEAR*,cache-clear*,cacheclear*}
else
	echo "No app install detected."
	exit 1
fi

# Get database info needed
DATABASECONNECTION=$(awk -F '[<>]' '/url/{print $3}' $CONFIGFILE)
DATABASE=$(awk -F/ '{print $4}' <<< "$DATABASECONNECTION")
echo "Using $DATABASE"
echo ""

## Parse the service name, prompt if this fails
echo "Finding active service name..."
if [[ $(systemctl|grep -c j2ee) -eq 1 ]] ; then
	SERVICENAME=$(systemctl -al|grep j2ee|awk '{print $1}')
	echo "Using $SERVICENAME as the active service."
else
	echo "Unable to automatically determine service, what should we be using?"
	echo ""
	systemctl |grep j2ee
	echo ""
	read -p "Service name?" SERVICENAME
	echo ""
fi

# Get other info we will need.
read -p "Ticket Number? " TICKET
read -p "Target Version? " VERSION
echo ""



## Whats the job
echo "1) Prep"
echo "2) Run the Sched"
echo "3) ROLLBACK"
echo "X) Exit. or any key really."
echo ""
read -n 1 -p 'Well? ' CHOICE
echo ""


if [ "$CHOICE" = "1" ] ; then
###PREP

## Check for enough space to do the work
echo "Checking for enough disk space for the upgrade..."
DATADIRSIZE=$(du -sk data/ "$SHAREDOPTS"|awk {'print $1'})
FREESPACE=$(df -k . --output=avail|tail -1)

if [[ $FREESPACE -lt $(( 2 * $DATADIRSIZE )) ]] ; then
	echo "Not enough free space, aborting."
	exit 1
else
	echo "Enough space found, proceeding."
fi

##Set up the files

# Clone the data, no attachments
echo "Copying data dir"
time rsync -aHS "$SHAREDOPTS" data/ data-"$VERSION"/ || exit 1
ln -s data-"$VERSION" next.data || echo "Linking the next data/ dir failed."

# Get the application
echo "Fetching and installing the app"
wget https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-"$VERSION".tar.gz || exit 1
tar xzf atlassian-confluence-"$VERSION".tar.gz || exit 1
ln -s atlassian-confluence-"$VERSION" next || echo "Linking the next current/ dir failed"

## The fancy diffs
echo "Checking for changes to config files..."
if [[ $APP = confluence ]] ; then
	for FILEPAIR in "data/confluence.cfg.xml next.data/confluence.cfg.xml" "current/bin/setenv.sh next/bin/setenv.sh" "current/conf/server.xml next/conf/server.xml" "current/conf/web.xml next/conf/web.xml" "current/confluence/WEB-INF/classes/confluence-init.properties next/confluence/WEB-INF/classes/confluence-init.properties" "current/confluence/WEB-INF/classes/seraph-config.xml next/confluence/WEB-INF/classes/seraph-config.xml" "current/confluence/WEB-INF/classes/crowd.properties next/confluence/WEB-INF/classes/crowd.properties" "current/confluence/WEB-INF/classes/okta-config-confluence.xml next/confluence/WEB-INF/classes/okta-config-confluence.xml"
		do 
			echo "Checking $FILEPAIR"
				if [[ "$(sdiff -BWsi "$FILEPAIR")" != "" ]]; then
					sdiff -BWsi "$FILEPAIR"
					echo ""
					echo "^^^^^^^^^^"
					echo ""
					echo "What to do?"
					echo "1\) Copy over"
					echo "2\) Run vimdiff"
					echo ""
					read -n 1 -p 'Well? ' CHOICE
					echo ""
				if [ "$CHOICE" = "1" ] ; then
					cp -vi "$FILEPAIR"
				elif [ "$CHOICE" = "2" ] ; then
					vimdiff "$FILEPAIR"
				else
					echo "Invalid input, breaking, please do diffs manually"
					break
				fi  

		else
			echo "Files match"
		fi
	done
elif [[ $APP = jira ]] ; then
	for FILEPAIR in "current/bin/setenv.sh next/bin/setenv.sh" "current/conf/server.xml next/conf/server.xml" "current/atlassian-jira/WEB-INF/classes/seraph-config.xml next/atlassian-jira/WEB-INF/classes/seraph-config.xml" "current/atlassian-jira/WEB-INF/classes/jira-application.properties next/atlassian-jira/WEB-INF/classes/jira-application.properties" "current/atlassian-jira/WEB-INF/urlrewrite.xml next/atlassian-jira/WEB-INF/urlrewrite.xml" "current/atlassian-jira/WEB-INF/classes/crowd.properties next/atlassian-jira/WEB-INF/classes/crowd.properties"
		do 
			echo "Checking $FILEPAIR"
				if [[ $(sdiff -BWsi "$FILEPAIR") != "" ]]; then
					sdiff -BWsi "$FILEPAIR"
					echo ""
					echo "^^^^^^^^^^"
					echo ""
					echo "What to do?"
					echo "1\) Copy over"
					echo "2\) Run vimdiff"
					echo ""
					read -n 1 -p 'Well? ' CHOICE
					echo ""
				if [ "$CHOICE" = "1" ] ; then
					cp -vi "$FILEPAIR"
				elif [ "$CHOICE" = "2" ] ; then
					vimdiff "$FILEPAIR"
				else
					echo "Invalid input, breaking, please do diffs manually"
					break
				fi  

			else
				echo "Files match"
			fi
	done
fi

## Fix Permissions
echo "Setting permissions..."
chown -R root:root next/ && chown -R "$FILEOWNER". next/{conf,logs,temp,webapps,work} && chown -R "$FILEOWNER". next.data/ || exit 1
echo "Permissions set"

## This part of the guide never found anything in my experience, putting in anyway
if [[ $APP = confluence ]] ; then
	echo "Copying okta"
	cp -vn current/confluence/WEB-INF/lib/okta-confluence-*.jar next/confluence/WEB-INF/lib/
elif [[ $APP = jira ]] ; then
	echo "Checking for okta. Deal with it if you find anything."
	find current/ | grep okta
	echo ""
	echo ""
	echo "Make sure the atlassian recommended settings are in..."
	grep -xF 'upgrade.reindex.allowed=false' data/jira-config.properties || echo 'upgrade.reindex.allowed=false' >> data/jira-config.properties
	grep -xF 'jira.autoexport=false' data/jira-config.properties || echo 'jira.autoexport=false' >> data/jira-config.properties
fi

echo "Prep completed!"
exit

elif [ "$CHOICE" = "2" ] ; then

### SCHED

echo "Stopping the service..."
systemctl stop "$SERVICENAME"

##Move files
echo "Moving the files..."
time rsync -aHS "$SHAREDOPTS" --delete data/ next.data/ || exit 1
mv -v data/attachments next.data/ || exit 1
mv -v current prev && mv -v next current || exit 1
mv -v data prev.data && mv -v next.data data || exit 1

echo "Dumping backup copy of the database..."
if [[ "$DATABASECONNECTION" == *"localhost"* ]]; then
	## Database Dump
	su - postgres -c "mkdir -p /var/lib/pgsql/backups/other/" && time su - postgres -c "pg_dump -O $DATABASE | gzip > /var/lib/pgsql/backups/other/$DATABASE-PRE-$TICKET.dmp.gz"
	echo "checking to be sure backup was created"
	ls -al /var/lib/pgsql/backups/other/"$DATABASE"-PRE-"$TICKET".dmp.gz

else
	echo "Database is not local, check at $DATABASECONNECTION"
	echo "Please run the following there"
	echo "su - postgres -c \"pg_dump -O $DATABASE | gzip > /var/lib/pgsql/backups/other/$DATABASE-PRE-$TICKET.dmp.gz\""
	read -p "Press any key to resume ..."
fi

## Start and watch
systemctl start "$SERVICENAME" && tail -F $APPLOG
exit

elif [ "$CHOICE" = "3" ] ; then

###  ROLLBACK

systemctl stop "$SERVICENAME"

## Reimport database

# Collect database creds
DATABASEUSERNAME=$(awk -F '[<>]' '/username/{print $3}' $CONFIGFILE)
DATABASEPASSWORD=$(awk -F '[<>]' '/password/{print $3}' $CONFIGFILE)

## check if database is local
if [[ "$DATABASECONNECTION" == *"localhost"* ]]; then
	## Restore database
	echo "Re-creating and restoring database..."
	su - postgres -p -c "dropdb $DATABASE" || exit 1
	su - postgres -p -c "createdb -E UNICODE -O $DATABASEUSERNAME $DATABASE" || exit 1

	export PGPASSWORD=$DATABASEPASSWORD
	time su - postgres -p -c "zcat /var/lib/pgsql/backups/other/$DATABASE-PRE-$TICKET.dmp.gz | psql -U $DATABASEUSERNAME $DATABASE" || exit 1
else
	echo "Database is not local, check at $DATABASECONNECTION"
	echo "Please restore database there, will continue after a pause"
	read -p "Press any key to resume ..."
fi

## Restore files
mv data/attachments prev.data/ || exit 1
mv current failed-"$TICKET" && mv data failed.data-"$TICKET" || exit 1
mv prev current && mv prev.data data || exit 1


## Start and watch
systemctl start "$SERVICENAME" && tail -F $APPLOG

exit
else
	echo "Please make a valid choice next time!"
	exit 1
fi