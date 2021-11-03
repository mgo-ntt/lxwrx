#!/bin/bash

# check debian upgrades
# djonz 2019

HOSTS="host1 \
       host2 \
       host3 \
       host4 \
       host5"

SCRIPT='cat /etc/os-release | grep PRETTY | cut -d= -f2 | tr -d \"'

echo ""
echo "Ausstehende Debian Upgrades `date`"
echo "--------------------------------------------------------"
echo ""
printf "%-15s %-35s %s\n" "Hostname" "Debian Version" "Anzahl ausstehender Updates"
echo "-------------------------------------------------------------------------------"
VER=`cat /etc/os-release | grep PRETTY | cut -d= -f2 | tr -d \"`
NUM=`apt list --upgradable -qq 2> /dev/null | wc -l`
printf "%-15s %-35s %s\n" "mon:" "$VER" "$NUM"

for HOST in $HOSTS; do
   CONNTEST=`/usr/bin/nc -z -w3 $HOST 22 && echo Open`
   if [ "$CONNTEST" = "Open" ]; then
      ssh -q -o PasswordAuthentication=no -o StrictHostKeyChecking=accept-new root@$HOST exit
      if [ "$?" = "0" ]; then
         ssh -q root@$HOST "apt-get update -qq" 2> /dev/null
         VER=`ssh root@$HOST ${SCRIPT}`
         NUM=`ssh root@$HOST "apt list --upgradable -qq" 2> /dev/null | wc -l`
         printf "%-15s %-35s %s\n" "$HOST:" "$VER" "$NUM"
      else
         printf "%-15s %s\n" "$HOST:" "Public Key Auth nicht konfiguriert."
      fi
   else
         printf "%-15s %s\n" "$HOST:" "Keine Antwort"
   fi
done
echo ""
