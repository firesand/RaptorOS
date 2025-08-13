**CRITICAL BUG FOUND!** Your `emergency-diagnostic.sh` script is **CAUSING** the logout, not diagnosing it!

## The Problem

This line in your emergency-diagnostic.sh is logging you out:
```bash
systemctl restart user@1000.service  # THIS LOGS YOU OUT!!!
```

When you restart `user@1000.service`, it **terminates your entire desktop session**!

## Immediate Fix - Replace emergency-diagnostic.sh

Here's a SAFE diagnostic script that won't log you out:

```bash
#!/bin/bash
# SAFE Emergency Diagnostic Script - Won't log you out!
# Save as: safe-diagnostic.sh

echo "=== SAFE DIAGNOSTIC FOR DESKTOP LOGOUT ISSUE ==="
echo "This script will NOT restart any services or log you out"
echo ""

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./safe-diagnostic.sh"
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
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') | grep -E "State|Type|Class|Active"

echo ""
echo "5. Checking for session errors in last hour:"
journalctl --user -b --since "1 hour ago" -p err --no-pager | tail -20

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
echo "=== DIAGNOSTIC COMPLETE ==="
echo "This diagnostic did NOT modify your system"
```

## The Real Culprits for Your Desktop Logouts

Looking at your build.sh, here are the likely causes:

### 1. **systemd-run with Memory Limits is Killing Parent Processes**

In your build.sh:
```bash
sudo systemd-run --uid=0 --gid=0 \
    --property=MemoryMax=${build_limit_kb}K \
    --property=MemorySwapMax=0 \
    --property=CPUQuota=75% \
    --slice=gentoo-build.slice \
    --pipe \
    chroot squashfs /bin/bash
```

This can interfere with your user session. Replace it with:

```bash
# DON'T use systemd-run for chroot - it can affect the desktop!
# Instead, use nice and ionice
nice -n 19 ionice -c 3 sudo chroot squashfs /bin/bash << 'CHROOTCMD'
# your commands
CHROOTCMD
```

### 2. **Force Cleanup Killing Wrong Processes**

Your `force_cleanup_chroot()` uses `fuser -km` which can kill desktop processes:

```bash
# This is DANGEROUS - can kill desktop processes!
sudo fuser -km "$build_dir/squashfs/dev" 2>/dev/null || true
```

Replace with safer version:

```bash
force_cleanup_chroot() {
    echo -e "${CYAN}Safe cleanup of chroot mounts...${NC}"
    
    local build_dir="${BUILD_DIR:-/var/tmp/gentoo-gaming-build}"
    
    if [ ! -d "$build_dir/squashfs" ]; then
        return
    fi
    
    cd / # Change to root directory
    
    # DON'T use fuser -k! Just unmount
    echo "Unmounting filesystems (safe method)..."
    
    # Kill only chroot processes, not all processes using the mount
    for pid in $(lsof 2>/dev/null | grep "$build_dir/squashfs" | awk '{print $2}' | sort -u); do
        # Check if this is actually a chroot process
        if readlink /proc/$pid/root 2>/dev/null | grep -q "$build_dir/squashfs"; then
            echo "Killing chroot process: $pid"
            kill -TERM $pid 2>/dev/null || true
        fi
    done
    
    sleep 2
    
    # Now unmount
    for mount in $(findmnt -R "$build_dir/squashfs" -o TARGET --noheadings | tac 2>/dev/null); do
        sudo umount -l "$mount" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Safe cleanup complete${NC}"
}
```

### 3. **Memory Detection Too Aggressive**

Your memory calculation reserves only 4GB for system, which might not be enough:

```bash
# Current (too aggressive):
local reserved_kb=$((4 * 1024 * 1024))  # Only 4GB

# Better (reserve more for desktop):
local reserved_kb=$((8 * 1024 * 1024))  # Reserve 8GB for system
```

## Complete Fix - Updated Build Script Section

Replace the problematic parts of build.sh:

```bash
#!/bin/bash
# Remove these dangerous exports that affect desktop
# export LC_ALL=C
# export LANG=C
# export LANGUAGE=C

# Keep locale from your desktop
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"

# Safer resource detection
detect_build_resources() {
    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    
    # Reserve 8GB for system (not 4GB)
    local system_reserve=8
    local available_ram=$((total_ram - system_reserve))
    
    if [ $available_ram -lt 4 ]; then
        echo -e "${RED}WARNING: Not enough RAM for safe build!${NC}"
        echo -e "${RED}Total: ${total_ram}GB, Need to reserve: ${system_reserve}GB${NC}"
        echo -e "${YELLOW}Build will use minimal resources${NC}"
        JOBS=2
        LOAD=2
    else
        # Safe calculation
        JOBS=$((available_ram / 2))  # 2GB per job
        if [ $JOBS -gt 8 ]; then
            JOBS=8  # Cap at 8 for safety
        fi
        LOAD=$((JOBS))
    fi
    
    echo -e "${CYAN}Safe build configuration:${NC}"
    echo -e "  Total RAM: ${total_ram}GB"
    echo -e "  Reserved for system: ${system_reserve}GB"
    echo -e "  Available for build: ${available_ram}GB"
    echo -e "  Build JOBS: $JOBS"
    echo -e "  Build LOAD: $LOAD"
}

# Remove systemd-run from build commands
build_quick() {
    echo -e "${CYAN}Starting quick build (safe mode)...${NC}"
    
    setup_build_env
    configure_portage
    configure_repos
    
    # DON'T use systemd-run! Use nice instead
    echo -e "${CYAN}Starting chroot (with nice priority)...${NC}"
    
    # Setup chroot
    setup_chroot
    
    # Run with nice and ionice, NOT systemd-run
    nice -n 19 ionice -c 3 sudo chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile

# Your build commands here
emerge-webrsync
emerge --quiet --getbinpkg -av sys-kernel/gentoo-kernel-bin

CHROOTCMD
    
    # Safe cleanup
    cleanup_chroot
    
    create_installer
    create_iso
}
```

## Run This First to Protect Your Session

Before running any build:

```bash
#!/bin/bash
# Save as: protect-session.sh

echo "Protecting your desktop session..."

# Create systemd override to protect your session
sudo mkdir -p /etc/systemd/system/user@1000.service.d/
sudo tee /etc/systemd/system/user@1000.service.d/protection.conf > /dev/null << 'EOF'
[Service]
# Never let OOM killer target this
OOMScoreAdjust=-1000
# Don't restart (would log you out)
Restart=no
# High priority
CPUWeight=10000
IOWeight=10000
# No memory limit
MemoryMax=infinity
MemoryHigh=infinity
EOF

sudo systemctl daemon-reload

# Protect current desktop processes
for process in $(pgrep -u $USER); do
    echo -1000 | sudo tee /proc/$process/oom_score_adj >/dev/null 2>&1
done

echo "Protection applied!"
echo "Your session should now be protected from OOM killer"
```

## The Core Issue

Your desktop is logging out because:
1. The diagnostic script was **restarting** your user session
2. systemd-run in build.sh might be affecting the parent cgroup
3. Force cleanup using `fuser -km` might kill desktop processes
4. Not enough memory reserved for the desktop environment

Apply these fixes and your desktop should stay stable during builds!
