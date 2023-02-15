#!/usr/bin/bash

# Purpose: Export networks from Infoblox Grid to csv file. Just for fun... ;)
# Parameters: At least $GRID_IP should be set. $PATTERN is optional
# Required programs: curl, gpg, jq
# Required preparation: Encrypted Grid credentials (gpg -c) in .netrc format

# dj0Nz Feb 2023

CREDS_CRYPT=creds.gpg
CREDS=creds.txt
OUTPUT=netlist.csv
PATTERN="RU"
GRID_IP="198.51.100.23"

# IP address and mask bits regexes. Masks are valid from 8 to 30 bits
IPREGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
MASK_REGEX="([8-9]|[1-2][0-9]|30)"

touch $OUTPUT
cat /dev/null > $OUTPUT

# Apply filter if $PATTERN is not empty
# You may filter networks with a piped "select(.network |. and startswith("192.168"))|.network"
function json_filter() {
    if [[ "$1" = "" ]]; then
        jq -r '.[] | [.["comment"], .["network"]] | @csv'
    else
        jq --arg PATTERN "$1" -r '.[] | select(.comment  | . and startswith($PATTERN)) | [.["comment"], .["network"]] | @csv'
    fi
}

echo "Testing Infoblox Grid WAPI export"
echo ""

# Decrypt credentials, don't cache the passphrase, don't use ncurses crap
echo "Decrypting credentials"
gpg -o $CREDS --pinentry-mode=loopback --no-symkey-cache -qd $CREDS_CRYPT

# The main thing. First, get all network containers, then, iterate through them and list networks with comments in csv format
echo "Gathering data..."
GRID_CONTAINERS=`curl -k --silent --netrc-file $CREDS https://$GRID_IP/wapi/v2.10/networkcontainer | jq -r '.[]|.network'`
for CONTAINER in $GRID_CONTAINERS; do
    curl -k --silent --netrc-file $CREDS https://$GRID_IP/wapi/v2.10/network?network_container=$CONTAINER | json_filter "$PATTERN" | tr -d '"' >> $OUTPUT
done
rm $CREDS

# Syntax checking and output
NUM=`cat $OUTPUT | wc -l`
if [[ ! $NUM -lt 1 ]]; then
    while read line; do
        CHECK=`echo $line | grep -E ".*,$IPREGEX\/$MASK_REGEX"`
        if [[ "$CHECK" = "" ]]; then
            echo "Syntax check failed: $line"
            continue
        fi
        COMMA=`echo $line | tr -d -c ',' | wc -m`
        if [[ ! "$COMMA" = "1" ]]; then
            echo "More than one comma: $line"
            continue
        fi
        COMMENT=`echo $line | cut -d ',' -f 1`
        if [[ "$COMMENT" = "" ]]; then
            echo "Missing description: $line"
            continue
        fi
        echo $line
    done < $OUTPUT
    echo ""
    echo "CSV export stored at $OUTPUT"
else
    echo "Empty output file!"
    exit 1
fi
