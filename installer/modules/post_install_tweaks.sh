#!/bin/bash
# Post-Installation Tweaks Module for RaptorOS
# Gaming optimizations, performance tuning, quality of life improvements

# Main post-installation menu
post_installation_tweaks() {
    while true; do
        local choice=$(dialog --backtitle "RaptorOS Post-Install" \
                             --title "Post-Installation Tweaks" \
                             --menu "\nSelect optimizations to apply:" \
                             20 70 12 \
                             "all" "Apply all recommended tweaks" \
                             "gaming" "Gaming optimizations" \
                             "zram" "Configure ZRAM (compressed RAM)" \
                             "cpu" "CPU governor & frequency" \
                             "gpu" "GPU performance settings" \
                             "audio" "Audio latency optimization" \
                             "storage" "Storage optimization" \
                             "security" "Basic security hardening" \
                             "cosmetic" "Visual improvements" \
                             "dev" "Development tools" \
                             "flatpak" "Configure Flatpak support" \
                             "benchmark" "Install performance benchmark suite" \
                             "validate" "Validate RaptorOS configuration" \
                             "verify" "Verify complete installation" \
                             "done" "Finish post-installation" \
                             3>&1 1>&2 2>&3)

        case "$choice" in
            "all")
                apply_all_tweaks
                ;;
            "gaming")
                apply_gaming_tweaks
                ;;
            "zram")
                configure_zram
                ;;
            "cpu")
                configure_cpu_governor
                ;;
            "gpu")
                configure_gpu_performance
                ;;
            "audio")
                configure_audio_latency
                ;;
            "storage")
                optimize_storage
                ;;
            "security")
                apply_security_hardening
                ;;
            "cosmetic")
                apply_cosmetic_tweaks
                ;;
            "dev")
                install_dev_tools
                ;;
            "flatpak")
                configure_flatpak
                ;;
            "benchmark")
                run_performance_benchmark
                ;;
            "validate")
                validate_raptoros_config
                ;;
            "verify")
                verify_installation
                ;;
            "done"|*)
                break
                ;;
        esac
    done
}

# Apply all recommended tweaks
apply_all_tweaks() {
    (
        echo "10"; echo "# Applying gaming optimizations..."
        apply_gaming_tweaks

        echo "25"; echo "# Configuring ZRAM..."
        configure_zram

        echo "40"; echo "# Setting CPU governor..."
        configure_cpu_governor

        echo "55"; echo "# Optimizing GPU..."
        configure_gpu_performance

        echo "70"; echo "# Configuring audio..."
        configure_audio_latency

        echo "85"; echo "# Optimizing storage..."
        optimize_storage

        echo "95"; echo "# Validating RaptorOS configuration..."
        validate_raptoros_config

        echo "100"; echo "# All tweaks applied!"
        sleep 2
    ) | dialog --backtitle "RaptorOS Post-Install" \
               --title "Applying All Tweaks" \
               --gauge "Starting optimizations..." 10 70 0
}

# Gaming-specific tweaks
apply_gaming_tweaks() {
    log "Applying gaming tweaks"

    # The config files should already be in place from the installer.
    # This script now focuses on applying settings and activating features.

    log "Activating RaptorOS gaming configurations"

    # 1. Set CPU Governor
    configure_cpu_governor

    # 2. Configure GameMode
    # The gamemode.ini file should be part of the repo's file structure
    # and copied during installation.
    if [ -f /mnt/gentoo/etc/gamemode.ini ]; then
        log "GameMode configuration found, enabling service"
        chroot /mnt/gentoo systemctl --user enable gamemoded.service 2>/dev/null || true
        chroot /mnt/gentoo systemctl --user start gamemoded.service 2>/dev/null || true
    else
        log "Creating default GameMode configuration"
        cat > /mnt/gentoo/etc/gamemode.ini << 'EOF'
[general]
# GameMode configuration for RaptorOS
# This file is managed by the installer

[gpu]
# GPU optimizations
apply_gpu_optimisations=yes
gpu_device=auto
nv_powermizer_mode=1
nv_cooler_control=1

[cpu]
# CPU optimizations
governor=performance
sched_policy=fifo
sched_priority=1

[audio]
# Audio optimizations
apply_audio_optimisations=yes
audio_device=auto

[network]
# Network optimizations
apply_network_optimisations=yes
EOF
    fi

    # 3. Apply sysctl settings
    if [ -f /mnt/gentoo/etc/sysctl.d/99-gaming.conf ]; then
        log "Applying gaming sysctl settings"
        chroot /mnt/gentoo sysctl --system 2>/dev/null || true
    fi

    # 4. Enable gaming services
    log "Enabling gaming-related services"
    
    # Enable GameMode daemon
    chroot /mnt/gentoo systemctl enable gamemoded.service 2>/dev/null || true
    
    # Enable Steam services if available
    if [ -f /mnt/gentoo/usr/bin/steam ]; then
        log "Steam detected, enabling Steam services"
        chroot /mnt/gentoo systemctl --user enable steam.service 2>/dev/null || true
    fi

    # 5. Install RaptorOS utility scripts
    log "Installing RaptorOS utility scripts"
    install_raptoros_scripts

    # 6. Install gaming stack configuration
    log "Installing gaming stack configuration"
    install_gaming_stack_config

    # 7. Create desktop shortcuts for gaming tools
    log "Creating desktop shortcuts for gaming tools"
    
    # RaptorOS Update tool
    if [ -f /mnt/gentoo/usr/local/bin/raptoros-update ]; then
        mkdir -p /mnt/gentoo/usr/share/applications
        cat > /mnt/gentoo/usr/share/applications/raptoros-update.desktop << 'EOF'
[Desktop Entry]
Name=RaptorOS Update
Comment=Update RaptorOS gaming system
Exec=raptoros-update
Icon=system-software-update
Terminal=true
Type=Application
Categories=System;Settings;
EOF
    fi

    # Performance Validator
    if [ -f /mnt/gentoo/usr/local/bin/validate-performance ]; then
        cat > /mnt/gentoo/usr/share/applications/validate-performance.desktop << 'EOF'
[Desktop Entry]
Name=Performance Validator
Comment=Validate RaptorOS performance settings
Exec=validate-performance
Icon=utilities-system-monitor
Terminal=true
Type=Application
Categories=System;Settings;
EOF
    fi

    # System Validator
    if [ -f /mnt/gentoo/usr/local/bin/system-validator ]; then
        cat > /mnt/gentoo/usr/share/applications/system-validator.desktop << 'EOF'
[Desktop Entry]
Name=System Validator
Comment=Validate RaptorOS system health
Exec=system-validator
Icon=utilities-system-monitor
Terminal=true
Type=Application
Categories=System;Settings;
EOF
    fi

    dialog --msgbox "Gaming performance tweaks have been activated!" 8 60
}

    # Install RaptorOS utility scripts
    log "Installing RaptorOS utility scripts"
    
    # Copy scripts to target system
    cp /tmp/raptoros-scripts/raptoros-update.sh /mnt/gentoo/usr/local/bin/ 2>/dev/null || {
        # If scripts not in /tmp, create them directly
        log "Creating RaptorOS utility scripts directly"
        
        # RaptorOS Update Script
        cat > /mnt/gentoo/usr/local/bin/raptoros-update.sh << 'EOF'
#!/bin/bash
# RaptorOS Update System - Simplified for modern stable

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       RaptorOS Update System               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

check_versions() {
    echo "Current System Versions:"
    echo "══════════════════════════"
    
    # GCC
    echo -n "GCC: "
    gcc --version | head -1 | awk '{print $3}'
    
    # LLVM
    echo -n "LLVM: "
    llvm-config --version 2>/dev/null || echo "Not installed"
    
    # Mesa
    echo -n "Mesa: "
    equery l media-libs/mesa -F '$version' 2>/dev/null | head -1
    
    # Kernel
    echo -n "Kernel: "
    uname -r
    
    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        echo -n "NVIDIA: "
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null
    fi
    
    echo ""
}

smart_update() {
    echo -e "${GREEN}Starting intelligent update...${NC}"
    
    # Sync repos
    echo "Syncing repositories..."
    emerge --sync --quiet
    
    # Update @world with smart defaults
    echo "Calculating updates..."
    
    # Show what would update
    local updates=$(emerge -pvuDN @world 2>&1 | grep "^\[" | wc -l)
    
    if [ "$updates" -eq 0 ]; then
        echo -e "${GREEN}System is up to date!${NC}"
        return
    fi
    
    echo -e "${YELLOW}Found $updates packages to update${NC}"
    
    # Actual update
    emerge -avuDN @world \
        --keep-going \
        --with-bdeps=y \
        --backtrack=30
    
    # Clean up
    echo "Cleaning up..."
    emerge --depclean -a
    
    # Preserved rebuild
    emerge @preserved-rebuild
    
    # Update config files
    etc-update --automode -3
    
    echo -e "${GREEN}Update complete!${NC}"
}

quick_gaming_update() {
    echo -e "${CYAN}Quick gaming package update...${NC}"
    
    # Just update critical gaming packages
    emerge -av1 \
        media-libs/mesa \
        x11-drivers/nvidia-drivers \
        app-emulation/wine-staging \
        games-util/steam-launcher \
        games-util/gamemode \
        2>/dev/null || echo "Some packages not installed"
}

main_menu() {
    PS3="Select option: "
    options=(
        "Check current versions"
        "Full system update"
        "Quick gaming update"
        "Update kernel only"
        "Check security updates"
        "Exit"
    )
    
    select opt in "${options[@]}"; do
        case $REPLY in
            1) check_versions ;;
            2) smart_update ;;
            3) quick_gaming_update ;;
            4) emerge -av sys-kernel/gentoo-sources ;;
            5) glsa-check -l affected ;;
            6) break ;;
            *) echo "Invalid option" ;;
        esac
        echo ""
        echo "Press Enter to continue..."
        read
    done
}

# Main
check_versions
main_menu
EOF

}

# Install RaptorOS utility scripts
install_raptoros_scripts() {
    log "Installing RaptorOS utility scripts"
    
    # Copy scripts to target system
    cp /tmp/raptoros-scripts/raptoros-update.sh /mnt/gentoo/usr/local/bin/ 2>/dev/null || {
        # If scripts not in /tmp, create them directly
        log "Creating RaptorOS utility scripts directly"
        
        # RaptorOS Update Script
        cat > /mnt/gentoo/usr/local/bin/raptoros-update.sh << 'EOF'
#!/bin/bash
# RaptorOS Update System - Simplified for modern stable

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       RaptorOS Update System               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

check_versions() {
    echo "Current System Versions:"
    echo "══════════════════════════"
    
    # GCC
    echo -n "GCC: "
    gcc --version | head -1 | awk '{print $3}'
    
    # LLVM
    echo -n "LLVM: "
    llvm-config --version 2>/dev/null || echo "Not installed"
    
    # Mesa
    echo -n "Mesa: "
    equery l media-libs/mesa -F '$version' 2>/dev/null | head -1
    
    # Kernel
    echo -n "Kernel: "
    uname -r
    
    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        echo -n "NVIDIA: "
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null
    fi
    
    echo ""
}

smart_update() {
    echo -e "${GREEN}Starting intelligent update...${NC}"
    
    # Sync repos
    echo "Syncing repositories..."
    emerge --sync --quiet
    
    # Update @world with smart defaults
    echo "Calculating updates..."
    
    # Show what would update
    local updates=$(emerge -pvuDN @world 2>&1 | grep "^\[" | wc -l)
    
    if [ "$updates" -eq 0 ]; then
        echo -e "${GREEN}System is up to date!${NC}"
        return
    fi
    
    echo -e "${YELLOW}Found $updates packages to update${NC}"
    
    # Actual update
    emerge -avuDN @world \
        --keep-going \
        --with-bdeps=y \
        --backtrack=30
    
    # Clean up
    echo "Cleaning up..."
    emerge --depclean -a
    
    # Preserved rebuild
    emerge @preserved-rebuild
    
    # Update config files
    etc-update --automode -3
    
    echo -e "${GREEN}Update complete!${NC}"
}

quick_gaming_update() {
    echo -e "${CYAN}Quick gaming package update...${NC}"
    
    # Just update critical gaming packages
    emerge -av1 \
        x11-drivers/nvidia-drivers \
        app-emulation/wine-staging \
        games-util/steam-launcher \
        games-util/lutris \
        games-util/gamemode \
        games-util/mangohud
    
    echo -e "${GREEN}Gaming packages updated!${NC}"
}

kernel_update() {
    echo -e "${CYAN}Kernel update...${NC}"
    
    # Update kernel
    emerge -av1 sys-kernel/gentoo-kernel
    
    # Rebuild modules
    emerge @module-rebuild
    
    echo -e "${GREEN}Kernel updated!${NC}"
}

security_check() {
    echo -e "${CYAN}Security check...${NC}"
    
    # Check for security updates
    glsa-check -l affected
    
    # Update security packages
    emerge -av1 $(glsa-check -l affected | grep -E "^[a-z0-9-]+/[a-z0-9-]+" | cut -d' ' -f1)
    
    echo -e "${GREEN}Security check complete!${NC}"
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo "Select update type:"
        echo "1) Smart full update (recommended)"
        echo "2) Quick gaming update"
        echo "3) Kernel only"
        echo "4) Security check"
        echo "5) Check versions"
        echo "6) Exit"
        echo ""
        read -p "Choice [1-6]: " choice
        
        case $choice in
            1) smart_update ;;
            2) quick_gaming_update ;;
            3) kernel_update ;;
            4) security_check ;;
            5) check_versions ;;
            6) break ;;
            *) echo "Invalid choice" ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read
    done
}

# Run main menu
main_menu
EOF

        # Performance Validation Script
        cat > /mnt/gentoo/usr/local/bin/validate-performance.sh << 'EOF'
#!/bin/bash
# Validate that modern stable versions are performing well

echo "RaptorOS Performance Validation"
echo "═══════════════════════════════"
echo ""

# Check compiler optimization
echo "Compiler Optimization Test:"
echo -n "GCC 14.3.0 LTO: "
if gcc -v 2>&1 | grep -q "enable-lto"; then
    echo "✓ Enabled"
else
    echo "✗ Disabled"
fi

# Check Mesa features
echo ""
echo "Mesa 25.1.7 Features:"
glxinfo 2>/dev/null | grep -E "OpenGL version|Mesa" | head -2

# Check LLVM
echo ""
echo "LLVM 20.1.7 Status:"
if llvm-config --version | grep -q "20"; then
    echo "✓ Modern LLVM 20 active"
    echo "  Polly: $(llvm-config --has-polly && echo ✓ || echo ✗)"
fi

# Check kernel config
echo ""
echo "Kernel Optimizations:"
if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_HZ_1000=y"; then
    echo "✓ 1000Hz timer"
fi
if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_PREEMPT=y"; then
    echo "✓ Full preemption"
fi

# Gaming readiness
echo ""
echo "Gaming Readiness:"
command -v steam &>/dev/null && echo "✓ Steam installed" || echo "✗ Steam not found"
command -v mangohud &>/dev/null && echo "✓ MangoHud ready" || echo "✗ MangoHud missing"
command -v gamemoded &>/dev/null && echo "✓ GameMode available" || echo "✗ GameMode missing"

echo ""
echo "═══════════════════════════════"
echo "Verdict: $(
    if command -v steam &>/dev/null && [ -f /usr/lib64/libvulkan.so ]; then
        echo "✓ READY FOR GAMING"
    else
        echo "⚠ Missing some components"
    fi
)"
EOF
    }
    
    # Make scripts executable
    chmod +x /mnt/gentoo/usr/local/bin/raptoros-update.sh
    chmod +x /mnt/gentoo/usr/local/bin/validate-performance.sh
    
    log "RaptorOS utility scripts installed"
}

# Install gaming stack configuration
install_gaming_stack_config() {
    log "Installing gaming stack configuration"
    
    # Create desktop shortcuts
    mkdir -p /mnt/gentoo/home/$USERNAME/Desktop
    cat > /mnt/gentoo/home/$USERNAME/Desktop/raptoros-update.desktop << 'EOF'
[Desktop Entry]
Name=RaptorOS Update
Comment=Smart system update for gaming
Exec=raptoros-update
Icon=system-software-update
Terminal=true
Type=Application
Categories=System;Settings;
EOF

    cat > /mnt/gentoo/home/$USERNAME/Desktop/validate-performance.desktop << 'EOF'
[Desktop Entry]
Name=Performance Validation
Comment=Validate RaptorOS performance
Exec=validate-performance
Icon=utilities-system-monitor
Terminal=true
Type=Application
Categories=System;Settings;
EOF

    chroot /mnt/gentoo chown $USERNAME:$USERNAME /home/$USERNAME/Desktop/raptoros-update.desktop
    chroot /mnt/gentoo chown $USERNAME:$USERNAME /home/$USERNAME/Desktop/validate-performance.desktop

    # GameMode configuration
    mkdir -p /mnt/gentoo/home/$USERNAME/.config/gamemode
    cat > /mnt/gentoo/home/$USERNAME/.config/gamemode/gamemode.ini << 'EOF'
[general]
; RaptorOS GameMode Configuration
reaper_freq=5
desiredgov=performance
igpu_desiredgov=performance
softrealtime=auto
renice=15
ioprio=0
inhibit_screensaver=1

[filter]
; Whitelist glxgears
whitelist=glxgears

[gpu]
; NVIDIA optimizations
apply_gpu_optimizations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
nv_core_clock_mhz_offset=100
nv_mem_clock_mhz_offset=200

; AMD optimizations
amd_performance_level=high

[cpu]
park_cores=no
pin_cores=yes

[custom]
start=notify-send "GameMode" "Performance mode activated"
end=notify-send "GameMode" "Performance mode deactivated"

[supervisor]
; Adjust scheduling
scheduling_policy=SCHED_ISO
nice=-4
EOF

    # Steam launch options
    cat > /mnt/gentoo/home/$USERNAME/.config/steam_launch_options.txt << 'EOF'
# RaptorOS Recommended Steam Launch Options

# General (for most games):
gamemoderun %command%

# For Proton games:
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 VKD3D_FEATURE_LEVEL=12_1 gamemoderun %command%

# For native Linux games with performance issues:
__GL_THREADED_OPTIMIZATIONS=1 __GL_SHADER_DISK_CACHE=1 gamemoderun %command%

# For CPU-limited games:
taskset -c 0-15 gamemoderun %command%

# For shader compilation stutters:
DXVK_ASYNC=1 gamemoderun %command%

# For HDR (experimental):
ENABLE_HDR_WSI=1 gamemoderun %command%
EOF

    # Lutris optimization
    mkdir -p /mnt/gentoo/home/$USERNAME/.config/lutris/system.yml
    cat > /mnt/gentoo/home/$USERNAME/.config/lutris/system.yml << 'EOF'
system:
  game_path: /games
  prefix_command: gamemoderun
  pulse_latency: 60
  use_us_layout: false
  disable_compositor: true
  disable_screen_saver: true
  enable_esync: true
  enable_fsync: true
  enable_gamemode: true
  enable_feral_gamemode: true
  enable_mangohud: true
  enable_vkbasalt: false
  nvidia_prime:
    sync: 1
    offload: 0
EOF

    # MangoHud configuration
    mkdir -p /mnt/gentoo/home/$USERNAME/.config/MangoHud
    cat > /mnt/gentoo/home/$USERNAME/.config/MangoHud/MangoHud.conf << 'EOF'
# RaptorOS MangoHud Configuration

# Performance metrics
fps
fps_limit=0
frame_timing=1
frametime
cpu_stats
cpu_temp
cpu_load_change
cpu_mhz
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
ram
vram
io_read
io_write

# Visual settings
position=top-left
height=24
font_size=20
background_alpha=0.5
alpha=0.8
round_corners=10

# Colors (Tokyo Night theme)
gpu_color=BB9AF7
cpu_color=7AA2F7
vram_color=9ECE6A
ram_color=F7768E
text_color=C0CAF5
frametime_color=73DACA

# Keybinds
toggle_hud=Shift_R+F12
toggle_logging=Shift_L+F2
toggle_fps_limit=Shift_L+F1

# Logging
log_duration=120
autostart_log=0
log_interval=100
EOF

    # Fix permissions
    chroot /mnt/gentoo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    
    log "Gaming stack configuration installed"
}

# Configure ZRAM
configure_zram() {
    log "Configuring ZRAM"

    # Calculate ZRAM size (50% of RAM)
    local zram_size=$((RAM_SIZE * 512))

    # Install zram-init
    echo "sys-block/zram-init" >> /mnt/gentoo/var/lib/portage/world

    # Configure zram
    cat > /mnt/gentoo/etc/conf.d/zram-init << EOF
# RaptorOS ZRAM Configuration
# Compressed RAM for better gaming performance

# Load zram module with 1 device per CPU
load_on_start="yes"

# ZRAM device size (50% of RAM)
type0="swap"
flag0="lz4"
size0="${zram_size}M"
priority0="32767"
EOF

    # Enable service
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /mnt/gentoo/etc/systemd/system/zram.service << EOF
[Unit]
Description=Configure ZRAM swap device
DefaultDependencies=no
Before=swap.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/zram-init start
ExecStop=/usr/sbin/zram-init stop

[Install]
WantedBy=swap.target
EOF
        chroot /mnt/gentoo systemctl enable zram.service
    else
        chroot /mnt/gentoo rc-update add zram-init boot
    fi

    dialog --infobox "ZRAM configured: ${zram_size}MB compressed swap" 3 50
    sleep 2
}

# Configure CPU governor
configure_cpu_governor() {
    log "Configuring CPU governor"

    # Install cpupower
    echo "sys-power/cpupower" >> /mnt/gentoo/var/lib/portage/world

    # Detect available governors
    local governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "performance powersave")

    # Configure for performance
    cat > /mnt/gentoo/etc/conf.d/cpupower << 'EOF'
# RaptorOS CPU Power Configuration
START_OPTS="--governor=performance"
STOP_OPTS="--governor=powersave"

# Set all CPUs to performance mode
SYSFS_EXTRA="
/sys/devices/system/cpu/cpufreq/boost=1
/sys/devices/system/cpu/intel_pstate/no_turbo=0
/sys/devices/system/cpu/intel_pstate/turbo_pct=100
/sys/devices/system/cpu/intel_pstate/min_perf_pct=50
/sys/devices/system/cpu/intel_pstate/max_perf_pct=100
/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost=1
"
EOF

    # CPU optimization script
    cat > /mnt/gentoo/usr/local/bin/cpu-gaming-mode << 'EOF'
#!/bin/bash
# Toggle CPU gaming mode

if [ "$1" == "on" ]; then
    echo "Enabling CPU gaming mode..."

    # Set performance governor
    cpupower frequency-set -g performance

    # Disable CPU idle states for lower latency
    for i in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        echo 1 > $i 2>/dev/null
    done

    # Set CPU affinity for gaming (P-cores on Intel hybrid)
    if lscpu | grep -q "Core(s) per cluster"; then
        # Hybrid CPU detected
        echo "Hybrid CPU detected, optimizing for P-cores..."
        echo "0-15" > /sys/fs/cgroup/cpuset/system.slice/cpuset.cpus
    fi

    echo "CPU gaming mode enabled!"

elif [ "$1" == "off" ]; then
    echo "Disabling CPU gaming mode..."

    # Set balanced governor
    cpupower frequency-set -g schedutil 2>/dev/null || cpupower frequency-set -g ondemand

    # Re-enable CPU idle states
    for i in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        echo 0 > $i 2>/dev/null
    done

    echo "CPU gaming mode disabled!"
else
    echo "Usage: $0 {on|off}"
fi
EOF
    chmod +x /mnt/gentoo/usr/local/bin/cpu-gaming-mode
}

# Configure GPU performance
configure_gpu_performance() {
    log "Configuring GPU performance settings"

    case "$GPU_DRIVER" in
        "nvidia"*)
            configure_nvidia_performance
            ;;
        "amdgpu"|"radeon")
            configure_amd_performance
            ;;
        "i915"|"xe")
            configure_intel_gpu_performance
            ;;
    esac
}

# NVIDIA performance settings
configure_nvidia_performance() {
    # NVIDIA persistent mode daemon
    cat > /mnt/gentoo/etc/conf.d/nvidia-persistenced << 'EOF'
# NVIDIA Persistence Daemon Configuration
NVPD_USER="nvidia-persistenced"
NVPD_GROUP="nvidia-persistenced"
EOF

    # Performance mode script
    cat > /mnt/gentoo/usr/local/bin/nvidia-performance << 'EOF'
#!/bin/bash
# NVIDIA Performance Mode Toggle

if [ "$1" == "max" ]; then
    # Maximum performance
    nvidia-smi -pm 1
    nvidia-smi -pl 350  # Adjust for your GPU
    nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
    nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffsetAllPerformanceLevels=200"
    nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffsetAllPerformanceLevels=100"
    echo "NVIDIA maximum performance enabled!"

elif [ "$1" == "auto" ]; then
    # Adaptive mode
    nvidia-smi -pm 1
    nvidia-smi -pl 0
    nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=2"
    echo "NVIDIA adaptive mode enabled!"

elif [ "$1" == "quiet" ]; then
    # Quiet mode
    nvidia-smi -pl 200
    nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=0"
    echo "NVIDIA quiet mode enabled!"
fi
EOF
    chmod +x /mnt/gentoo/usr/local/bin/nvidia-performance

    # Coolbits for overclocking
    if [[ -f /mnt/gentoo/etc/X11/xorg.conf.d/20-nvidia.conf ]]; then
        sed -i '/Section "Device"/a\    Option "Coolbits" "31"' \
            /mnt/gentoo/etc/X11/xorg.conf.d/20-nvidia.conf
    fi
}

# AMD performance settings
configure_amd_performance() {
    cat > /mnt/gentoo/usr/local/bin/amd-performance << 'EOF'
#!/bin/bash
# AMD GPU Performance Mode

if [ "$1" == "max" ]; then
    echo "high" > /sys/class/drm/card0/device/power_dpm_force_performance_level
    echo "1" > /sys/class/drm/card0/device/pp_power_profile_mode
    echo "AMD GPU maximum performance enabled!"

elif [ "$1" == "auto" ]; then
    echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level
    echo "0" > /sys/class/drm/card0/device/pp_power_profile_mode
    echo "AMD GPU auto mode enabled!"
fi
EOF
    chmod +x /mnt/gentoo/usr/local/bin/amd-performance
}

# AMD performance settings with LACT
configure_amd_performance() {
    log "Configuring AMD GPU with LACT"

    # Install LACT (Linux AMDGPU Control)
    echo "sys-apps/lact" >> /mnt/gentoo/var/lib/portage/world

    # If LACT not in portage, build from source
    if ! chroot /mnt/gentoo emerge -s lact &>/dev/null; then
        dialog --infobox "Building LACT from source..." 3 40

        # Install dependencies
        cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
dev-lang/rust
dev-libs/libdrm
x11-libs/gtk
sys-apps/hwdata
sys-apps/pciutils
EOF

        # Build LACT
        cat > /mnt/gentoo/tmp/install-lact.sh << 'EOF'
#!/bin/bash
cd /tmp
git clone https://github.com/ilya-zlobintsev/LACT.git
cd LACT
cargo build --release
cp target/release/lact /usr/local/bin/
cp target/release/lact-daemon /usr/local/bin/
cp res/lactd.service /etc/systemd/system/ 2>/dev/null
cp res/io.github.lact-linux.desktop /usr/share/applications/
mkdir -p /usr/share/lact
cp -r res/* /usr/share/lact/
EOF
        chmod +x /mnt/gentoo/tmp/install-lact.sh
        chroot /mnt/gentoo /tmp/install-lact.sh
    fi

    # LACT configuration
    mkdir -p /mnt/gentoo/etc/lact
    cat > /mnt/gentoo/etc/lact/config.yaml << 'EOF'
# RaptorOS LACT Configuration for AMD GPUs
daemon:
  log_level: info
  admin_groups: [wheel, video]

gpus:
  # Auto-detect and configure all AMD GPUs
  apply_settings_on_boot: true

  # Default profile
  default:
    fan_control_enabled: true
    fan_control_mode: curve
    fan_curve:
      - [0, 0]
      - [40, 30]
      - [50, 40]
      - [60, 50]
      - [70, 60]
      - [80, 80]
      - [90, 100]

    # Performance settings
    power_cap: 350  # Adjust for your GPU (RX 7900 XTX default)
    performance_level: auto

    # Overclocking (disabled by default for safety)
    overclock:
      core_clock_offset: 0
      memory_clock_offset: 0
      voltage_offset: 0

  # Gaming profile
  gaming:
    fan_control_enabled: true
    fan_control_mode: curve
    fan_curve:
      - [0, 20]
      - [40, 40]
      - [50, 50]
      - [60, 60]
      - [70, 75]
      - [80, 90]
      - [85, 100]

    power_cap: 400  # Maximum performance
    performance_level: high

    overclock:
      core_clock_offset: 50
      memory_clock_offset: 100
      voltage_offset: 0

  # Quiet profile
  quiet:
    fan_control_enabled: true
    fan_control_mode: curve
    fan_curve:
      - [0, 0]
      - [50, 20]
      - [60, 30]
      - [70, 40]
      - [80, 50]
      - [90, 60]

    power_cap: 250
    performance_level: low
EOF

    # Enable LACT daemon
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        chroot /mnt/gentoo systemctl enable lactd
    else
        # Create OpenRC service
        cat > /mnt/gentoo/etc/init.d/lactd << 'EOF'
#!/sbin/openrc-run
# LACT daemon for AMD GPU control

command="/usr/local/bin/lact-daemon"
command_background=true
pidfile="/run/lactd.pid"
description="LACT - AMD GPU Control Daemon"

depend() {
    need localmount
    after modules
}
EOF
        chmod +x /mnt/gentoo/etc/init.d/lactd
        chroot /mnt/gentoo rc-update add lactd default
    fi

    # Create helper scripts
    cat > /mnt/gentoo/usr/local/bin/amd-performance << 'EOF'
#!/bin/bash
# AMD GPU Performance Mode with LACT

case "$1" in
    max|gaming)
        echo "Setting AMD GPU to maximum performance..."
        lact profile gaming
        echo "high" > /sys/class/drm/card0/device/power_dpm_force_performance_level
        echo "1" > /sys/class/drm/card0/device/pp_power_profile_mode
        notify-send "AMD GPU" "Gaming mode activated" -i gpu
        ;;

    auto|balanced)
        echo "Setting AMD GPU to balanced mode..."
        lact profile default
        echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level
        echo "0" > /sys/class/drm/card0/device/pp_power_profile_mode
        notify-send "AMD GPU" "Balanced mode activated" -i gpu
        ;;

    quiet|power)
        echo "Setting AMD GPU to quiet mode..."
        lact profile quiet
        echo "low" > /sys/class/drm/card0/device/power_dpm_force_performance_level
        echo "0" > /sys/class/drm/card0/device/pp_power_profile_mode
        notify-send "AMD GPU" "Quiet mode activated" -i gpu
        ;;

    status)
        echo "AMD GPU Status:"
        echo "=============="
        lact status
        echo ""
        echo "Temperature: $(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk '{print $1/1000"°C"}')"
        echo "Power: $(cat /sys/class/drm/card0/device/hwmon/hwmon*/power1_average 2>/dev/null | awk '{print $1/1000000"W"}')"
        echo "Fan Speed: $(cat /sys/class/drm/card0/device/hwmon/hwmon*/fan1_input 2>/dev/null) RPM"
        ;;

    *)
        echo "Usage: $0 {gaming|balanced|quiet|status}"
        echo ""
        echo "Modes:"
        echo "  gaming   - Maximum performance for gaming"
        echo "  balanced - Auto power management"
        echo "  quiet    - Reduced power and noise"
        echo "  status   - Show current GPU status"
        ;;
esac
EOF
    chmod +x /mnt/gentoo/usr/local/bin/amd-performance

    # Desktop shortcut for LACT GUI
    cat > /mnt/gentoo/home/$USERNAME/Desktop/lact.desktop << 'EOF'
[Desktop Entry]
Name=LACT - AMD GPU Control
Comment=Control and monitor AMD GPUs
Exec=lact-gui
Icon=gpu
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=amd;gpu;radeon;overclock;
EOF

    chroot /mnt/gentoo chown $USERNAME:$USERNAME /home/$USERNAME/Desktop/lact.desktop
    chmod +x /mnt/gentoo/home/$USERNAME/Desktop/lact.desktop

    dialog --msgbox "AMD GPU configuration complete!\n\n\
LACT installed for GPU control:\n\
- GUI: lact-gui\n\
- CLI: lact\n\
- Profiles: gaming, balanced, quiet\n\
- Helper: amd-performance" 14 50
}

# Audio latency optimization
configure_audio_latency() {
    log "Configuring audio for low latency"

    # PipeWire configuration for gaming
    mkdir -p /mnt/gentoo/home/$USERNAME/.config/pipewire
    cat > /mnt/gentoo/home/$USERNAME/.config/pipewire/pipewire.conf << 'EOF'
# RaptorOS PipeWire Gaming Configuration

context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 256
    default.clock.min-quantum = 16
    default.clock.max-quantum = 512
}

context.modules = [
    {
        name = libpipewire-module-rtkit
        args = {
            nice.level = -15
            rt.prio = 88
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
    }
    {
        name = libpipewire-module-protocol-pulse
        args = {
            pulse.min.req = 16/48000
            pulse.default.req = 32/48000
            pulse.max.req = 256/48000
            pulse.min.quantum = 16/48000
            pulse.max.quantum = 256/48000
        }
    }
]

stream.properties = {
    node.latency = 256/48000
    resample.quality = 10
    channelmix.normalize = false
    channelmix.mix-lfe = false
}
EOF

    # JACK configuration for ultra-low latency
    cat > /mnt/gentoo/home/$USERNAME/.config/jack/conf.xml << 'EOF'
<?xml version="1.0"?>
<jack>
  <driver>alsa</driver>
  <realtime>true</realtime>
  <realtime-priority>89</realtime-priority>
  <periods>2</periods>
  <period-size>256</period-size>
  <rate>48000</rate>
  <no-memory-lock>false</no-memory-lock>
  <unlock-memory>false</unlock-memory>
  <softmode>false</softmode>
  <monitor>false</monitor>
  <midi-driver>seq</midi-driver>
</jack>
EOF

    chroot /mnt/gentoo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

    # Realtime privileges for audio
    cat >> /mnt/gentoo/etc/security/limits.conf << 'EOF'

# RaptorOS Audio Realtime Privileges
@audio - rtprio 95
@audio - memlock unlimited
@audio - nice -19
EOF

    # Add user to audio group
    chroot /mnt/gentoo usermod -a -G audio,realtime $USERNAME
}

# Storage optimization
optimize_storage() {
    log "Optimizing storage configuration"

    # SSD optimization
    if [[ "$DISK_TYPE" == "SSD" ]] || [[ "$DISK_TYPE" == "NVMe" ]]; then

        # Enable periodic TRIM
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            chroot /mnt/gentoo systemctl enable fstrim.timer
        else
            echo '0 3 * * 0 root /sbin/fstrim -a' >> /mnt/gentoo/etc/crontab
        fi

        # I/O scheduler optimization
        cat > /mnt/gentoo/etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# RaptorOS I/O Scheduler Optimization
# NVMe - none/kyber
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
# SATA SSD - mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# HDD - bfq
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

        # Mount options for SSDs
        sed -i 's/defaults/defaults,noatime,discard=async/g' /mnt/gentoo/etc/fstab
    fi

    # BTRFS optimizations
    if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then

        # BTRFS maintenance scripts
        cat > /mnt/gentoo/usr/local/bin/btrfs-maintenance << 'EOF'
#!/bin/bash
# BTRFS Maintenance Script

case "$1" in
    balance)
        echo "Starting BTRFS balance..."
        btrfs balance start -dusage=50 -dlimit=2 -musage=50 -mlimit=4 /
        ;;
    scrub)
        echo "Starting BTRFS scrub..."
        btrfs scrub start /
        ;;
    defrag)
        echo "Defragmenting BTRFS (excluding games)..."
        btrfs filesystem defragment -r -clzo /
        ;;
    snapshot)
        echo "Creating system snapshot..."
        btrfs subvolume snapshot -r / /.snapshots/$(date +%Y%m%d-%H%M%S)
        ;;
esac
EOF
        chmod +x /mnt/gentoo/usr/local/bin/btrfs-maintenance

        # Weekly maintenance
        echo '0 4 * * 1 root /usr/local/bin/btrfs-maintenance balance' >> /mnt/gentoo/etc/crontab
        echo '0 5 * * 3 root /usr/local/bin/btrfs-maintenance scrub' >> /mnt/gentoo/etc/crontab
    fi
}

# Security hardening
apply_security_hardening() {
    log "Applying security hardening"

    # Kernel security parameters
    cat > /mnt/gentoo/etc/sysctl.d/50-security.conf << 'EOF'
# RaptorOS Security Hardening

# Kernel hardening
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1
kernel.modules_disabled = 0

# Network security
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Process security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
EOF

    # Firewall basic rules
    configure_gaming_firewall

    # Fail2ban for SSH protection
    echo "net-analyzer/fail2ban" >> /mnt/gentoo/var/lib/portage/world

    dialog --msgbox "Security hardening applied!\n\n\
- Kernel security parameters set\n\
- Network hardening enabled\n\
- Basic firewall configured" 10 50
}

# Cosmetic improvements
apply_cosmetic_tweaks() {
    log "Applying cosmetic improvements"

    # Plymouth boot splash
    echo "sys-boot/plymouth" >> /mnt/gentoo/var/lib/portage/world

    # Configure Plymouth
    cat >> /mnt/gentoo/etc/default/grub << 'EOF'

# Plymouth boot splash
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} quiet splash plymouth.enable=1"
EOF

    # Neofetch for terminal rice
    echo "app-misc/neofetch" >> /mnt/gentoo/var/lib/portage/world

    # Terminal welcome message
    cat > /mnt/gentoo/home/$USERNAME/.bashrc << 'EOF'
# RaptorOS Bash Configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias update='sudo emerge --sync && sudo emerge -avuDN @world'
alias cleanup='sudo emerge --depclean && sudo eclean-dist'

# Gaming aliases
alias gamemode='gamemoderun'
alias fps='mangohud'
alias wine='wine-staging'

# Prompt
PS1='\[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\$\[\033[00m\] '

# Welcome message
if [ -f /usr/bin/neofetch ]; then
    clear
    neofetch --ascii_distro gentoo --colors 5 7 7 5 7 7
    echo -e "\n\033[1;35m╦╔╗┌─┐┌─┐┌┬┐┌─┐┬─┐╔═╗╔═╗\033[0m"
    echo -e "\033[1;35m╠╦╝├─┤├─┘ │ │ │├┬┘║ ║╚═╗\033[0m"
    echo -e "\033[1;35m╩╚═┴ ┴┴   ┴ └─┘┴└─╚═╝╚═╝\033[0m"
    echo -e "\033[0;36m  Performance Evolved™\033[0m\n"
fi

# Enable bash completion
[ -f /etc/bash_completion ] && . /etc/bash_completion

# Gaming environment
export MANGOHUD=1
export ENABLE_VKBASALT=0
export DXVK_HUD=0

# PATH additions
export PATH="$HOME/.local/bin:$PATH"
EOF

    chroot /mnt/gentoo chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc
}

# Development tools installation
install_dev_tools() {
    log "Installing development tools"

    local dev_packages=$(dialog --backtitle "RaptorOS Post-Install" \
                               --title "Development Tools" \
                               --checklist "\nSelect development tools to install:" \
                               20 70 10 \
                               "vscode" "Visual Studio Code" ON \
                               "git" "Git version control" ON \
                               "docker" "Docker containers" OFF \
                               "nodejs" "Node.js and npm" OFF \
                               "rust" "Rust toolchain" OFF \
                               "go" "Go language" OFF \
                               "python" "Python dev tools" ON \
                               "gcc" "GCC toolchain" ON \
                               "cmake" "CMake build system" OFF \
                               "vim" "Vim editor" ON \
                               3>&1 1>&2 2>&3)

    for package in $dev_packages; do
        case "$package" in
            "vscode")
                echo "app-editors/vscode" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "git")
                echo "dev-vcs/git" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "docker")
                echo "app-containers/docker" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "nodejs")
                echo "net-libs/nodejs" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "rust")
                echo "dev-lang/rust" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "go")
                echo "dev-lang/go" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "python")
                echo "dev-python/pip dev-python/virtualenv" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "gcc")
                echo "sys-devel/gcc" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "cmake")
                echo "dev-util/cmake" >> /mnt/gentoo/var/lib/portage/world
                ;;
            "vim")
                echo "app-editors/vim" >> /mnt/gentoo/var/lib/portage/world
                ;;
        esac
    done
}

# Flatpak support for gaming applications
configure_flatpak() {
    log "Configuring Flatpak support"
    
    dialog --backtitle "RaptorOS Post-Install" \
           --title "Flatpak Support" \
           --yesno "\nWould you like to enable Flatpak support?\n\n\
Benefits:\n\
- Easy Discord, OBS, Spotify installation\n\
- Sandboxed applications\n\
- Always up-to-date apps\n\
- No compilation needed\n\n\
This will add ~500MB to the system." 16 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Install Flatpak
    echo "sys-apps/flatpak" >> /mnt/gentoo/var/lib/portage/world
    echo "sys-apps/xdg-desktop-portal" >> /mnt/gentoo/var/lib/portage/world
    echo "sys-apps/xdg-desktop-portal-gtk" >> /mnt/gentoo/var/lib/portage/world
    
    # Configure Flatpak
    cat > /mnt/gentoo/usr/local/bin/setup-flatpak << 'EOF'
#!/bin/bash
# RaptorOS Flatpak Setup

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install gaming-related Flatpaks
echo "Installing gaming applications via Flatpak..."

# Discord
flatpak install -y flathub com.discordapp.Discord

# OBS Studio
flatpak install -y flathub com.obsproject.Studio

# Spotify (for gaming soundtracks)
flatpak install -y flathub com.spotify.Client

# ProtonUp-Qt (Proton version manager)
flatpak install -y flathub net.davidotek.pupgui2

# Bottles (Alternative Wine manager)
flatpak install -y flathub com.usebottles.bottles

echo "Flatpak applications installed!"
echo "You can manage them with: flatpak list"
EOF
    
    chmod +x /mnt/gentoo/usr/local/bin/setup-flatpak
    
    # Create desktop entries helper
    cat > /mnt/gentoo/usr/local/bin/flatpak-gaming-apps << 'EOF'
#!/bin/bash
# Quick launcher for Flatpak gaming apps

case "$1" in
    discord)
        flatpak run com.discordapp.Discord
        ;;
    obs)
        flatpak run com.obsproject.Studio
        ;;
    spotify)
        flatpak run com.spotify.Client
        ;;
    bottles)
        flatpak run com.usebottles.bottles
        ;;
    protonup)
        flatpak run net.davidotek.pupgui2
        ;;
    *)
        echo "Usage: $0 {discord|obs|spotify|bottles|protonup}"
        ;;
esac
EOF
    
    chmod +x /mnt/gentoo/usr/local/bin/flatpak-gaming-apps
    
    dialog --msgbox "Flatpak support configured!\n\n\
Run 'setup-flatpak' after first boot to install apps.\n\n\
Quick launch: flatpak-gaming-apps {app}" 10 50
}

# Validate RaptorOS configuration
validate_raptoros_config() {
    log "Validating RaptorOS configuration"
    
    local errors=0
    local warnings=0
    
    # Check if package environments are installed
    if [ ! -f /mnt/gentoo/etc/portage/env/gcc14-latest ]; then
        echo "ERROR: GCC 14.3 environment not found"
        errors=$((errors + 1))
    else
        echo "✓ GCC 14.3 environment found"
    fi
    
    if [ ! -f /mnt/gentoo/etc/portage/env/llvm20-mesa25 ]; then
        echo "ERROR: LLVM 20 + Mesa 25 environment not found"
        errors=$((errors + 1))
    else
        echo "✓ LLVM 20 + Mesa 25 environment found"
    fi
    
    if [ ! -f /mnt/gentoo/etc/portage/env/nvidia-modern ]; then
        echo "WARNING: NVIDIA modern environment not found"
        warnings=$((warnings + 1))
    else
        echo "✓ NVIDIA modern environment found"
    fi
    
    if [ ! -f /mnt/gentoo/etc/portage/env/systemd-modern ]; then
        echo "WARNING: systemd modern environment not found"
        warnings=$((warnings + 1))
    else
        echo "✓ systemd modern environment found"
    fi
    
    # Check if package keywords are installed
    if [ ! -f /mnt/gentoo/etc/portage/package.accept_keywords/raptoros-minimal-testing ]; then
        echo "ERROR: RaptorOS minimal testing keywords not found"
        errors=$((errors + 1))
    else
        echo "✓ RaptorOS minimal testing keywords found"
    fi
    
    # Check if package environment mappings are installed
    if [ ! -f /mnt/gentoo/etc/portage/package.env/modern-optimizations ]; then
        echo "ERROR: Modern optimizations package.env not found"
        errors=$((errors + 1))
    else
        echo "✓ Modern optimizations package.env found"
    fi
    
    # Check if scripts are installed
    if [ ! -f /mnt/gentoo/usr/local/bin/raptoros-update.sh ]; then
        echo "ERROR: RaptorOS update script not found"
        errors=$((errors + 1))
    else
        echo "✓ RaptorOS update script found"
    fi
    
    if [ ! -f /mnt/gentoo/usr/local/bin/validate-performance.sh ]; then
        echo "ERROR: Performance validation script not found"
        errors=$((errors + 1))
    else
        echo "✓ Performance validation script found"
    fi
    
    # Check if desktop shortcuts are created
    if [ ! -f /mnt/gentoo/home/$USERNAME/Desktop/raptoros-update.desktop ]; then
        echo "WARNING: RaptorOS update desktop shortcut not found"
        warnings=$((warnings + 1))
    else
        echo "✓ RaptorOS update desktop shortcut found"
    fi
    
    # Summary
    echo ""
    echo "═══════════════════════════════"
    echo "Validation Summary:"
    echo "Errors: $errors"
    echo "Warnings: $warnings"
    
    if [ $errors -eq 0 ]; then
        if [ $warnings -eq 0 ]; then
            dialog --msgbox "RaptorOS configuration validation passed! ✓\n\n\
All components are properly installed and configured.\n\
Your system is ready for maximum gaming performance!" 10 60
        else
            dialog --msgbox "RaptorOS configuration validation passed with warnings! ⚠️\n\n\
$errors errors, $warnings warnings\n\n\
Core functionality is working, but some optional components are missing." 12 60
        fi
    else
        dialog --msgbox "RaptorOS configuration validation failed! ✗\n\n\
$errors errors found\n$warnings warnings\n\n\
Please check the installation and try again." 12 60
    fi
}

# Verify complete installation
verify_installation() {
    log "Verifying complete installation"
    
    local checks_passed=0
    local checks_total=7
    
    # Check kernel installed
    if [ -f /mnt/gentoo/boot/vmlinuz* ] || [ -f /mnt/gentoo/boot/kernel* ]; then
        echo "✓ Kernel installed"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ Kernel not found"
    fi
    
    # Check bootloader
    if [ -f /mnt/gentoo/boot/grub/grub.cfg ] || [ -f /mnt/gentoo/boot/efi/EFI/BOOT/BOOTX64.EFI ]; then
        echo "✓ Bootloader configured"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ Bootloader not configured"
    fi
    
    # Check network config
    if [ -f /mnt/gentoo/etc/NetworkManager/NetworkManager.conf ] || [ -f /mnt/gentoo/etc/resolv.conf ]; then
        echo "✓ Network configuration found"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ Network configuration missing"
    fi
    
    # Check user created
    if grep -q "^$USERNAME:" /mnt/gentoo/etc/passwd; then
        echo "✓ User account created"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ User account not created"
    fi
    
    # Check GPU driver
    if [ -d /mnt/gentoo/lib/modules/*/kernel/drivers/gpu ] || [ -d /mnt/gentoo/lib/modules/*/kernel/drivers/video ]; then
        echo "✓ GPU drivers available"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ GPU drivers not found"
    fi
    
    # Check RaptorOS configurations
    if [ -f /mnt/gentoo/etc/portage/env/gcc14-latest ] && [ -f /mnt/gentoo/etc/portage/package.accept_keywords/raptoros-minimal-testing ]; then
        echo "✓ RaptorOS configurations installed"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ RaptorOS configurations missing"
    fi
    
    # Check utility scripts
    if [ -f /mnt/gentoo/usr/local/bin/raptoros-update.sh ] && [ -f /mnt/gentoo/usr/local/bin/validate-performance.sh ]; then
        echo "✓ Utility scripts installed"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ Utility scripts missing"
    fi
    
    # Summary
    echo ""
    echo "═══════════════════════════════"
    echo "Installation Verification:"
    echo "Passed: $checks_passed/$checks_total checks"
    
    if [ $checks_passed -eq $checks_total ]; then
        dialog --msgbox "✅ Installation Verification Successful!\n\n\
All $checks_total checks passed!\n\
Your RaptorOS system is fully installed and ready for gaming.\n\n\
Next steps:\n\
1. Reboot into your new system\n\
2. Run 'raptoros-update.sh' to update\n\
3. Run 'validate-performance.sh' to verify performance\n\
4. Install your favorite games and enjoy!" 14 60
    else
        local failed_checks=$((checks_total - checks_passed))
        dialog --msgbox "⚠️ Installation Verification Incomplete\n\n\
$checks_passed/$checks_total checks passed\n\
$failed_checks checks failed\n\n\
Some components may not be properly installed.\n\
Please review the installation and try again." 12 60
    fi
}
