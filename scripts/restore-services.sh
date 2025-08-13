#!/bin/bash
# Restore Services After Gentoo Build
# This script restores services that were disabled during OOM protection

echo "Restoring system services after Gentoo build..."

# Restore ananicy-cpp if it was running before
if ! systemctl is-active --quiet ananicy-cpp; then
    echo "Starting ananicy-cpp service..."
    sudo systemctl start ananicy-cpp
    echo "ananicy-cpp restored"
fi

# Restore other services
for service in oomd systemd-oomd; do
    if ! systemctl is-active --quiet "$service"; then
        echo "Starting $service service..."
        sudo systemctl start "$service"
        echo "$service restored"
    fi
done

echo "All services restored to normal operation."
echo "Your system is back to normal configuration."
