#!/usr/bin/bash

# Purpose: Export networks from Infoblox Grid to csv file. Just for fun... ;)
# 
# Parameters: At least $GRID_IP should be set. $FILTER parameters are optional, see description below
# Required programs: curl, gpg, jq
# 
# Required preparation: 
# - add API user with read permissions at Infoblox Grid
# - create authentication file (creds.txt) in netrc format. See https://everything.curl.dev/usingcurl/netrc for details
# - encrypt this file using 'gpg -o creds.gpg -c creds.txt' and delete the unencrypted file for security reasons

# dj0Nz Feb 2023

# Parameters
CREDS_CRYPT=creds.gpg
CREDS=creds.txt
OUTPUT=netlist.csv
# $COMMENT_FILTER applied to comments field, if not empty
# $NET_FILTER applied to network field, if not empty. SHOULD be a network address, CAN be first octets only, e.g. "10." or "192.168"
COMMENT_FILTER="DE"
NET_FILTER="192.168"
GRID_IP="198.51.100.23"

# IP address and mask bits regexes. Masks are valid from 8 to 30 bits
IPREGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
MASK_REGEX="([8-9]|[1-2][0-9]|30)"

touch $OUTPUT
cat /dev/null > $OUTPUT

# Apply jq filter. See https://stedolan.github.io/jq/manual/#Builtinoperatorsandfunctions for information on jq filters
function json_filter() {
    if [[ "$COMMENT_FILTER" = "" ]]; then
        if [[ "$NET_FILTER" = "" ]]; then
            jq -r '.[] | [.["comment"], .["network"]] | @csv'
        else
            jq --arg NET_FILTER "$NET_FILTER" -r '.[] | select(.network  | . and startswith($NET_FILTER)) | [.["comment"], .["network"]] | @csv'
        fi
    else
        if [[ "$NET_FILTER" = "" ]]; then
            jq --arg COMMENT_FILTER "$COMMENT_FILTER" -r '.[] | select(.comment  | . and contains($COMMENT_FILTER)) | [.["comment"], .["network"]] | @csv'
        else
            jq --arg COMMENT_FILTER "$COMMENT_FILTER" --arg NET_FILTER "$NET_FILTER" -r '.[] | select(.comment  | . and contains($COMMENT_FILTER)) | select(.network  | . and startswith($NET_FILTER)) | [.["comment"], .["network"]] | @csv'
        fi
    fi
}

echo ""
echo "Welcome to API playground. Soup of the day: Infoblox Grid WAPI export"
echo "---------------------------------------------------------------------"
echo ""

# Decrypt credentials, don't cache the passphrase, don't use ncurses crap
echo "Decrypting credentials..."
gpg -o $CREDS --pinentry-mode=loopback --no-symkey-cache -qd $CREDS_CRYPT

# The main thing. First, get all network containers, then, iterate through them and list networks with comments in csv format
echo "Gathering data..."
GRID_CONTAINERS=`curl -k --silent --netrc-file $CREDS https://$GRID_IP/wapi/v2.10/networkcontainer | jq -r '.[]|.network'`
for CONTAINER in $GRID_CONTAINERS; do
    curl -k --silent --netrc-file $CREDS https://$GRID_IP/wapi/v2.10/network?network_container=$CONTAINER | json_filter | tr -d '"' >> $OUTPUT
done
rm $CREDS

# Syntax checking and output
NUM=`cat $OUTPUT | wc -l`
if [[ ! $NUM -lt 1 ]]; then
    while read line; do
        CHECK=`echo $line | grep -E ".*,$IPREGEX\/$MASK_REGEX"`
        if [[ "$CHECK" = "" ]]; then
            printf "%-15s %s\n" "Syntax check failed:" "$line"
            continue
        fi
        COMMA=`echo $line | tr -d -c ',' | wc -m`
        if [[ ! "$COMMA" = "1" ]]; then
            printf "%-15s %s\n" "More than one comma:" "$line"
            continue
        fi
        COMMENT=`echo $line | cut -d ',' -f 1`
        if [[ "$COMMENT" = "" ]]; then
            printf "%-15s %s\n" "Missing description:" "$line"
            continue
        fi
        printf "%s\n" "$line"
    done < $OUTPUT
    echo ""
    echo "CSV export stored at $OUTPUT"
else
    echo "Empty output file!"
    exit 1
fi
