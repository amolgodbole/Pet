#!/bin/bash
#input to the file is process name
PID=$(prgrep -d "," $1)
OUTPUT_FILE="top-output.csv"
# run for 15 mins
DURATION=900
INTERVAL=0.01

# Clear the output file and add header
echo "Timestamp,PID,Command,CPU%,Memory%" > "$OUTPUT_FILE"

# Get the end time
END_TIME=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    # Get current timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Capture process info with CPU and memory usage
    PROCESS_INFO=$(top -b -n1 -p $PID | tail -n1 | awk -v ts="$TIMESTAMP" '{print ts","$1","$12","$9","$10}')
    
    # Only add if process info was captured
    if [[ $PROCESS_INFO != *"$TIMESTAMP,"* ]]; then
        echo "$PROCESS_INFO" >> "$OUTPUT_FILE"
    fi
    
    sleep $INTERVAL
done

# Sort the output by CPU usage (descending), then by memory usage (descending)
(head -n1 "$OUTPUT_FILE" && tail -n+2 "$OUTPUT_FILE" | sort -t',' -k4,4nr -k5,5nr) > temp_file && mv temp_file "$OUTPUT_FILE"
