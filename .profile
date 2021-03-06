# Sample .profile for SuSE Linux
# rewritten by Christian Steinruecken <cstein@suse.de>
#
# This file is read each time a login shell is started.
# All other interactive shells will only read .bashrc; this is particularly
# important for language settings, see below.

test -z "$PROFILEREAD" && . /etc/profile || true

# Most applications support several languages for their output.
# To make use of this feature, simply uncomment one of the lines below or
# add your own one (see /usr/share/locale/locale.alias for more codes)
# This overwrites the system default set in /etc/sysconfig/language
# in the variable RC_LANG.
#
#export LANG=de_DE.UTF-8	# uncomment this line for German output
#export LANG=fr_FR.UTF-8	# uncomment this line for French output
#export LANG=es_ES.UTF-8	# uncomment this line for Spanish output


# Some people don't like fortune. If you uncomment the following lines,
# you will have a fortune each time you log in ;-)

if [ -x /usr/bin/fortune ] ; then
    echo
    /usr/bin/fortune
    echo
fi

if [ -x ~/logs/ ] ; then
	if test -t 0 ; then
		date=$(date +"%m_%d_%Y")
		time=$(date +"%Y/%m/%d-%T %Z epoc: %s")
		echo -e "\n\n======>> Session started at $time <<======\n\n" >> ~/logs/output.$date.log
		script -f -a ~/logs/output.$date.log
		echo ""
		exit
	fi
fi
