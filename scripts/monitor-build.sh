#!/bin/bash
# Build Monitor for RaptorOS
# Run this in another terminal to monitor build progress

echo "Starting RaptorOS build monitor..."
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    echo "=== RaptorOS Build Monitor ==="
    echo "Timestamp: $(date)"
    echo ""
    
    echo "Mounts:"
    mount | grep gentoo-gaming-build || echo "  None"
    echo ""
    
    echo "Processes in chroot:"
    ps aux | grep -E "chroot.*squashfs" | grep -v grep || echo "  None"
    echo ""
    
    echo "Build directory status:"
    BUILD_DIR="/var/tmp/gentoo-gaming-build"
    if [ -d "$BUILD_DIR" ]; then
        echo "  Build dir: $BUILD_DIR"
        if [ -d "$BUILD_DIR/squashfs" ]; then
            echo "  Squashfs: $(du -sh "$BUILD_DIR/squashfs" 2>/dev/null | cut -f1 || echo 'Unknown')"
        fi
        if [ -d "$BUILD_DIR/iso" ]; then
            echo "  ISO dir: $(du -sh "$BUILD_DIR/iso" 2>/dev/null | cut -f1 || echo 'Unknown')"
        fi
    else
        echo "  Build directory not found"
    fi
    echo ""
    
    echo "System resources:"
    echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Memory: $(free -h | grep Mem | awk '{print "Used: " $3 " / Total: " $2}')"
    echo "  Disk: $(df -h /var/tmp | tail -1 | awk '{print "Available: " $4}')"
    echo ""
    
    echo "Refreshing in 5 seconds..."
    sleep 5
done
