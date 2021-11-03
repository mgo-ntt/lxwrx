#!/bin/bash

# linux system backup script
#
# backup configuration and settings locally
# put files in $DIRECTORY to be collected by backup server
#
# dj0Nz oct 2021

# variables
TMPDIRECTORY=/var/tmp/backup
DIRECTORY=/root/backup
LCNAME=`/bin/hostname -s | tr '[:upper:]' '[:lower:]'`

# make clean directories
if [ -d $TMPDIRECTORY ]; then
   rm -r $TMPDIRECTORY
fi
mkdir $TMPDIRECTORY
if [ -d $DIRECTORY ]; then
   rm $DIRECTORY/* > /dev/null 2>&1
else
   mkdir $DIRECTORY
fi

# version information and manually installed package list
cat /etc/os-release > $TMPDIRECTORY/debian-version.txt
grep -oP "Unpacking \K[^: ]+" /var/log/installer/syslog | sort -u | comm -13 /dev/stdin <(apt-mark showmanual | sort) > $TMPDIRECTORY/debian-pkg-list.txt

# system specific and home directories
tar cPf $TMPDIRECTORY/etc.tar /etc/ > /dev/null 2>&1
tar cPf $TMPDIRECTORY/root.tar /root/ > /dev/null 2>&1
tar cPf $TMPDIRECTORY/home.tar /home/ > /dev/null 2>&1
tar cPf $TMPDIRECTORY/cron.tar /var/spool/cron/ > /dev/null 2>&1

#
# insert application specific here (e.g. /var/www if web server, database dumps)
#

# checksum and copy to output basket
tar cfz $DIRECTORY/$LCNAME.tgz $TMPDIRECTORY/* > /dev/null 2>&1
cd $DIRECTORY
md5sum $LCNAME.tgz > $LCNAME.md5

# end
