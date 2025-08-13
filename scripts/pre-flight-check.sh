#!/bin/bash
# Pre-flight System Check for RaptorOS
# Run this before starting a build to ensure system stability

echo "=== Pre-flight System Check ==="
echo ""

# Check RAM
total_ram=$(free -g | awk '/^Mem:/{print $2}')
if [ $total_ram -lt 16 ]; then
    echo "⚠️  WARNING: Only ${total_ram}GB RAM detected"
    echo "   Recommended: 16GB minimum, 32GB optimal"
else
    echo "✓ RAM: ${total_ram}GB (adequate)"
fi

# Check swap
total_swap=$(free -g | awk '/^Swap:/{print $2}')
if [ $total_swap -lt 8 ]; then
    echo "⚠️  WARNING: Only ${total_swap}GB swap detected"
    echo "   Recommended: At least 8GB swap"
else
    echo "✓ Swap: ${total_swap}GB (adequate)"
fi

# Check disk space
avail_space=$(df -BG /var/tmp | awk 'NR==2 {print int($4)}')
if [ $avail_space -lt 50 ]; then
    echo "⚠️  WARNING: Only ${avail_space}GB free in /var/tmp"
    echo "   Recommended: At least 50GB free space"
else
    echo "✓ Disk space: ${avail_space}GB free (adequate)"
fi

# Check if running on battery (laptops)
if [ -f /sys/class/power_supply/BAT0/status ]; then
    battery_status=$(cat /sys/class/power_supply/BAT0/status)
    if [ "$battery_status" != "Charging" ] && [ "$battery_status" != "Full" ]; then
        echo "⚠️  WARNING: Running on battery power!"
        echo "   Recommended: Connect to AC power for builds"
    else
        echo "✓ Power: AC power connected"
    fi
fi

# Check CPU load
cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
cpu_cores=$(nproc)
echo "✓ CPU: ${cpu_cores} cores, current load: ${cpu_load}"

# Check memory usage
mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
echo "✓ Memory: ${mem_usage}% used"

echo ""
echo "=== Resource Recommendations ==="
echo "For your system (${total_ram}GB RAM, ${cpu_cores} cores):"
echo "  Recommended JOBS: $((cpu_cores * 3 / 4))"
echo "  Recommended LOAD: $((cpu_cores - 2))"
echo "  Max safe RAM usage: $((total_ram * 80 / 100))GB"

echo ""
read -p "Continue with build? [y/N]: " continue
if [[ ! "$continue" =~ ^[Yy]$ ]]; then
    echo "Build cancelled. Please address warnings above."
    exit 1
fi

echo -e "\n\033[0;32mSystem ready for build!\033[0m"
echo "Remember to run OOM protection: sudo ./scripts/oom-protection.sh"
