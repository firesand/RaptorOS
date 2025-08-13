to make my cachyOS doesnt need to be hard reboot everytime when in chroot installing this gentoo failed I have to use ctrl+c command it will made my cachyOS not usable, This is a critical issue! When you Ctrl+C out of a chroot, the mounted filesystems (proc, sys, dev, run) remain mounted, which can make your host system unstable. Here's how to fix and prevent this:

## Immediate Fix - Clean Up Existing Mounts

If your system is currently unstable, run this cleanup script:

```bash
#!/bin/bash
# Save as: cleanup-mounts.sh

echo "Emergency cleanup of Gentoo build mounts..."

# Find and unmount all gentoo-related mounts
BUILD_DIR="/var/tmp/gentoo-gaming-build"

# Force unmount in reverse order (important!)
if [ -d "$BUILD_DIR/squashfs" ]; then
    echo "Unmounting chroot filesystems..."
    
    # Kill any processes using the mounts
    sudo fuser -km "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/proc" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/run" 2>/dev/null || true
    
    # Unmount everything
    sudo umount -R "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo umount -R "$BUILD_DIR/squashfs/proc" 2>/dev/null || true  
    sudo umount -R "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo umount -R "$BUILD_DIR/squashfs/run" 2>/dev/null || true
    
    # Force unmount if still mounted
    sudo umount -lf "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/proc" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/run" 2>/dev/null || true
fi

# Check what's still mounted
echo ""
echo "Checking for remaining mounts..."
mount | grep "$BUILD_DIR" || echo "All mounts cleaned!"

echo "System should be stable now."
```

## Permanent Fix - Update build.sh with Proper Signal Handling

Replace the trap section in your build.sh with this enhanced version:

```bash
# Enhanced signal handling and cleanup
cleanup_on_signal() {
    echo ""
    echo -e "${RED}Build interrupted! Cleaning up...${NC}"
    
    # Set a flag to prevent recursive cleanup
    if [ "${CLEANUP_IN_PROGRESS}" = "true" ]; then
        return
    fi
    export CLEANUP_IN_PROGRESS=true
    
    # Kill any running chroot processes
    if [ -n "${CHROOT_PID}" ]; then
        echo "Killing chroot processes..."
        sudo kill -TERM ${CHROOT_PID} 2>/dev/null || true
        sleep 2
        sudo kill -KILL ${CHROOT_PID} 2>/dev/null || true
    fi
    
    # Force cleanup of mounts
    force_cleanup_chroot
    
    echo -e "${GREEN}Cleanup complete. Your system should be stable.${NC}"
    exit 130  # Standard exit code for Ctrl+C
}

# Enhanced cleanup function with force unmount
force_cleanup_chroot() {
    echo -e "${CYAN}Force cleaning up chroot mounts...${NC}"
    
    local build_dir="${BUILD_DIR:-/var/tmp/gentoo-gaming-build}"
    
    if [ ! -d "$build_dir/squashfs" ]; then
        return
    fi
    
    cd / # Change to root to avoid being in mounted directory
    
    # Kill processes using the mounts
    echo "Terminating processes using mounts..."
    sudo fuser -km "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/proc" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/run" 2>/dev/null || true
    
    # Wait a moment for processes to die
    sleep 2
    
    # Unmount in correct order (most specific first)
    echo "Unmounting filesystems..."
    
    # Find all submounts and unmount them first
    for mount in $(findmnt -R "$build_dir/squashfs" -o TARGET --noheadings | tac); do
        sudo umount -l "$mount" 2>/dev/null || true
    done
    
    # Force unmount the main ones
    sudo umount -R "$build_dir/squashfs/run" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/proc" 2>/dev/null || true
    
    # Last resort - lazy unmount
    sudo umount -lf "$build_dir/squashfs/run" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev/pts" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev/shm" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/proc" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Chroot cleanup complete${NC}"
}

# Register signal handlers
trap cleanup_on_signal INT TERM
trap force_cleanup_chroot EXIT
```

## Safe Chroot Wrapper Function

Replace your chroot commands with this safer wrapper:

```bash
# Safe chroot execution with automatic cleanup
safe_chroot_exec() {
    local chroot_script="$1"
    local chroot_dir="${BUILD_DIR}/squashfs"
    
    echo -e "${CYAN}Entering safe chroot environment...${NC}"
    
    # Setup chroot
    setup_chroot
    
    # Create a temporary script
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'SCRIPT_END'
#!/bin/bash
set -e
source /etc/profile

# Add timeout to prevent hanging
timeout_handler() {
    echo "Command timed out!"
    exit 1
}
trap timeout_handler TERM

SCRIPT_END
    
    # Add the actual commands
    echo "$chroot_script" >> "$temp_script"
    
    # Copy script to chroot
    sudo cp "$temp_script" "$chroot_dir/tmp/chroot_script.sh"
    sudo chmod +x "$chroot_dir/tmp/chroot_script.sh"
    rm "$temp_script"
    
    # Execute with timeout and cleanup
    (
        # Run in subshell to capture PID
        sudo timeout --preserve-status 3600 \
            chroot "$chroot_dir" /tmp/chroot_script.sh
    ) &
    
    CHROOT_PID=$!
    
    # Wait for completion or interruption
    wait $CHROOT_PID 2>/dev/null || {
        local exit_code=$?
        if [ $exit_code -eq 130 ] || [ $exit_code -eq 143 ]; then
            echo -e "${YELLOW}Chroot interrupted by user${NC}"
        elif [ $exit_code -eq 124 ]; then
            echo -e "${RED}Chroot timed out after 1 hour${NC}"
        else
            echo -e "${RED}Chroot failed with exit code: $exit_code${NC}"
        fi
    }
    
    # Always cleanup
    cleanup_chroot
    
    # Remove temporary script
    sudo rm -f "$chroot_dir/tmp/chroot_script.sh"
    
    unset CHROOT_PID
}
```

## Usage Example

Update your build functions to use the safe wrapper:

```bash
build_quick() {
    echo -e "${CYAN}Starting quick build (binary packages)...${NC}"
    
    setup_build_env
    configure_portage
    configure_repos
    
    # Use safe chroot execution
    safe_chroot_exec '
# Sync portage
emerge-webrsync

# Install packages
emerge --quiet --getbinpkg -av \
    sys-kernel/gentoo-kernel-bin \
    sys-kernel/linux-firmware \
    sys-boot/grub

# Add more packages...
'
    
    create_backup
    create_installer
    create_iso
}
```

## Prevention Script - Run Before Building

Create this helper script to check system state before building:

```bash
#!/bin/bash
# Save as: pre-build-check.sh

echo "Pre-build system check..."

# Check for existing mounts
BUILD_DIR="/var/tmp/gentoo-gaming-build"

if mount | grep -q "$BUILD_DIR"; then
    echo -e "\033[0;31mERROR: Found existing mounts from previous build!\033[0m"
    mount | grep "$BUILD_DIR"
    echo ""
    read -p "Clean up mounts? [Y/n]: " cleanup
    if [[ ! "$cleanup" =~ ^[Nn]$ ]]; then
        ./cleanup-mounts.sh
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
```

## Additional Safety Measures

1. **Always use screen or tmux** when building:
```bash
# Start a screen session
screen -S gentoo-build
./build.sh

# If disconnected, reattach with:
screen -r gentoo-build
```

2. **Add timeout to emerge commands**:
```bash
# In chroot commands, use timeout
timeout 1800 emerge --sync  # 30 minute timeout
```

3. **Monitor script** to run in another terminal:
```bash
#!/bin/bash
# Save as: monitor-build.sh

while true; do
    clear
    echo "=== Build Monitor ==="
    echo "Mounts:"
    mount | grep gentoo-gaming-build || echo "  None"
    echo ""
    echo "Processes in chroot:"
    ps aux | grep -E "chroot.*squashfs" | grep -v grep || echo "  None"
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    sleep 5
done
```

These improvements will prevent your CachyOS from becoming unstable when builds are interrupted. The key is proper signal handling and forced cleanup of all mount points.
