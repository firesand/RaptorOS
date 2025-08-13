#!/bin/bash
# Safe Session Protection Script - Won't log you out!
# This script protects your desktop session from OOM killer

echo "=== SAFE SESSION PROTECTION ==="
echo "This script will NOT restart any services or log you out"
echo ""

# Check if we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./scripts/protect-session.sh"
    exit 1
fi

echo "Protecting your desktop session..."

# Create systemd override to protect your session
echo "Creating systemd override for user@1000.service..."
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

echo "Reloading systemd..."
sudo systemctl daemon-reload

# Protect current desktop processes
echo "Protecting current desktop processes..."
for process in $(pgrep -u $SUDO_USER); do
    echo -1000 | sudo tee /proc/$process/oom_score_adj >/dev/null 2>&1
done

# Protect specific desktop processes
echo "Protecting critical desktop processes..."
for process in plasmashell kwin_x11 kwin_wayland gnome-shell xfce4-session mate-session cinnamon budgie-panel sway wayfire sddm lightdm gdm Xorg Xwayland dbus-daemon; do
    pgrep "$process" | while read pid; do
        echo -1000 | sudo tee /proc/$pid/oom_score_adj >/dev/null 2>&1
        echo "Protected: $process (PID: $pid)"
    done
done

echo ""
echo "✓ Session protection applied!"
echo "✓ Your session should now be protected from OOM killer"
echo "✓ No services were restarted"
echo ""
echo "IMPORTANT: Keep this protection active during builds"
