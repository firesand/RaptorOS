#!/bin/bash
# RaptorOS Performance Benchmark Module

# Run comprehensive performance test
run_performance_benchmark() {
    dialog --backtitle "RaptorOS Installer" \
           --title "Performance Benchmark" \
           --yesno "Run performance benchmark?\n\n\
This will test:\n\
- CPU performance (stress-ng)\n\
- GPU performance (glmark2/vkmark)\n\
- Disk I/O (fio)\n\
- Memory bandwidth\n\n\
Results will be saved to /var/log/raptoros-benchmark.log" 14 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Install benchmark tools
    cat >> /mnt/gentoo/var/lib/portage/world << EOF
app-benchmarks/stress-ng
app-benchmarks/glmark2
app-benchmarks/vkmark
sys-block/fio
app-benchmarks/sysbench
sys-apps/memtest86+
EOF
    
    # Create benchmark script
    cat > /mnt/gentoo/usr/local/bin/raptoros-benchmark << 'BENCHSCRIPT'
#!/bin/bash
# RaptorOS System Benchmark

LOG="/var/log/raptoros-benchmark.log"
RESULTS="/home/$USER/raptoros-benchmark-$(date +%Y%m%d-%H%M%S).txt"

echo "RaptorOS Performance Benchmark" | tee "$RESULTS"
echo "==============================" | tee -a "$RESULTS"
echo "Date: $(date)" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# System Information
echo "=== System Information ===" | tee -a "$RESULTS"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)" | tee -a "$RESULTS"
echo "Cores: $(nproc)" | tee -a "$RESULTS"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')" | tee -a "$RESULTS"
echo "GPU: $(lspci | grep VGA | cut -d: -f3 | xargs)" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# CPU Benchmark
echo "=== CPU Benchmark ===" | tee -a "$RESULTS"
echo "Running stress-ng CPU test..." | tee -a "$RESULTS"
stress-ng --cpu $(nproc) --cpu-method matrixprod --metrics --timeout 60s 2>&1 | \
    grep "cpu:" | tee -a "$RESULTS"

# Single-threaded performance
echo "Single-threaded performance:" | tee -a "$RESULTS"
stress-ng --cpu 1 --cpu-method ackermann --metrics --timeout 10s 2>&1 | \
    grep "cpu:" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# Memory Benchmark
echo "=== Memory Benchmark ===" | tee -a "$RESULTS"
echo "Running memory bandwidth test..." | tee -a "$RESULTS"
sysbench memory --memory-total-size=10G run | grep -E "transferred|total time" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# Disk I/O Benchmark
echo "=== Disk I/O Benchmark ===" | tee -a "$RESULTS"
echo "Sequential read test:" | tee -a "$RESULTS"
fio --name=seq-read --ioengine=libaio --rw=read --bs=1M --size=1G \
    --numjobs=1 --runtime=60 --group_reporting --minimal 2>/dev/null | \
    awk -F';' '{print "Read: " $7/1024 " MB/s"}' | tee -a "$RESULTS"

echo "Sequential write test:" | tee -a "$RESULTS"
fio --name=seq-write --ioengine=libaio --rw=write --bs=1M --size=1G \
    --numjobs=1 --runtime=60 --group_reporting --minimal 2>/dev/null | \
    awk -F';' '{print "Write: " $48/1024 " MB/s"}' | tee -a "$RESULTS"

echo "Random 4K read IOPS:" | tee -a "$RESULTS"
fio --name=rand-read --ioengine=libaio --rw=randread --bs=4k --size=256M \
    --numjobs=4 --runtime=60 --group_reporting --minimal 2>/dev/null | \
    awk -F';' '{print "IOPS: " $8}' | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# GPU Benchmark (if available)
if command -v glmark2 &>/dev/null; then
    echo "=== GPU Benchmark (OpenGL) ===" | tee -a "$RESULTS"
    glmark2 2>&1 | grep "Score:" | tee -a "$RESULTS"
    echo "" | tee -a "$RESULTS"
fi

if command -v vkmark &>/dev/null; then
    echo "=== GPU Benchmark (Vulkan) ===" | tee -a "$RESULTS"
    vkmark 2>&1 | grep "Score:" | tee -a "$RESULTS"
    echo "" | tee -a "$RESULTS"
fi

# Gaming-specific tests
echo "=== Gaming Performance Indicators ===" | tee -a "$RESULTS"
echo "Kernel: $(uname -r)" | tee -a "$RESULTS"
echo "Scheduler: $(cat /sys/block/sda/queue/scheduler 2>/dev/null)" | tee -a "$RESULTS"
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)" | tee -a "$RESULTS"
echo "Swappiness: $(cat /proc/sys/vm/swappiness)" | tee -a "$RESULTS"

# Check for gaming optimizations
echo "" | tee -a "$RESULTS"
echo "Gaming Optimizations:" | tee -a "$RESULTS"
[ -f /usr/bin/gamemode ] && echo "✓ GameMode installed" | tee -a "$RESULTS"
[ -f /usr/bin/mangohud ] && echo "✓ MangoHud installed" | tee -a "$RESULTS"
[ -d /usr/share/vulkan ] && echo "✓ Vulkan support" | tee -a "$RESULTS"
lsmod | grep -q nvidia && echo "✓ NVIDIA driver loaded" | tee -a "$RESULTS"
lsmod | grep -q amdgpu && echo "✓ AMD GPU driver loaded" | tee -a "$RESULTS"

echo "" | tee -a "$RESULTS"
echo "Benchmark complete! Results saved to: $RESULTS"

# Performance rating
score_cpu=$(stress-ng --cpu 1 --cpu-method ackermann --metrics --timeout 10s 2>&1 | \
           grep "bogo ops/s" | awk '{print int($9)}')
score_mem=$(sysbench memory --memory-total-size=1G run 2>/dev/null | \
           grep "transferred" | grep -oE '[0-9]+\.[0-9]+' | head -1)

echo "" | tee -a "$RESULTS"
echo "=== RaptorOS Performance Rating ===" | tee -a "$RESULTS"

if [ "$score_cpu" -gt 10000 ]; then
    echo "CPU Performance: APEX PREDATOR 🦖" | tee -a "$RESULTS"
elif [ "$score_cpu" -gt 5000 ]; then
    echo "CPU Performance: HUNTING RAPTOR 🦅" | tee -a "$RESULTS"
else
    echo "CPU Performance: YOUNG HATCHLING 🥚" | tee -a "$RESULTS"
fi
BENCHSCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/raptoros-benchmark
    
    dialog --msgbox "Benchmark suite installed!\n\n\
Run 'raptoros-benchmark' after first boot\n\
to test system performance." 10 50
}

# Add to post-installation menu
# In post_installation_tweaks() function, add:
"benchmark" "Install performance benchmark suite" \

# And in the case statement:
"benchmark")
    run_performance_benchmark
    ;;
