#!/bin/bash

# purpose:
# quick and dirty solution to start/stop an iperf3 server on default port 5201/tcp
# adjust permissions and create symlink in /usr/local/bin to run it from everywhere
# dont forget to add firewall rules allowing 5201 in the input chain
#
# requirements:
# linux, iperf3, lsof, bash
#
# dj0Nz Feb 2022

IPERFBIN=/usr/bin/iperf3
LOGFILE=/var/log/iperf.log
PIDFILE=/var/run/iperf.pid
PORT=`lsof -Pni | grep iperf | awk '{print $9}' | tr -d '*:'`
ME=`basename "$0"`

case $1 in
   start)
      $IPERFBIN --logfile $LOGFILE --timestamps -s -D -I $PIDFILE
      ;;
   stop)
      kill $(tr -d '\0' < $PIDFILE)
      ;;
   status)
      if [[ $PORT = "" ]]; then
         echo "iperf server not running"
      else
         echo "iperf server listening on port $PORT"
      fi
      ;;
   *)
      echo "Usage: $ME start|stop|status"
      ;;
esac
