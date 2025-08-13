#!/bin/bash
# Emergency Diagnostic Script for Desktop Logout Issue
# This script will help identify what's killing your user session

echo "=== EMERGENCY DIAGNOSTIC FOR DESKTOP LOGOUT ==="
echo "This script will help identify what's killing your session"
echo ""

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "=== SYSTEM STATUS CHECK ==="

# Check systemd status
echo "Checking systemd status..."
systemctl status --no-pager -l

echo ""
echo "=== USER SESSION STATUS ==="

# Check user session
echo "Checking user@1000.service status..."
systemctl status --no-pager -l user@1000.service

echo ""
echo "=== MEMORY STATUS ==="

# Check memory
echo "Memory status:"
free -h
echo ""
echo "Memory pressure:"
cat /proc/pressure/memory 2>/dev/null || echo "Memory pressure not available"

echo ""
echo "=== PROCESS TREE ==="

# Check process tree for user 1000
echo "Processes for user 1000:"
ps -u 1000 -o pid,ppid,cmd --forest

echo ""
echo "=== SYSTEMD USER SLICE ==="

# Check systemd user slice
echo "User slice status:"
systemctl status --no-pager -l user.slice

echo ""
echo "=== RECENT SYSTEM EVENTS ==="

# Check recent system events
echo "Recent system events (last 10 minutes):"
journalctl -b --since "10 minutes ago" -p err | tail -20

echo ""
echo "=== KERNEL MESSAGES ==="

# Check kernel messages
echo "Recent kernel messages:"
dmesg | tail -20

echo ""
echo "=== EMERGENCY PROTECTION ==="

# Try to protect the user session
echo "Attempting to protect user session..."

# Set maximum protection for user session
if systemctl is-active --quiet user@1000.service; then
    echo "Setting maximum protection for user@1000.service..."
    
    # Create override directory
    mkdir -p /etc/systemd/system/user@1000.service.d/
    
    # Create override file with maximum protection
    cat > /etc/systemd/system/user@1000.service.d/emergency-protection.conf << 'EOF'
[Service]
# Maximum OOM protection
OOMScoreAdjust=-1000
# Restart on failure
Restart=always
RestartSec=1
# Maximum restart attempts
StartLimitInterval=0
StartLimitBurst=0
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Restart user session
    echo "Restarting user session with protection..."
    systemctl restart user@1000.service
    
    echo "Emergency protection applied!"
else
    echo "User session not running - cannot apply protection"
fi

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
echo "Check the output above for clues about what's killing your session"
echo ""
echo "If the issue persists, this might be a hardware problem or kernel issue"
echo "Consider:"
echo "1. Checking hardware (RAM, CPU, power supply)"
echo "2. Updating kernel and system packages"
echo "3. Checking for hardware overheating"
echo "4. Running memtest86+ to check RAM integrity"
