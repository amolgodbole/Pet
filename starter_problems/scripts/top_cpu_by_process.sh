#!/bin/bash


# ./top_cpu_by_process.sh process_name my_cpu_log.csv




# Check if process name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <process_name> [log_file]"
    echo "Example: $0 firefox cpu_monitor.log"
    exit 1
fi

PROCESS_NAME="$1"
LOG_FILE="${2:-cpu_monitor_${PROCESS_NAME}_$(date +%Y%m%d_%H%M%S).log}"
DURATION=900
INTERVAL=0.1
MAX_CPU=0.0
SAMPLE_COUNT=0
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

# Initialize log file
echo "Timestamp,CPU_Usage,Process_Name" > "$LOG_FILE"
echo "CPU monitoring log for $PROCESS_NAME started at $(date)" >> "$LOG_FILE"

echo "Monitoring CPU usage for process: $PROCESS_NAME"
echo "Logging to: $LOG_FILE"
echo "Duration: $DURATION seconds"
echo "Sampling interval: ${INTERVAL}s (100ms)"
echo "Started at: $(date)"
echo "----------------------------------------"

# Function to compare floating point numbers
compare_float() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1>n2) print "1"; else print "0"}'
}

while [ $(date +%s) -lt $END_TIME ]; do
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Get CPU usage for the process
    CPU_USAGE=$(top -b -n 1 -d 0 | grep "$PROCESS_NAME" | head -1 | awk '{print $9}')
    
    if [ -n "$CPU_USAGE" ] && [ "$CPU_USAGE" != "0.0" ]; then
        SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
        
        # Log the data point
        echo "$CURRENT_TIME,$CPU_USAGE,$PROCESS_NAME" >> "$LOG_FILE"
        
        # Check if current CPU usage is higher than max
        if [ $(compare_float "$CPU_USAGE" "$MAX_CPU") -eq 1 ]; then
            MAX_CPU="$CPU_USAGE"
            MAX_CPU_TIME="$CURRENT_TIME"
        fi
        
        # Print progress every 50 samples
        if [ $((SAMPLE_COUNT % 50)) -eq 0 ]; then
            ELAPSED=$(($(date +%s) - START_TIME))
            REMAINING=$((DURATION - ELAPSED))
            echo "Elapsed: ${ELAPSED}s | Remaining: ${REMAINING}s | Current: ${CPU_USAGE}% | Max: ${MAX_CPU}%"
        fi
    else
        # Process not found or CPU usage is 0
        if [ $((SAMPLE_COUNT % 100)) -eq 0 ]; then
            echo "Process '$PROCESS_NAME' not found or not using CPU..."
        fi
    fi
    
    sleep $INTERVAL
done

# Final results
echo "----------------------------------------"
echo "MONITORING COMPLETED"
echo "Process: $PROCESS_NAME"
echo "Total samples collected: $SAMPLE_COUNT"
echo "Maximum CPU usage: ${MAX_CPU}%"
if [ -n "$MAX_CPU_TIME" ]; then
    echo "Peak occurred at: $MAX_CPU_TIME"
fi
echo "Total monitoring duration: $DURATION seconds"
echo "Log file: $LOG_FILE"

# Generate summary statistics if we have data
if [ $SAMPLE_COUNT -gt 0 ]; then
    echo "----------------------------------------"
    echo "SUMMARY STATISTICS"
    
    # Calculate average CPU usage
    AVG_CPU=$(awk -F',' 'NR>2 {sum+=$2; count++} END {if(count>0) printf "%.2f", sum/count}' "$LOG_FILE")
    echo "Average CPU usage: ${AVG_CPU}%"
    
    # Find minimum CPU usage
    MIN_CPU=$(awk -F',' 'NR>2 {if(min=="" || $2<min) min=$2} END {print min}' "$LOG_FILE")
    echo "Minimum CPU usage: ${MIN_CPU}%"
    
    echo "Data points collected: $SAMPLE_COUNT"
    echo "Sampling rate achieved: $(awk "BEGIN {printf \"%.1f\", $SAMPLE_COUNT/($DURATION/0.1)*100}")% of target"
fi