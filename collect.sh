#!/bin/bash

# collect backups from linux hosts, store them in $LOCDIR and keep $RETIME versions of them. 
# This script is intended to run daily, but only keeps one backup per week to prevent disk space issues.
#
# add a backup client as follows:
#
# - make sure target (backup source) is reachable by its hostname
# - login as root on target system and install rsync
# - create ssh keys with ssh-keygen -a 100 -t ed25519
# - edit .ssh/authorized_keys and add backup pubkey (+chmod 600!)
# - make sure firewalls are open
# - test ssh login from backup to target system
# - copy sysbackup.sh script from backup server to target root home and chmod 700
# - schedule backup script to run daily
# - add a local backup directory for target in $LOCDIR. name = target hostname.
#
# thats it. everything else should be handled by this script.
#
# mgo/ntt nov 2021

# setting local and remote directories
LOCDIR=/mnt/backup
REMDIR=/root/backup

# week number will be used in file name, RETIME is number of old backups kept
WEEK=`date +%W`
RETIME=5

# output sent to logfile completely, overwrite every time it runs
LOG=/var/log/collect-backups.log
exec > $LOG 2>&1

# creating list of backup clients
LIST=`ls -l $LOCDIR | awk '{print $9}' | sed '/^$/d'`

echo "Collecting backups from Linux machines"
echo ""

for TARGET in $LIST; do
   # we only need the host part of the fqdn
   RESOLV=`host $TARGET | cut -d. -f1`
   if [[ $TARGET == $RESOLV ]]; then
      # check if ssh port is open on target
      OPEN=`timeout 3 bash -c "</dev/tcp/$TARGET/22" 2>/dev/null &&  echo "Open" || echo "Closed"`
      if [[ "$OPEN" = "Open" ]]; then
         # check if ssh login is possible and add host key if that's the first conenction
         ssh -q -o PasswordAuthentication=no -o StrictHostKeyChecking=accept-new $TARGET exit
         if [ "$?" = "0" ]; then
            # check if remote directory exists
            DIRCHK=`ssh -q $TARGET test -d $REMDIR && echo yes`
            if [[ $DIRCHK == yes ]]; then
               # check if both tgz and md5 are there
               NUM=`ssh -q $TARGET ls $REMDIR/ 2>/dev/null | tr '[:upper:]' '[:lower:]' | egrep 'md5|tgz' | wc -l`
               if [[ $NUM == 2 ]]; then
                  # check if local directory already contains backup of current week
		  if [ -f $LOCDIR/$TARGET/$TARGET-$WEEK.tgz ]; then
                     printf "%-15s %s\n" "$TARGET:" "Directory already contains backup file"
                  else
                     # if not, copy backup file and checksum
		     rsync -aq -e "ssh" $TARGET:$REMDIR/ $LOCDIR/$TARGET/
                     cd $LOCDIR/$TARGET/
                     MD5CHK=`md5sum -c $TARGET.md5 | awk '{print $2}'`
                     if [[ $MD5CHK == OK ]]; then
                        printf "%-15s %s\n" "$TARGET:" "OK. Backup files copied to $LOCDIR/$TARGET"
                        # remove checksum and rename backup file
                        rm $TARGET.md5
                        mv $TARGET.tgz $TARGET-$WEEK.tgz
                        # housekeeping: enumerate files to delete
			NUM=`ls -t $LOCDIR/$TARGET/*.tgz | awk "NR>$RETIME" | wc -l`
			if [[ $NUM = 0 ]]; then
                           printf "%-15s %-35s %s\n" "$TARGET:" "Nothing to clean up."
                        else
                           # cleanup backup files keeping $RETIME revisions
			   printf "%-15s %-35s %s\n" "$TARGET:" "Deleting $NUM backups..."
                           rm `ls -t $LOCDIR/$TARGET/*.tgz | awk "NR>$RETIME"`
                        fi
                     else
                        printf "%-15s %s\n" "$TARGET:" "Checksum failed."
                     fi
                  fi
               else
                  printf "%-15s %s\n" "$TARGET:" "Unexpected number of files. Check backups on target."
               fi
            else
               printf "%-15s %s\n" "$TARGET:" "Remote source directory does not exist."
            fi
         else
            printf "%-15s %s\n" "$TARGET:" "Pubkey auth not configured."
         fi
      else
         printf "%-15s %-35s %s\n" "$TARGET:" "Unreachable. Check firewall rules."
      fi
   else
      printf "%-15s %-35s %s\n" "$TARGET:" "No hostname."
   fi
done
echo ""
