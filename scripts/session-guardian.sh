#!/bin/bash
# Session Guardian - Protects Your User Session from Being Killed
# This script runs continuously and restarts your session if it gets killed

echo "=== SESSION GUARDIAN STARTED ==="
echo "This script will protect your user session from being killed"
echo "Keep it running in a separate terminal during builds"
echo ""

# Configuration
USER_ID=1000
SESSION_SERVICE="user@${USER_ID}.service"
CHECK_INTERVAL=5
LOG_FILE="/tmp/session-guardian.log"

# Log function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Check if session is running
check_session() {
    if ! systemctl is-active --quiet "$SESSION_SERVICE"; then
        log_message "WARNING: User session is DOWN!"
        return 1
    fi
    
    # Check if user processes are running
    local user_processes=$(ps -u $USER_ID | wc -l)
    if [ $user_processes -lt 5 ]; then
        log_message "WARNING: Very few user processes running ($user_processes)"
        return 1
    fi
    
    return 0
}

# Restart session
restart_session() {
    log_message "ATTEMPTING TO RESTART USER SESSION..."
    
    # Try to restart the service
    if systemctl restart "$SESSION_SERVICE"; then
        log_message "SUCCESS: User session restarted"
        
        # Wait a moment for session to stabilize
        sleep 10
        
        # Check if it's running
        if systemctl is-active --quiet "$SESSION_SERVICE"; then
            log_message "SUCCESS: Session is now stable"
            return 0
        else
            log_message "ERROR: Session failed to stabilize after restart"
            return 1
        fi
    else
        log_message "ERROR: Failed to restart user session"
        return 1
    fi
}

# Emergency recovery
emergency_recovery() {
    log_message "EMERGENCY RECOVERY MODE ACTIVATED!"
    
    # Kill any processes that might be interfering
    pkill -f "emerge" 2>/dev/null || true
    pkill -f "gcc\|g\+\+\|cc1\|cc1plus" 2>/dev/null || true
    
    # Wait for processes to die
    sleep 5
    
    # Try to restart session again
    restart_session
}

# Main monitoring loop
monitor_session() {
    log_message "Session Guardian monitoring started"
    log_message "Monitoring: $SESSION_SERVICE"
    log_message "User ID: $USER_ID"
    log_message "Check interval: ${CHECK_INTERVAL}s"
    
    local consecutive_failures=0
    local max_failures=3
    
    while true; do
        # Check session status
        if check_session; then
            if [ $consecutive_failures -gt 0 ]; then
                log_message "Session recovered - resetting failure counter"
                consecutive_failures=0
            fi
        else
            consecutive_failures=$((consecutive_failures + 1))
            log_message "Session check failed (attempt $consecutive_failures/$max_failures)"
            
            if [ $consecutive_failures -ge $max_failures ]; then
                log_message "CRITICAL: Multiple session failures detected!"
                
                # Try normal restart first
                if restart_session; then
                    consecutive_failures=0
                else
                    # Try emergency recovery
                    emergency_recovery
                    consecutive_failures=0
                fi
            fi
        fi
        
        # Display status
        clear
        echo "=== SESSION GUARDIAN STATUS ==="
        echo "Time: $(date '+%H:%M:%S')"
        echo "Session: $SESSION_SERVICE"
        echo "Status: $(systemctl is-active $SESSION_SERVICE 2>/dev/null || echo 'DOWN')"
        echo "User Processes: $(ps -u $USER_ID | wc -l)"
        echo "Consecutive Failures: $consecutive_failures"
        echo "Memory Usage: $(free -h | grep Mem | awk '{print $3"/"$2}')"
        echo ""
        echo "Press Ctrl+C to stop monitoring"
        echo "Log file: $LOG_FILE"
        
        sleep $CHECK_INTERVAL
    done
}

# Signal handling
cleanup() {
    log_message "Session Guardian stopping..."
    echo ""
    echo "Session Guardian stopped"
    exit 0
}

trap cleanup INT TERM

# Start monitoring
monitor_session
