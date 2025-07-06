#!/bin/bash

# Check if running as sudo/root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo privileges for accurate system monitoring."
    echo "Usage: sudo $0 <process_name> [duration] [interval]"
    echo "Example: sudo $0 firefox 900 0.1"
    exit 1
fi

# Validate input parameters
if [ $# -eq 0 ]; then
    echo "ERROR: Process name is required."
    echo "Usage: sudo $0 <process_name> [duration] [interval]"
    echo "Example: sudo $0 firefox 900 0.1"
    exit 1
fi

PROCESS_NAME="$1"
DURATION=${2:-900}  # Default 900 seconds
INTERVAL=${3:-0.1}  # Default 100ms

REPORT_FILE="detailed_cpu_memory_monitor_$(date +%Y%m%d_%H%M%S).log"
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
SAMPLE_COUNT=0
MAX_CPU=0.0
MAX_MEMORY_MB=0.0
MAX_CPU_TIME=""
MAX_MEMORY_TIME=""

# Function to compare floating point numbers
compare_float() {
    awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1>n2) print "1"; else print "0"}'
}

# Create detailed header
cat > $REPORT_FILE << EOF
# CPU and Memory Monitoring Report
# Process: $PROCESS_NAME
# Started: $(date)
# Duration: $DURATION seconds
# Interval: $INTERVAL seconds
# Run by: $(whoami) (UID: $EUID)
# System: $(uname -a)
#
# Columns: EpochNanoseconds,FormattedTime,CPUPercentage,MemoryMB,MemoryKB,VirtualMemoryMB,ProcessPID,ProcessName
EOF

echo "=========================================="
echo "CPU & Memory Monitor (Sudo Mode)"
echo "=========================================="
echo "Process: $PROCESS_NAME"
echo "Duration: $DURATION seconds"
echo "Interval: $INTERVAL seconds"
echo "Started: $(date)"
echo "Log file: $REPORT_FILE"
echo "Running as: $(whoami) (UID: $EUID)"
echo "=========================================="

while [ $(date +%s) -lt $END_TIME ]; do
    # Capture precise timestamp
    EPOCH_NANOS=$(date +%s%N)
    FORMATTED_TIME=$(date +"%Y-%m-%d %H:%M:%S.%N")
    
    # Get detailed process info using top with memory information
    PROCESS_INFO=$(top -b -n 1 | grep "$PROCESS_NAME" | head -1)
    
    if [ -n "$PROCESS_INFO" ]; then
        # Extract process details
        #PID=$(echo "$PROCESS_INFO" | awk '{print $1}')
        PID=$(pgrep -d "," "$PROCESS_NAME")
        CPU_PERCENT=$(echo "$PROCESS_INFO" | awk '{print $9}')
        
        # Get comprehensive memory information using ps[2]
        MEMORY_INFO=$(ps -p $PID -o rss,vsz,pmem 2>/dev/null)
        
        if [ -n "$MEMORY_INFO" ]; then
            # Extract memory values from ps output
            MEMORY_RSS_KB=$(echo "$MEMORY_INFO" | tail -1 | awk '{print $1}')  # Resident Set Size
            MEMORY_VSZ_KB=$(echo "$MEMORY_INFO" | tail -1 | awk '{print $2}')  # Virtual Size
            MEMORY_PERCENT=$(echo "$MEMORY_INFO" | tail -1 | awk '{print $3}') # Memory percentage
            
            # Convert to MB for easier reading
            MEMORY_RSS_MB=$(awk "BEGIN {printf \"%.2f\", $MEMORY_RSS_KB/1024}")
            MEMORY_VSZ_MB=$(awk "BEGIN {printf \"%.2f\", $MEMORY_VSZ_KB/1024}")
        else
            # Fallback: try to get memory from top output
            MEMORY_RSS_KB=$(echo "$PROCESS_INFO" | awk '{print $6}' | sed 's/[^0-9]//g')
            MEMORY_RSS_MB=$(awk "BEGIN {printf \"%.2f\", $MEMORY_RSS_KB/1024}")
            MEMORY_VSZ_MB="0.00"
        fi
        
        # Set default values if extraction fails
        CPU_PERCENT=${CPU_PERCENT:-0.0}
        MEMORY_RSS_KB=${MEMORY_RSS_KB:-0}
        MEMORY_RSS_MB=${MEMORY_RSS_MB:-0.00}
        MEMORY_VSZ_MB=${MEMORY_VSZ_MB:-0.00}
        
        # Track maximum values
        if [ $(compare_float "$CPU_PERCENT" "$MAX_CPU") -eq 1 ]; then
            MAX_CPU="$CPU_PERCENT"
            MAX_CPU_TIME="$FORMATTED_TIME"
        fi
        
        if [ $(compare_float "$MEMORY_RSS_MB" "$MAX_MEMORY_MB") -eq 1 ]; then
            MAX_MEMORY_MB="$MEMORY_RSS_MB"
            MAX_MEMORY_TIME="$FORMATTED_TIME"
        fi
        
        # Log the data
        echo "$EPOCH_NANOS,$FORMATTED_TIME,$CPU_PERCENT,$MEMORY_RSS_MB,$MEMORY_RSS_KB,$MEMORY_VSZ_MB,$PID,$PROCESS_NAME" >> $REPORT_FILE
        
        SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
        
        # Print progress every 50 samples (approximately every 5 seconds)
        if [ $((SAMPLE_COUNT % 50)) -eq 0 ]; then
            ELAPSED=$(($(date +%s) - START_TIME))
            REMAINING=$((DURATION - ELAPSED))
            echo "Sample $SAMPLE_COUNT | Elapsed: ${ELAPSED}s | Remaining: ${REMAINING}s"
            echo "  Current - CPU: $CPU_PERCENT% | Memory: ${MEMORY_RSS_MB}MB (${MEMORY_RSS_KB}KB)"
            echo "  Peak    - CPU: $MAX_CPU% | Memory: ${MAX_MEMORY_MB}MB"
        fi
    else
        # Process not found
        if [ $((SAMPLE_COUNT % 100)) -eq 0 ]; then
            echo "WARNING: Process '$PROCESS_NAME' not found at $(date +%H:%M:%S)"
        fi
    fi
    
    sleep $INTERVAL
done

# Final summary
echo "=========================================="
echo "MONITORING COMPLETED"
echo "=========================================="
echo "Process: $PROCESS_NAME"
echo "Total samples collected: $SAMPLE_COUNT"
echo "Total monitoring duration: $DURATION seconds"
echo ""
echo "PEAK PERFORMANCE METRICS:"
echo "-------------------------"
echo "Maximum CPU usage: ${MAX_CPU}%"
if [ -n "$MAX_CPU_TIME" ]; then
    echo "CPU peak occurred at: $MAX_CPU_TIME"
fi
echo ""
echo "Maximum Memory usage: ${MAX_MEMORY_MB}MB"
if [ -n "$MAX_MEMORY_TIME" ]; then
    echo "Memory peak occurred at: $MAX_MEMORY_TIME"
fi
echo ""
echo "Log file: $REPORT_FILE"

# Generate summary statistics if we have data
if [ $SAMPLE_COUNT -gt 0 ]; then
    echo ""
    echo "SUMMARY STATISTICS:"
    echo "-------------------"
    
    # Calculate average CPU and memory usage
    AVG_CPU=$(awk -F',' 'NR>8 && $3!="" {sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count; else print "0.00"}' "$REPORT_FILE")
    AVG_MEMORY_MB=$(awk -F',' 'NR>8 && $4!="" {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "0.00"}' "$REPORT_FILE")
    
    # Find minimum values
    MIN_CPU=$(awk -F',' 'NR>8 && $3!="" {if(min=="" || $3<min) min=$3} END {print min}' "$REPORT_FILE")
    MIN_MEMORY_MB=$(awk -F',' 'NR>8 && $4!="" {if(min=="" || $4<min) min=$4} END {print min}' "$REPORT_FILE")
    
    echo "Average CPU usage: ${AVG_CPU}%"
    echo "Minimum CPU usage: ${MIN_CPU}%"
    echo "Average Memory usage: ${AVG_MEMORY_MB}MB"
    echo "Minimum Memory usage: ${MIN_MEMORY_MB}MB"
    echo ""
    echo "Data points collected: $SAMPLE_COUNT"
    echo "Sampling rate achieved: $(awk "BEGIN {printf \"%.1f\", $SAMPLE_COUNT/($DURATION/$INTERVAL)*100}")% of target"
    
    # Calculate memory consumption statistics
    MAX_MEMORY_KB=$(awk -F',' 'NR>8 && $5!="" {if(max=="" || $5>max) max=$5} END {print max}' "$REPORT_FILE")
    AVG_MEMORY_KB=$(awk -F',' 'NR>8 && $5!="" {sum+=$5; count++} END {if(count>0) printf "%.0f", sum/count; else print "0"}' "$REPORT_FILE")
    MAX_VIRTUAL_MB=$(awk -F',' 'NR>8 && $6!="" {if(max=="" || $6>max) max=$6} END {print max}' "$REPORT_FILE")
    
    if [ -n "$MAX_MEMORY_KB" ] && [ "$MAX_MEMORY_KB" -gt 0 ]; then
        echo ""
        echo "DETAILED MEMORY CONSUMPTION:"
        echo "-----------------------------"
        echo "Peak RSS (Resident Set Size): ${MAX_MEMORY_KB}KB (${MAX_MEMORY_MB}MB)"
        echo "Average RSS: ${AVG_MEMORY_KB}KB (${AVG_MEMORY_MB}MB)"
        echo "Peak Virtual Memory: ${MAX_VIRTUAL_MB}MB"
        
        # Convert to GB if memory usage is high
        if [ $(awk "BEGIN {print ($MAX_MEMORY_MB > 1024)}") -eq 1 ]; then
            MAX_MEMORY_GB=$(awk "BEGIN {printf \"%.2f\", $MAX_MEMORY_MB/1024}")
            echo "Peak RSS in GB: ${MAX_MEMORY_GB}GB"
        fi
    fi
fi

echo ""
echo "Monitoring session completed successfully!"
echo "=========================================="