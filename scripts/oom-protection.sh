#!/bin/bash
# OOM Protection for Gentoo Build
# This script protects your desktop from being killed by the OOM killer

echo "Setting up OOM protection for Gentoo build..."

# Adjust OOM scores to protect desktop
protect_desktop() {
    echo "Protecting desktop environment from OOM killer..."
    
    # Protect critical desktop processes with maximum priority
    for process in plasmashell kwin_x11 kwin_wayland gnome-shell xfce4-session mate-session cinnamon budgie-panel sway wayfire sddm lightdm gdm; do
        pgrep "$process" | while read pid; do
            echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
            echo "Protected: $process (PID: $pid)"
        done
    done
    
    # Protect display manager and X11 processes
    for process in Xorg Xwayland dbus-daemon systemd user@1000.service; do
        pgrep -f "$process" | while read pid; do
            echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
            echo "Protected: $process (PID: $pid)"
        done
    done
    
    # Make build processes more likely to be killed
    pgrep -f "emerge\|gcc\|g\+\+\|cc1\|cc1plus\|make\|ninja" | while read pid; do
        echo 1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
        echo "Marked for OOM: build process (PID: $pid)"
    done
    
    echo "Enhanced OOM protection applied"
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

# Set up cgroup limits if available
setup_cgroup_limits() {
    if [ -d /sys/fs/cgroup/memory ]; then
        echo "Setting up cgroup memory limits..."
        
        # Create gentoo-build cgroup
        sudo mkdir -p /sys/fs/cgroup/memory/gentoo-build
        
        # Get total RAM and set limit to 80%
        local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local limit_kb=$((total_ram_kb * 80 / 100))
        
        echo $limit_kb | sudo tee /sys/fs/cgroup/memory/gentoo-build/memory.limit_in_bytes >/dev/null
        
        echo "Cgroup memory limit: $((limit_kb / 1024 / 1024))GB"
    fi
}

# Disable interfering services temporarily
disable_interfering_services() {
    echo "Disabling services that interfere with OOM protection..."
    
    # Disable ananicy-cpp temporarily (it can override our OOM scores)
    if systemctl is-active --quiet ananicy-cpp; then
        echo "Stopping ananicy-cpp service..."
        sudo systemctl stop ananicy-cpp
        echo "ananicy-cpp stopped"
    fi
    
    # Disable other potential interference
    for service in oomd systemd-oomd; do
        if systemctl is-active --quiet "$service"; then
            echo "Stopping $service service..."
            sudo systemctl stop "$service"
            echo "$service stopped"
        fi
    done
    
    echo "Interfering services disabled"
}

# Main execution
protect_desktop
setup_memory_limits
setup_cgroup_limits
disable_interfering_services

echo "OOM protection setup complete!"
echo "Your desktop should now be protected from memory-related crashes."
echo ""
echo "IMPORTANT: After your build completes, run:"
echo "  sudo ./scripts/restore-services.sh"
echo "to restore normal system services."
