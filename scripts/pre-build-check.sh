#!/bin/bash
# Pre-build system check for RaptorOS
# Run this before starting a build to ensure system stability

echo "Pre-build system check..."

# Check for existing mounts
BUILD_DIR="/var/tmp/gentoo-gaming-build"

if mount | grep -q "$BUILD_DIR"; then
    echo -e "\033[0;31mERROR: Found existing mounts from previous build!\033[0m"
    mount | grep "$BUILD_DIR"
    echo ""
    read -p "Clean up mounts? [Y/n]: " cleanup
    if [[ ! "$cleanup" =~ ^[Nn]$ ]]; then
        ./scripts/cleanup-mounts.sh
    else
        echo "Cannot proceed with existing mounts. Exiting."
        exit 1
    fi
fi

# Check system resources
echo "System resources:"
echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Memory: $(free -h | grep Mem | awk '{print "Used: " $3 " / Total: " $2}')"
echo "  Disk: $(df -h /var/tmp | tail -1 | awk '{print "Available: " $4}')"

echo -e "\033[0;32mSystem ready for build!\033[0m"
