#!/bin/bash
# SAFE Emergency Diagnostic Script - Won't log you out!
# This script will NOT restart any services or log you out

echo "=== SAFE DIAGNOSTIC FOR DESKTOP LOGOUT ISSUE ==="
echo "This script will NOT restart any services or log you out"
echo ""

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./scripts/safe-diagnostic.sh"
    exit 1
fi

echo "=== CHECKING WHAT MIGHT BE KILLING YOUR SESSION ==="

# 1. Check OOM killer activity
echo "1. Checking if OOM killer is active..."
if dmesg | grep -i "killed process" | tail -5; then
    echo "⚠️  OOM KILLER HAS BEEN ACTIVE!"
else
    echo "✓ No recent OOM kills detected"
fi

echo ""
echo "2. Memory status:"
free -h
echo ""
echo "Swap usage:"
swapon --show

echo ""
echo "3. Top memory consumers:"
ps aux --sort=-%mem | head -10

echo ""
echo "4. Checking session status (WITHOUT restarting):"
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') 2>/dev/null | grep -E "State|Type|Class|Active" || echo "Cannot read session info"

echo ""
echo "5. Checking for session errors in last hour:"
journalctl --user -b --since "1 hour ago" -p err --no-pager 2>/dev/null | tail -20 || echo "Cannot read user journal"

echo ""
echo "6. Checking systemd-oomd status (if enabled):"
if systemctl is-enabled systemd-oomd &>/dev/null; then
    systemctl status systemd-oomd --no-pager | head -10
    echo "Recent oomd activity:"
    journalctl -u systemd-oomd -b --since "1 hour ago" --no-pager | tail -10
else
    echo "systemd-oomd is not enabled"
fi

echo ""
echo "7. Checking cgroup memory limits:"
cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.max 2>/dev/null || echo "No memory limit set"
cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.current 2>/dev/null || echo "Cannot read current memory"

echo ""
echo "8. Checking for any recent SIGKILL signals:"
dmesg | grep -i "killed\|sigkill\|status=9" | tail -10

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
echo "This diagnostic did NOT modify your system"
echo "✓ No services were restarted"
echo "✓ No processes were killed"
echo "✓ Your session remains intact"
