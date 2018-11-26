#!/bin/sh
#
# Ausstehende Upgrades auf Debian Systemen checken
# Ausgabe: Hostname, Anzahl der ausstehenden Updates
#
# Michael Goessmann Matos, NTT Security
# November 2019
 
# Liste der zu prüfenden Debian-Systeme
HOSTS="host1 \
       host2 \
       host3 \
       host4 \
       host5 \
       host6“
 
# Neues Logfile bei jedem Start, alle Ausgaben dahin umleiten
LOG="/var/log/deb-upgrade-check.log"
exec > $LOG 2>&1
if [ -f $LOG ]; then
   cat /dev/null > $LOG
else
   touch $LOG
fi
 
# Eigentliche Arbeit und Ausgabe
echo ""
echo "Ausstehende Debian Upgrades `date`"
echo "--------------------------------------------------------"
echo ""
echo "System \t\tAnzahl"
echo "----------------------"
for HOST in $HOSTS; do
   ssh root@$HOST "apt-get update -qq"
   NUM=`ssh root@$HOST "apt list --upgradable -qq" 2> /dev/null | wc -l`
   printf "%-15s %s\n" "$HOST:" "$NUM"
done
echo ""
