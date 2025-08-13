#!/bin/bash
# Continuous OOM Protection for Gentoo Build
# This script runs continuously to ensure desktop processes stay protected

echo "Starting continuous OOM protection..."
echo "This script will run until you stop it (Ctrl+C)"
echo "Keep it running during your entire build process!"

# Create a flag file to track if we're protecting
PROTECTION_FILE="/tmp/gentoo-oom-protection-active"

# Function to protect desktop processes
protect_desktop_continuous() {
    while [ -f "$PROTECTION_FILE" ]; do
        # Protect critical desktop processes every 5 seconds
        for process in plasmashell kwin_x11 kwin_wayland gnome-shell xfce4-session mate-session cinnamon budgie-panel sway wayfire sddm lightdm gdm; do
            pgrep "$process" | while read pid; do
                echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
            done
        done
        
        # Protect display manager and X11 processes
        for process in Xorg Xwayland dbus-daemon systemd user@1000.service; do
            pgrep -f "$process" | while read pid; do
                echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
            done
        done
        
        # Mark build processes for OOM
        pgrep -f "emerge\|gcc\|g\+\+\|cc1\|cc1plus\|make\|ninja" | while read pid; do
            echo 1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
        done
        
        # Check memory usage and warn if critical
        local ram_percent=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        if [ $ram_percent -gt 90 ]; then
            echo "⚠️  WARNING: RAM usage critical (${ram_percent}%) - Consider stopping build!"
        fi
        
        sleep 5
    done
}

# Set up signal handling
cleanup() {
    echo "Stopping continuous OOM protection..."
    rm -f "$PROTECTION_FILE"
    echo "OOM protection stopped"
    exit 0
}

trap cleanup INT TERM

# Create protection flag
touch "$PROTECTION_FILE"

# Start continuous protection
protect_desktop_continuous
