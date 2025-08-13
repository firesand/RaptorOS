#!/bin/bash
# Resource Monitor for Gentoo Build
# Monitors system resources and can trigger emergency stops

EMERGENCY_STOP_FILE="/tmp/gentoo-build-emergency-stop"
BUILD_DIR="/var/tmp/gentoo-gaming-build"

# Thresholds
MAX_RAM_PERCENT=85
MAX_SWAP_PERCENT=50
MIN_FREE_RAM_MB=2048
MAX_TEMP_CELSIUS=85

monitor_resources() {
    while true; do
        # Check RAM usage
        local ram_percent=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        local swap_percent=$(free | grep Swap | awk '{if ($2 > 0) print int($3/$2 * 100); else print 0}')
        local free_ram_mb=$(free -m | grep Mem | awk '{print $4}')
        
        # Check CPU temperature (if sensors available)
        local cpu_temp=0
        if command -v sensors &>/dev/null; then
            cpu_temp=$(sensors | grep -E "Core|Tctl" | awk '{print $3}' | grep -o '[0-9]*' | sort -rn | head -1)
        fi
        
        # Display status
        clear
        echo "=== Gentoo Build Resource Monitor ==="
        echo "Time: $(date '+%H:%M:%S')"
        echo ""
        echo "RAM Usage: ${ram_percent}% (Free: ${free_ram_mb}MB)"
        echo "Swap Usage: ${swap_percent}%"
        echo "CPU Temp: ${cpu_temp}°C"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        # Check critical conditions
        local critical=false
        local warning=""
        
        if [ $ram_percent -gt $MAX_RAM_PERCENT ]; then
            warning="${warning}⚠️  RAM usage critical (${ram_percent}%)!\n"
            critical=true
        fi
        
        if [ $swap_percent -gt $MAX_SWAP_PERCENT ] && [ $swap_percent -gt 0 ]; then
            warning="${warning}⚠️  Swap usage high (${swap_percent}%)!\n"
        fi
        
        if [ $free_ram_mb -lt $MIN_FREE_RAM_MB ]; then
            warning="${warning}⚠️  Free RAM too low (${free_ram_mb}MB)!\n"
            critical=true
        fi
        
        if [ $cpu_temp -gt $MAX_TEMP_CELSIUS ] && [ $cpu_temp -gt 0 ]; then
            warning="${warning}🔥 CPU temperature critical (${cpu_temp}°C)!\n"
            critical=true
        fi
        
        if [ -n "$warning" ]; then
            echo -e "WARNINGS:\n$warning"
        fi
        
        # Emergency stop if critical
        if [ "$critical" = true ]; then
            echo -e "\n🛑 CRITICAL: Creating emergency stop file!"
            touch "$EMERGENCY_STOP_FILE"
            
            # Try to reduce load
            echo "Attempting to reduce system load..."
            pkill -STOP -f "emerge"  # Pause emerge
            sleep 10
            pkill -CONT -f "emerge"  # Resume emerge
        fi
        
        echo ""
        echo "Press Ctrl+C to stop monitoring"
        echo "(Monitor refreshes every 10 seconds)"
        
        sleep 10
    done
}

# Run monitor
trap "rm -f $EMERGENCY_STOP_FILE 2>/dev/null" EXIT
monitor_resources
