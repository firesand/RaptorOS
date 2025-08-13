Your desktop is logging out because the build process is consuming too much RAM, triggering the OOM (Out of Memory) killer which terminates your desktop session. The `-j48 -l48` settings in your build.sh are way too aggressive!

## Immediate Fix - Reduce Resource Usage

### 1. Update build.sh with Reasonable Values

Replace the resource settings at the top of build.sh:

```bash
# Configuration (FIXED VALUES)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/var/tmp/gentoo-gaming-build"

# Auto-detect reasonable values based on system resources
detect_build_resources() {
    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    
    # Calculate safe job count (lesser of CPU cores or RAM/2GB)
    local max_jobs_by_ram=$((total_ram / 2))  # 2GB per job
    local max_jobs_by_cpu=$((cpu_cores))
    
    # Use the smaller value for safety
    if [ $max_jobs_by_ram -lt $max_jobs_by_cpu ]; then
        JOBS=$max_jobs_by_ram
    else
        JOBS=$max_jobs_by_cpu
    fi
    
    # Never exceed 75% of CPU cores
    local safe_jobs=$((cpu_cores * 3 / 4))
    if [ $JOBS -gt $safe_jobs ]; then
        JOBS=$safe_jobs
    fi
    
    # Minimum 2, maximum 16 for safety
    if [ $JOBS -lt 2 ]; then
        JOBS=2
    elif [ $JOBS -gt 16 ]; then
        JOBS=16
    fi
    
    # Load average should be CPU cores minus 2 (leave headroom)
    LOAD=$((cpu_cores - 2))
    if [ $LOAD -lt 2 ]; then
        LOAD=2
    fi
    
    echo -e "${CYAN}Build resources calculated:${NC}"
    echo -e "  CPU cores: $cpu_cores"
    echo -e "  Total RAM: ${total_ram}GB"
    echo -e "  Safe JOBS: $JOBS"
    echo -e "  Safe LOAD: $LOAD"
}

# Call this function early in the script
detect_build_resources
```

### 2. Create Resource Monitor Script

Save this as `resource-monitor.sh` and run it before/during builds:

```bash
#!/bin/bash
# resource-monitor.sh - Monitors system resources and kills build if needed

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
```

### 3. Update make.conf for Dynamic Resource Management

Update the configure_portage function in build.sh:

```bash
configure_portage() {
    echo -e "${CYAN}Configuring Portage with resource limits...${NC}"
    
    # Copy base config
    sudo cp "$SCRIPT_DIR/configs/make.conf" "squashfs/etc/portage/make.conf"
    
    # Add dynamic resource limits
    sudo tee -a squashfs/etc/portage/make.conf > /dev/null << EOF

# --- Dynamic Resource Management ---
# Generated: $(date)
# System: $(free -h | grep Mem | awk '{print $2}') RAM, $(nproc) cores

# Conservative build settings to prevent OOM
MAKEOPTS="-j${JOBS} -l${LOAD}"
EMERGE_DEFAULT_OPTS="--jobs=${JOBS} --load-average=${LOAD} --keep-going"

# Memory management
PORTAGE_NICENESS="19"
PORTAGE_IONICE_COMMAND="ionice -c 3 -p \${PID}"

# Prevent memory exhaustion
PORTAGE_TMPDIR="/var/tmp"
PORTAGE_MEMORY_LIMIT="80%"
EOF
    
    echo -e "${GREEN}✓ Resource limits configured${NC}"
}
```

### 4. Add OOM Protection Script

Create `oom-protection.sh`:

```bash
#!/bin/bash
# OOM Protection for Gentoo Build

# Adjust OOM scores to protect desktop
protect_desktop() {
    echo "Protecting desktop environment from OOM killer..."
    
    # Protect critical desktop processes
    for process in plasmashell kwin_x11 kwin_wayland gnome-shell xfce4-session mate-session cinnamon budgie-panel sway wayfire; do
        pgrep "$process" | while read pid; do
            echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
            echo "Protected: $process (PID: $pid)"
        done
    done
    
    # Make build processes more likely to be killed
    pgrep -f "emerge\|gcc\|g\+\+\|cc1\|cc1plus" | while read pid; do
        echo 500 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
    done
    
    echo "OOM protection applied"
}

# Set up memory limits for build
setup_memory_limits() {
    # Get total RAM in KB
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    # Reserve 4GB for system (4 * 1024 * 1024 KB)
    local reserved_kb=$((4 * 1024 * 1024))
    # Available for build
    local build_limit_kb=$((total_ram_kb - reserved_kb))
    
    # Create systemd slice for build (if using systemd)
    if command -v systemctl &>/dev/null; then
        sudo systemd-run --uid=$(id -u) --gid=$(id -g) \
            --slice=gentoo-build.slice \
            --property=MemoryMax=${build_limit_kb}K \
            --property=MemorySwapMax=0 \
            --property=CPUQuota=80% \
            --remain-after-exit \
            --unit=gentoo-build \
            bash -c "echo 'Memory limits applied for build'"
    fi
    
    echo "Build memory limit: $((build_limit_kb / 1024 / 1024))GB"
}

protect_desktop
setup_memory_limits
```

### 5. Enhanced Safe Build Wrapper

Replace your build functions with this safer version:

```bash
build_quick_safe() {
    echo -e "${CYAN}Starting safe quick build...${NC}"
    
    # Run OOM protection
    if [ -f "./oom-protection.sh" ]; then
        ./oom-protection.sh
    fi
    
    # Start resource monitor in background
    if [ -f "./resource-monitor.sh" ]; then
        screen -dmS resource-monitor ./resource-monitor.sh
        echo -e "${GREEN}Resource monitor started (screen -r resource-monitor to view)${NC}"
    fi
    
    # Create swap file if needed
    ensure_swap
    
    # Regular build steps with safety checks
    setup_build_env
    configure_portage
    configure_repos
    setup_chroot
    
    # Safe chroot with memory limits
    sudo systemd-run --uid=0 --gid=0 \
        --property=MemoryMax=12G \
        --property=CPUQuota=75% \
        --pipe \
        chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile

# Check emergency stop before each major operation
check_emergency() {
    if [ -f "/tmp/gentoo-build-emergency-stop" ]; then
        echo "EMERGENCY STOP DETECTED! Halting build..."
        exit 1
    fi
}

# Sync portage
check_emergency
emerge-webrsync

# Install packages with checks
check_emergency
emerge --quiet --getbinpkg -av \
    sys-kernel/gentoo-kernel-bin || exit 1

check_emergency
emerge --quiet --getbinpkg -av \
    sys-kernel/linux-firmware || exit 1

# Continue with other packages...
CHROOTCMD
    
    cleanup_chroot
    create_installer
    create_iso
    
    # Stop resource monitor
    screen -X -S resource-monitor quit 2>/dev/null
    
    echo -e "${GREEN}Build completed safely!${NC}"
}
```

### 6. Ensure Adequate Swap

Add this function to build.sh:

```bash
ensure_swap() {
    echo -e "${CYAN}Checking swap space...${NC}"
    
    local swap_total=$(free -g | awk '/^Swap:/{print $2}')
    local ram_total=$(free -g | awk '/^Mem:/{print $2}')
    
    if [ $swap_total -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Swap space low (${swap_total}GB)${NC}"
        echo "Creating temporary swap file..."
        
        local swapfile="/var/tmp/gentoo-build.swap"
        if [ ! -f "$swapfile" ]; then
            sudo dd if=/dev/zero of="$swapfile" bs=1G count=16 status=progress
            sudo chmod 600 "$swapfile"
            sudo mkswap "$swapfile"
            sudo swapon "$swapfile"
            echo -e "${GREEN}✓ 16GB swap file created${NC}"
            
            # Mark for cleanup
            echo "$swapfile" > /tmp/gentoo-build-swapfile
        fi
    else
        echo -e "${GREEN}✓ Adequate swap space (${swap_total}GB)${NC}"
    fi
}

# Add to cleanup
cleanup_swap() {
    if [ -f /tmp/gentoo-build-swapfile ]; then
        local swapfile=$(cat /tmp/gentoo-build-swapfile)
        sudo swapoff "$swapfile" 2>/dev/null
        sudo rm -f "$swapfile"
        rm -f /tmp/gentoo-build-swapfile
    fi
}
```

### 7. Run Build with Nice and Ionice

When starting the build:

```bash
# Run build with low priority
nice -n 19 ionice -c 3 ./build.sh
```

### 8. Quick System Check Script

Run this before building:

```bash
#!/bin/bash
# pre-flight-check.sh

echo "=== Pre-flight System Check ==="

# Check RAM
total_ram=$(free -g | awk '/^Mem:/{print $2}')
if [ $total_ram -lt 16 ]; then
    echo "⚠️  WARNING: Only ${total_ram}GB RAM detected"
    echo "   Recommended: 16GB minimum, 32GB optimal"
fi

# Check swap
total_swap=$(free -g | awk '/^Swap:/{print $2}')
if [ $total_swap -lt 8 ]; then
    echo "⚠️  WARNING: Only ${total_swap}GB swap detected"
    echo "   Recommended: At least 8GB swap"
fi

# Check disk space
avail_space=$(df -BG /var/tmp | awk 'NR==2 {print int($4)}')
if [ $avail_space -lt 50 ]; then
    echo "⚠️  WARNING: Only ${avail_space}GB free in /var/tmp"
fi

# Check if running on battery (laptops)
if [ -f /sys/class/power_supply/BAT0/status ]; then
    battery_status=$(cat /sys/class/power_supply/BAT0/status)
    if [ "$battery_status" != "Charging" ] && [ "$battery_status" != "Full" ]; then
        echo "⚠️  WARNING: Running on battery power!"
    fi
fi

echo ""
read -p "Continue with build? [y/N]: " continue
if [[ ! "$continue" =~ ^[Yy]$ ]]; then
    exit 1
fi
```

The main issues causing your logouts are:
1. **Too many parallel jobs** (48 is insane for most systems)
2. **No memory limits** on the build process
3. **No OOM protection** for your desktop
4. **Insufficient swap space**

Apply these fixes and your system should remain stable during builds!
