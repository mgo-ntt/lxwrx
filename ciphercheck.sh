#!/bin/bash
  
# SSL/TLS cipher check
# Loops through all ciphers available locally to identify weak encryption
# dj0Nz jun 2023

# Syntax check
if [[ $1 ]]; then
    HOST=$1
else
    echo "Syntax: $(basename $0) [Hostname|IP address]"
    exit 1
fi

# Connectivity check
OPEN=`timeout 3 bash -c "</dev/tcp/$HOST/443" 2>/dev/null && echo "Open" || echo "Closed"`
if [[ ! "$OPEN" = "Open" ]]; then
    echo "Host $HOST unreachable"
    exit 1
fi

# Check if host supports TLSv1.3
TLS13=`echo Q | timeout 2 openssl s_client -connect $HOST:443 -tls1_3 2>/dev/null | grep New | grep 1.3`

# Get a list of all locally available ciphers ($1) with protocol ($2)
CIPHERS=`openssl ciphers -v | awk '{print $1 ":" $2}'`

echo "Checking SSL ciphers on host $HOST"
echo ""

for INDEX in $CIPHERS; do
    # Extract cipher and protocol from current cipher/protocol string
    CIDX=`echo $INDEX | awk -F ":" '{print $1}'`
    PIDX=`echo $INDEX | awk -F ":" '{print $2}'`
    # Different commands needed for TLS 1.3 and lower protocols
    if [[ "$PIDX" == "TLSv1.3" ]]; then
        if [[ $TLS13 ]]; then
            # Command returns a line containing protocol and cipher. Uppercase "Q" terminates the request.
            LINE=`echo Q | timeout 2 openssl s_client -connect $HOST:443 -ciphersuites $CIDX 2>/dev/null | grep ^New`
        fi
    else
        # The no_tls1_3 switch is needed to prevent fallback to "better" ciphers
        LINE=`echo Q | timeout 2 openssl s_client -connect $HOST:443 -no_tls1_3 -cipher $CIDX 2>/dev/null | grep ^New`
    fi
    # Prettify output (or ease further processing)
    if [[ ! "$LINE" =~ "NONE" ]]; then
        AR_LINE=(${LINE// / })
        PROTO=`echo ${AR_LINE[1]} | sed 's/,//'`
        CIPHER=${AR_LINE[4]}
        if [[ $CIPHER ]]; then
            printf "%-8s %s\n" "$PROTO" "$CIPHER"
        fi
    fi
done
echo ""