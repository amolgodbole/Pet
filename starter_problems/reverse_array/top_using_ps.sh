#!/bin/bash
PID=$(prgrep -d "," PROCESS-NAME)
OUTPUT_FILE="top-output.txt"
DURATION=900
INTERVAL=0.01

# Clear the output file and add header
echo "Timestamp,PID,Command,CPU%,Memory%" > "$OUTPUT_FILE"

END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Use ps to get process information
    ps -p $PID -o pid,comm,%cpu,%mem --no-headers | while read pid comm cpu mem; do
        echo "$TIMESTAMP,$pid,$comm,$cpu,$mem" >> "$OUTPUT_FILE"
    done
    
    sleep $INTERVAL
done
