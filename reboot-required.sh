#!/bin/bash
if [ -f /var/run/reboot-required ]; then
   REASON=`cat /var/run/reboot-required.pkgs`
   echo "1 \"Pending reboot\" - Reboot requested by package $REASON"
else
   echo "0 \"Pending reboot\" - No pending reboot."
fi
