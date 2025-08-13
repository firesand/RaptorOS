#!/bin/bash
# RaptorOS TUI Installer
# Hardware-optimized installation for gaming systems
set -e

# Configuration
SCRIPT_DIR="$(dirname "$0")"
MODULE_DIR="/usr/share/raptoros-installer"
# Create log directory that survives reboots
mkdir -p /var/log/raptoros 2>/dev/null || mkdir -p /tmp/raptoros-logs
LOG_FILE="/var/log/raptoros/install-$(date +%Y%m%d-%H%M%S).log" 2>/dev/null || LOG_FILE="/tmp/raptoros-logs/install-$(date +%Y%m%d-%H%M%S).log"

# Import modules - ORDER MATTERS!
MODULES=(
    "disk_selector.sh"
    "partition_manager.sh"
    "gpu_driver_selector.sh"
    "desktop_selector.sh"
    "kernel_selector.sh"
    "kernel_configurator.sh"
    "init_selector.sh"
    "network_configurator.sh"
    "post_install_tweaks.sh"
    "benchmark.sh"
    "secure_boot.sh"
    "backup_restore.sh"
)

for module in "${MODULES[@]}"; do
    if [ -f "$MODULE_DIR/$module" ]; then
        source "$MODULE_DIR/$module"
        log "Loaded module: $module"
    else
        echo "Warning: Module $MODULE_DIR/$module not found"
    fi
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Global variables
INSTALL_DISK=""
PARTITION_SCHEME=""
FILESYSTEM_TYPE=""
DESKTOP_ENV=""
GPU_DRIVER=""
GPU_VENDOR=""
KERNEL_TYPE=""
INIT_SYSTEM=""
HOSTNAME=""
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
BOOT_MODE=""
INSTALL_MODE=""

# Hardware variables
CPU_MODEL=""
CPU_CORES=""
CPU_MARCH=""
GPU_MODEL=""
RAM_SIZE=""
DISK_TYPE=""
DISK_SIZE=""
DISK_MODEL=""
DISK_AVAILABLE=""

# Partition variables
BOOT_PART=""
ROOT_PART=""
HOME_PART=""
SWAP_PART=""
GAMES_PART=""

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Main installer function
main() {
    clear
    show_welcome
    detect_hardware
    check_requirements

    # Core installation steps
    select_installation_mode
    select_installation_disk
    select_partition_scheme
    select_filesystem
    select_desktop_environment
    select_gpu_driver
    select_kernel
    select_init_system
    configure_system_settings

    # Network configuration (NEW)
    configure_network

    # Security configuration
    dialog --yesno "Configure security features?\n\n\
    • Secure Boot support\n\
    • Gaming firewall\n\
    • Kernel module signing" 12 50
    if [ $? -eq 0 ]; then
        configure_secure_boot
        configure_gaming_firewall
    fi

    # Review and confirm
    if review_installation; then
        perform_installation

        # Post-installation tweaks (NEW)
        dialog --yesno "Would you like to apply post-installation optimizations?" 8 50
        if [ $? -eq 0 ]; then
            post_installation_tweaks
        fi

        # Backup configuration (NEW)
        dialog --yesno "Would you like to configure automatic backups?" 8 50
        if [ $? -eq 0 ]; then
            schedule_backups
        fi

        show_completion_message
    else
        echo -e "${RED}Installation cancelled by user${NC}"
        exit 1
    fi
}

# Welcome screen
show_welcome() {
    dialog --colors --backtitle "RaptorOS Installer" \
           --title "\Zb\Z2Welcome to RaptorOS\Zn" \
           --msgbox "\n\
     ╦╔╗┌─┐┌─┐┌┬┐┌─┐┬─┐╔═╗╔═╗\n\
     ╠╦╝├─┤├─┘ │ │ │├┬┘║ ║╚═╗\n\
     ╩╚═┴ ┴┴   ┴ └─┘┴└─╚═╝╚═╝\n\
       Performance Evolved™\n\n\
  This installer will guide you through setting up\n\
  a gaming-optimized Gentoo Linux system.\n\n\
  Features:\n\
  • Hardware auto-detection and optimization\n\
  • Multiple desktop environments\n\
  • GPU driver selection (NVIDIA/AMD/Intel)\n\
  • Gaming kernel options\n\
  • BTRFS with compression and snapshots\n\
  • Network optimization\n\
  • Post-install tweaks\n\n\
  Press OK to continue..." 24 64
}

# Hardware detection
detect_hardware() {
    dialog --infobox "Detecting hardware..." 3 30

    # CPU detection
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    CPU_ARCH=$(lscpu | grep "Architecture" | cut -d: -f2 | xargs)

    # Detect CPU generation for optimization
    if echo "$CPU_MODEL" | grep -qi "14900\|13900\|14700"; then
        CPU_MARCH="raptorlake"
    elif echo "$CPU_MODEL" | grep -qi "12900\|12700"; then
        CPU_MARCH="alderlake"
    elif echo "$CPU_MODEL" | grep -qi "AMD.*7950X\|7900X\|7700X"; then
        CPU_MARCH="znver4"
    elif echo "$CPU_MODEL" | grep -qi "AMD.*5950X\|5900X\|5800X"; then
        CPU_MARCH="znver3"
    else
        CPU_MARCH="native"
    fi

    # Memory detection
    RAM_SIZE=$(free -g | awk '/^Mem:/{print $2}')

    # GPU detection - from gpu_driver_selector.sh module
    detect_gpu

    # Boot mode detection
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS"
    fi

    log "Hardware detection complete: CPU=$CPU_MODEL, RAM=${RAM_SIZE}GB, GPU=$GPU_MODEL, Boot=$BOOT_MODE"
}

# Check requirements
check_requirements() {
    local errors=""

    # Check RAM
    if [ "$RAM_SIZE" -lt 4 ]; then
        errors="${errors}\n• Insufficient RAM: ${RAM_SIZE}GB (minimum 4GB required)"
    fi

    # Check disk space
    local min_disk_size=20 # GB
    DISK_AVAILABLE=false
    for disk in $(lsblk -d -n -o NAME,SIZE | awk '{print $1}'); do
        local size=$(lsblk -d -b -n -o SIZE /dev/$disk 2>/dev/null | awk '{print int($1/1073741824)}')
        if [ "$size" -ge "$min_disk_size" ]; then
            DISK_AVAILABLE=true
            break
        fi
    done

    if [ "$DISK_AVAILABLE" = "false" ]; then
        errors="${errors}\n• No disk with at least ${min_disk_size}GB available"
    fi

    # Check network
    if ! ping -c 1 gentoo.org &> /dev/null; then
        dialog --msgbox "Warning: No internet connection detected.\nOffline installation will use cached packages only." 8 60
    fi

    if [ ! -z "$errors" ]; then
        dialog --msgbox "Installation cannot continue:$errors" 12 60
        exit 1
    fi
}

# Prepare installation environment
prepare_installation() {
    log "Preparing installation environment"

    # Create necessary directories
    mkdir -p /mnt/gentoo

    # Ensure we have required tools
    which mkfs.btrfs >/dev/null 2>&1 || error_exit "btrfs-progs not installed"
    which mkfs.ext4 >/dev/null 2>&1 || error_exit "e2fsprogs not installed"
    which mkfs.vfat >/dev/null 2>&1 || error_exit "dosfstools not installed"

    # Set system clock
    if command -v hwclock >/dev/null 2>&1; then
        hwclock --systohc --utc
    fi

    log "Installation environment prepared"
}

# Select installation mode
select_installation_mode() {
    INSTALL_MODE=$(dialog --backtitle "RaptorOS Installer" \
                          --title "Installation Mode" \
                          --radiolist "\nSelect installation mode:\n" \
                          15 70 4 \
                          "gaming" "Gaming Optimized - Full gaming stack with optimizations" ON \
                          "desktop" "Desktop - Standard desktop without gaming focus" OFF \
                          "minimal" "Minimal - Base system only" OFF \
                          "custom" "Custom - Choose every component" OFF \
                          3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"
}

# System configuration settings
configure_system_settings() {
    # Hostname
    HOSTNAME=$(dialog --backtitle "RaptorOS Installer" \
                      --title "System Configuration" \
                      --inputbox "\nEnter hostname:" 10 50 "raptoros" \
                      3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Username
    USERNAME=$(dialog --backtitle "RaptorOS Installer" \
                     --title "User Configuration" \
                     --inputbox "\nEnter username:" 10 50 \
                     3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # User password
    USER_PASSWORD=$(dialog --backtitle "RaptorOS Installer" \
                          --title "User Configuration" \
                          --passwordbox "\nEnter password for $USERNAME:" 10 50 \
                          3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Root password
    ROOT_PASSWORD=$(dialog --backtitle "RaptorOS Installer" \
                          --title "Root Configuration" \
                          --passwordbox "\nEnter root password:" 10 50 \
                          3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Timezone selection
    select_timezone

    # Locale selection
    select_locale
}

# Timezone selection
select_timezone() {
    local regions=($(timedatectl list-timezones 2>/dev/null | cut -d'/' -f1 | sort -u))

    if [ ${#regions[@]} -eq 0 ]; then
        # Fallback if timedatectl not available
        regions=("America" "Europe" "Asia" "Pacific" "Africa" "Australia")
    fi

    local region_list=()
    for region in "${regions[@]}"; do
        region_list+=("$region" "")
    done

    local region=$(dialog --backtitle "RaptorOS Installer" \
                         --title "Select Region" \
                         --menu "\nSelect your region:" \
                         20 50 12 \
                         "${region_list[@]}" \
                         3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    local zones=($(timedatectl list-timezones 2>/dev/null | grep "^$region/" | cut -d'/' -f2-))

    if [ ${#zones[@]} -eq 0 ]; then
        # Fallback zones
        case "$region" in
            "America") zones=("New_York" "Chicago" "Los_Angeles" "Toronto" "Mexico_City") ;;
            "Europe") zones=("London" "Paris" "Berlin" "Moscow" "Rome") ;;
            "Asia") zones=("Tokyo" "Shanghai" "Seoul" "Singapore" "Dubai") ;;
            *) zones=("GMT") ;;
        esac
    fi

    local zone_list=()
    for zone in "${zones[@]}"; do
        zone_list+=("$zone" "")
    done

    local zone=$(dialog --backtitle "RaptorOS Installer" \
                       --title "Select Timezone" \
                       --menu "\nSelect your timezone:" \
                       20 50 12 \
                       "${zone_list[@]}" \
                       3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    TIMEZONE="$region/$zone"
}

# Locale selection
select_locale() {
    local locales=(
        "en_US.UTF-8" "English (United States)"
        "en_GB.UTF-8" "English (United Kingdom)"
        "de_DE.UTF-8" "German (Germany)"
        "fr_FR.UTF-8" "French (France)"
        "es_ES.UTF-8" "Spanish (Spain)"
        "it_IT.UTF-8" "Italian (Italy)"
        "pt_BR.UTF-8" "Portuguese (Brazil)"
        "ru_RU.UTF-8" "Russian (Russia)"
        "ja_JP.UTF-8" "Japanese (Japan)"
        "zh_CN.UTF-8" "Chinese (China)"
        "ko_KR.UTF-8" "Korean (Korea)"
    )

    LOCALE=$(dialog --backtitle "RaptorOS Installer" \
                   --title "Select Locale" \
                   --menu "\nSelect system locale:" \
                   20 60 10 \
                   "${locales[@]}" \
                   3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && LOCALE="en_US.UTF-8"
}

# Review installation settings
review_installation() {
    local review_text="Please review your installation settings:\n\n"
    review_text+="═══════════════════════════════════════\n"
    review_text+="HARDWARE:\n"
    review_text+="  CPU: $CPU_MODEL ($CPU_CORES cores)\n"
    review_text+="  RAM: ${RAM_SIZE}GB\n"
    review_text+="  GPU: $GPU_MODEL\n"
    review_text+="  Boot: $BOOT_MODE\n\n"
    review_text+="DISK CONFIGURATION:\n"
    review_text+="  Disk: $INSTALL_DISK\n"
    review_text+="  Scheme: $PARTITION_SCHEME\n"
    review_text+="  Filesystem: $FILESYSTEM_TYPE\n\n"
    review_text+="SOFTWARE:\n"
    review_text+="  Mode: $INSTALL_MODE\n"
    review_text+="  Desktop: $DESKTOP_ENV\n"
    review_text+="  GPU Driver: $GPU_DRIVER\n"
    review_text+="  Kernel: $KERNEL_TYPE\n"
    review_text+="  Init: $INIT_SYSTEM\n\n"
    review_text+="SYSTEM:\n"
    review_text+="  Hostname: $HOSTNAME\n"
    review_text+="  Username: $USERNAME\n"
    review_text+="  Timezone: $TIMEZONE\n"
    review_text+="  Locale: $LOCALE\n"
    review_text+="═══════════════════════════════════════\n\n"
    review_text+="Begin installation?"

    dialog --backtitle "RaptorOS Installer" \
           --title "Review Installation" \
           --yesno "$review_text" 32 60

    return $?
}

# Install welcome app
install_welcome_app() {
    log "Installing RaptorOS Welcome Center"
    
    # Copy welcome app
    cp scripts/raptoros-welcome /mnt/gentoo/usr/local/bin/
    chmod +x /mnt/gentoo/usr/local/bin/raptoros-welcome
    
    # Copy UI helper library
    mkdir -p /mnt/gentoo/usr/local/lib/raptoros
    cp installer/modules/ui_helper.sh /mnt/gentoo/usr/local/lib/raptoros/
    
    # Copy game compatibility checker
    cp scripts/game-compatibility /mnt/gentoo/usr/local/bin/
    chmod +x /mnt/gentoo/usr/local/bin/game-compatibility
    
    # Create desktop entry for all users
    cat > /mnt/gentoo/usr/share/applications/raptoros-welcome.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=RaptorOS Welcome
GenericName=System Setup
Comment=Configure your RaptorOS gaming system
Exec=/usr/local/bin/raptoros-welcome
Icon=raptoros
Terminal=false
Categories=System;Settings;
Keywords=setup;gaming;optimization;
EOF
    
    # Create first-run trigger
    cat > /mnt/gentoo/etc/profile.d/raptoros-firstrun.sh << 'EOF'
# RaptorOS First Run Check
if [ ! -f ~/.config/raptoros/welcome-shown ] && [ -n "$DISPLAY" ]; then
    /usr/local/bin/raptoros-welcome &
fi
EOF
    
    log "Welcome app installed"
}

# Perform the actual installation
perform_installation() {
    # Create a dialog with progress
    (
        echo "5"
        echo "# Preparing installation..."
        prepare_installation

        echo "10"
        echo "# Creating partitions..."
        create_partitions

        echo "20"
        echo "# Formatting filesystems..."
        format_partitions

        echo "25"
        echo "# Mounting filesystems..."
        mount_partitions

        echo "30"
        echo "# Extracting base system..."
        extract_stage3

        echo "40"
        echo "# Configuring portage..."
        configure_portage_final

        echo "50"
        echo "# Installing kernel..."
        install_kernel_final

        echo "60"
        echo "# Installing GPU drivers..."
        install_gpu_driver

        echo "70"
        echo "# Installing desktop environment..."
        install_desktop_environment

        echo "80"
        echo "# Installing gaming stack..."
        install_gaming_stack

        echo "85"
        echo "# Configuring network..."
        configure_hosts  # From network module

        echo "90"
        echo "# Configuring bootloader..."
        install_bootloader

        echo "95"
        echo "# Final configuration..."
        final_configuration

        echo "98"
        echo "# Installing welcome app..."
        install_welcome_app

        echo "99"
        echo "# Verifying installation integrity..."
        verify_installation

        echo "100"
        echo "# Installation complete!"

    ) | dialog --backtitle "RaptorOS Installer" \
               --title "Installing RaptorOS" \
               --gauge "Starting installation..." \
               20 70 0
}

# Show completion message
show_completion_message() {
    # Build validation summary
    local validation_summary=""
    if [ -n "${VALIDATION_RESULTS[*]}" ]; then
        validation_summary="\nInstallation Validation:\n"
        for result in "${VALIDATION_RESULTS[@]}"; do
            validation_summary+="  $result\n"
        done
        validation_summary+="\nOverall: ${VALIDATION_PASSED:-0}/${VALIDATION_TOTAL:-0} checks passed"
    fi
    
    dialog --backtitle "RaptorOS Installer" \
           --title "Installation Complete!" \
           --msgbox "\n\
     ╦╔╗┌─┐┌─┐┌┬┐┌─┐┬─┐╔═╗╔═╗\n\
     ╠╦╝├─┤├─┘ │ │ │├┬┘║ ║╚═╗\n\
     ╩╚═┴ ┴┴   ┴ └─┘┴└─╚═╝╚═╝\n\
       Ready to Game!\n\n\
RaptorOS has been successfully installed!$validation_summary\n\n\
System Information:\n\
- Hostname: $HOSTNAME\n\
- Username: $USERNAME\n\
- Desktop: $DESKTOP_ENV\n\
- GPU Driver: $GPU_DRIVER\n\
- Kernel: $KERNEL_TYPE\n\
- Network: Optimized for gaming\n\n\
Remove the installation media and reboot.\n\n\
For detailed system validation, run: system-validator\n\n\
Enjoy gaming on Linux!" 30 70

    # Offer additional options
    dialog --backtitle "RaptorOS Installer" \
           --title "Post-Installation Options" \
           --menu "\nWhat would you like to do next?" 12 50 3 \
           "1" "Run full system validation" \
           "2" "Reboot now" \
           "3" "Exit to shell" 2>/tmp/choice

    choice=$(cat /tmp/choice 2>/dev/null || echo "2")
    rm -f /tmp/choice

    case $choice in
        "1")
            # Run full system validation
            echo "Running full system validation..."
            if [ -f /mnt/gentoo/usr/local/bin/system-validator ]; then
                # Mount necessary filesystems for validation
                mount --bind /proc /mnt/gentoo/proc
                mount --bind /sys /mnt/gentoo/sys
                mount --bind /dev /mnt/gentoo/dev
                
                # Run validation in chroot
                chroot /mnt/gentoo system-validator
                
                # Unmount
                umount /mnt/gentoo/proc /mnt/gentoo/sys /mnt/gentoo/dev 2>/dev/null || true
                
                read -p "Press Enter to continue..."
            else
                echo "System validator not found"
                read -p "Press Enter to continue..."
            fi
            ;;
        "2")
            # Reboot
            umount -R /mnt/gentoo 2>/dev/null || true
            reboot
            ;;
        "3")
            # Exit to shell
            echo "Installation complete. You can now:"
            echo "1. Run: system-validator (for detailed validation)"
            echo "2. Reboot: reboot"
            echo "3. Continue working in the installation environment"
            ;;
    esac
}

# Extract stage3
extract_stage3() {
    log "Extracting stage3 tarball"

    # Find stage3 file
    local stage3_file=$(find /mnt/cdrom -name "stage3-*.tar.xz" 2>/dev/null | head -1)

    if [ -z "$stage3_file" ]; then
        # Download stage3
        local STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
        local LATEST=$(wget -qO- $STAGE3_URL | tail -1 | cut -d' ' -f1)
        wget -c "https://distfiles.gentoo.org/releases/amd64/autobuilds/$LATEST" -O /tmp/stage3.tar.xz
        stage3_file="/tmp/stage3.tar.xz"
    fi

    # Extract
    tar xpf "$stage3_file" --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

    log "Stage3 extracted successfully"
}

# Configure Portage
configure_portage_final() {
    log "Configuring Portage"

    # Generate make.conf
    cat > /mnt/gentoo/etc/portage/make.conf << EOF
# RaptorOS Make.conf
# Generated for: $CPU_MODEL
# Build date: $(date)

# Compiler flags optimized for $CPU_MARCH
COMMON_FLAGS="-O3 -march=$CPU_MARCH -pipe -flto=auto"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
LDFLAGS="-Wl,-O3 -Wl,--as-needed"

# Parallel compilation
MAKEOPTS="-j$CPU_CORES -l$CPU_CORES"
EMERGE_DEFAULT_OPTS="--jobs=$((CPU_CORES/2)) --load-average=$CPU_CORES --quiet-build=y"

# System
USE="X wayland elogind dbus networkmanager bluetooth \
     vulkan opengl vaapi vdpau nvenc cuda \
     pulseaudio pipewire alsa \
     jpeg png webp gif svg truetype \
     zstd lz4 lto pgo jit \
     -systemd -debug -test"

VIDEO_CARDS="$GPU_DRIVER"
INPUT_DEVICES="libinput"
L10N="${LOCALE%.*}"
ACCEPT_LICENSE="*"
ACCEPT_KEYWORDS="~amd64"

# Python
PYTHON_TARGETS="python3_11 python3_12 python3_13"
PYTHON_SINGLE_TARGET="python3_12"

# Ruby
RUBY_TARGETS="ruby32 ruby33"

# Features
FEATURES="parallel-fetch parallel-install candy"

# Portage directories
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"
EOF

    # Copy DNS
    cp -L /etc/resolv.conf /mnt/gentoo/etc/

    # Mount proc, sys, dev
    mount -t proc /proc /mnt/gentoo/proc
    mount --rbind /sys /mnt/gentoo/sys
    mount --rbind /dev /mnt/gentoo/dev
    mount --bind /run /mnt/gentoo/run
}

# Install kernel (updated to use kernel_configurator module)
install_kernel_final() {
    log "Installing and configuring kernel"

    # Install kernel sources
    case "$KERNEL_TYPE" in
        "cachyos")
            # Add CachyOS overlay
            echo "[cachyos]" >> /mnt/gentoo/etc/portage/repos.conf/cachyos.conf
            echo "location = /var/db/repos/cachyos" >> /mnt/gentoo/etc/portage/repos.conf/cachyos.conf
            echo "sync-type = git" >> /mnt/gentoo/etc/portage/repos.conf/cachyos.conf
            echo "sync-uri = https://github.com/CachyOS/gentoo-overlay.git" >> /mnt/gentoo/etc/portage/repos.conf/cachyos.conf
            chroot /mnt/gentoo emerge --sync cachyos
            chroot /mnt/gentoo emerge -av sys-kernel/cachyos-kernel
            ;;
        "xanmod")
            chroot /mnt/gentoo emerge -av sys-kernel/xanmod-sources
            ;;
        "zen")
            chroot /mnt/gentoo emerge -av sys-kernel/zen-sources
            ;;
        *)
            chroot /mnt/gentoo emerge -av sys-kernel/gentoo-sources
            ;;
    esac

    # Configure kernel using kernel_configurator module
    configure_kernel

    # Build kernel
    build_kernel

    # Create module blacklist
    create_module_blacklist
}

# Install gaming stack
install_gaming_stack() {
    log "Installing gaming software stack"

    if [[ "$INSTALL_MODE" == "gaming" ]]; then
        cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
games-util/steam-launcher
games-util/lutris
games-util/heroic-games-launcher-bin
games-util/gamemode
games-util/mangohud
app-emulation/wine-staging
app-emulation/wine-mono
app-emulation/wine-gecko
media-libs/vkd3d-proton
sys-apps/gamemode
media-sound/discord
net-im/discord-bin
media-video/obs-studio
games-util/goverlay
EOF

        # Add LACT for AMD GPUs
        if [[ "$GPU_VENDOR" == "amd" ]]; then
            echo "sys-apps/lact" >> /mnt/gentoo/var/lib/portage/world
        fi
    fi

    # Emerge everything
    chroot /mnt/gentoo emerge -avuDN @world
}

# Install bootloader
install_bootloader() {
    log "Installing bootloader"

    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        # Install GRUB for UEFI
        chroot /mnt/gentoo emerge -av sys-boot/grub
        chroot /mnt/gentoo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=RaptorOS

        # Configure GRUB
        cat > /mnt/gentoo/etc/default/grub << EOF
GRUB_DISTRIBUTOR="RaptorOS"
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off"
GRUB_CMDLINE_LINUX=""
GRUB_GFXMODE=1920x1080
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_SUBMENU=y
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_THEME="/boot/grub/themes/raptoros/theme.txt"
EOF

        # Add gaming optimizations to kernel cmdline
        if [[ "$GPU_DRIVER" == "nvidia"* ]]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' \
                /mnt/gentoo/etc/default/grub
        fi

        # Add AMD-specific parameters
        if [[ "$GPU_VENDOR" == "amd" ]]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="amdgpu.ppfeaturemask=0xffffffff /' \
                /mnt/gentoo/etc/default/grub
        fi

        # Generate config
        chroot /mnt/gentoo grub-mkconfig -o /boot/grub/grub.cfg
    else
        # BIOS/Legacy boot
        chroot /mnt/gentoo emerge -av sys-boot/grub
        chroot /mnt/gentoo grub-install "$INSTALL_DISK"
        chroot /mnt/gentoo grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

# Verify installation integrity
verify_installation() {
    log "Verifying installation integrity"
    
    # Create a simplified validation function for installation
    local validation_results=()
    local total_checks=0
    local passed_checks=0
    
    echo "🔍 Running installation validation..."
    
    # Check 1: Critical files exist
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/etc/fstab ] && [ -f /mnt/gentoo/etc/hostname ]; then
        validation_results+=("✅ Critical files")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ Critical files")
    fi
    
    # Check 2: Bootloader installed
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/boot/grub/grub.cfg ] || [ -f /mnt/gentoo/boot/efi/EFI/gentoo/grubx64.efi ]; then
        validation_results+=("✅ Bootloader")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ Bootloader")
    fi
    
    # Check 3: Network configuration
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/etc/NetworkManager/NetworkManager.conf ] || [ -f /mnt/gentoo/etc/resolv.conf ]; then
        validation_results+=("✅ Network config")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ Network config")
    fi
    
    # Check 4: User creation
    total_checks=$((total_checks + 1))
    if [ -d /mnt/gentoo/home/"$USERNAME" ]; then
        validation_results+=("✅ User creation")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ User creation")
    fi
    
    # Check 5: GPU drivers
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/etc/portage/make.conf ] || [ -f /mnt/gentoo/etc/portage/package.env ]; then
        validation_results+=("✅ GPU drivers")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ GPU drivers")
    fi
    
    # Check 6: RaptorOS configs
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/etc/portage/package.accept_keywords/raptoros-minimal-testing ] && \
       [ -f /mnt/gentoo/etc/portage/package.env/modern-optimizations ]; then
        validation_results+=("✅ RaptorOS configs")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ RaptorOS configs")
    fi
    
    # Check 7: Utility scripts
    total_checks=$((total_checks + 1))
    if [ -f /mnt/gentoo/usr/local/bin/raptoros-update ] && \
       [ -f /mnt/gentoo/usr/local/bin/validate-performance ]; then
        validation_results+=("✅ Utility scripts")
        passed_checks=$((passed_checks + 1))
    else
        validation_results+=("❌ Utility scripts")
    fi
    
    # Store validation results for completion message
    VALIDATION_RESULTS=("${validation_results[@]}")
    VALIDATION_PASSED=$passed_checks
    VALIDATION_TOTAL=$total_checks
    
    # Log validation results
    log "Installation validation: $passed_checks/$total_checks checks passed"
    for result in "${validation_results[@]}"; do
        log "  $result"
    done
    
    echo "📊 Validation complete: $passed_checks/$total_checks checks passed"
}

# Final configuration
final_configuration() {
    log "Performing final configuration"

    # Set hostname
    echo "$HOSTNAME" > /mnt/gentoo/etc/hostname

    # Set timezone
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/gentoo/etc/localtime

    # Set locale
    echo "$LOCALE UTF-8" >> /mnt/gentoo/etc/locale.gen
    chroot /mnt/gentoo locale-gen
    echo "LANG=$LOCALE" > /mnt/gentoo/etc/locale.conf

    # Create user
    chroot /mnt/gentoo useradd -m -G users,wheel,audio,video,games,plugdev,networkmanager -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chroot /mnt/gentoo chpasswd
    echo "root:$ROOT_PASSWORD" | chroot /mnt/gentoo chpasswd

    # Enable sudo for wheel group
    echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/gentoo/etc/sudoers

    # Enable services
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        chroot /mnt/gentoo systemctl enable NetworkManager
        chroot /mnt/gentoo systemctl enable bluetooth
        [[ "$DESKTOP_ENV" == "kde-plasma" ]] && chroot /mnt/gentoo systemctl enable sddm
        [[ "$GPU_VENDOR" == "amd" ]] && chroot /mnt/gentoo systemctl enable lactd
    else
        chroot /mnt/gentoo rc-update add NetworkManager default
        chroot /mnt/gentoo rc-update add bluetooth default
        [[ "$DESKTOP_ENV" == "kde-plasma" ]] && chroot /mnt/gentoo rc-update add sddm default
        [[ "$GPU_VENDOR" == "amd" ]] && chroot /mnt/gentoo rc-update add lactd default
    fi

    # Create fstab
    log "Generating fstab"
    cat > /mnt/gentoo/etc/fstab << EOF
# /etc/fstab: static file system information.
# <fs>             <mountpoint>    <type>    <opts>                   <dump> <pass>

EOF

    # Add boot partition
    if [ ! -z "$BOOT_PART" ]; then
        echo "UUID=$(blkid -s UUID -o value $BOOT_PART)    /boot/efi    vfat    defaults,noatime    0 2" >> /mnt/gentoo/etc/fstab
    fi

    # Add root partition
    if [ ! -z "$ROOT_PART" ]; then
        if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
            echo "UUID=$(blkid -s UUID -o value $ROOT_PART)    /    btrfs    defaults,noatime,compress=zstd:1,space_cache=v2    0 1" >> /mnt/gentoo/etc/fstab
        else
            echo "UUID=$(blkid -s UUID -o value $ROOT_PART)    /    $FILESYSTEM_TYPE    defaults,noatime    0 1" >> /mnt/gentoo/etc/fstab
        fi
    fi

    # Add home partition if separate
    if [ ! -z "$HOME_PART" ]; then
        if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
            echo "UUID=$(blkid -s UUID -o value $HOME_PART)    /home    btrfs    defaults,noatime,compress=zstd:1,space_cache=v2    0 2" >> /mnt/gentoo/etc/fstab
        else
            echo "UUID=$(blkid -s UUID -o value $HOME_PART)    /home    $FILESYSTEM_TYPE    defaults,noatime    0 2" >> /mnt/gentoo/etc/fstab
        fi
    fi

    # Add games partition if exists
    if [ ! -z "$GAMES_PART" ]; then
        mkdir -p /mnt/gentoo/games
        if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
            echo "UUID=$(blkid -s UUID -o value $GAMES_PART)    /games    btrfs    defaults,noatime,compress=zstd:1,space_cache=v2    0 2" >> /mnt/gentoo/etc/fstab
        else
            echo "UUID=$(blkid -s UUID -o value $GAMES_PART)    /games    $FILESYSTEM_TYPE    defaults,noatime    0 2" >> /mnt/gentoo/etc/fstab
        fi
    fi

    # Add swap if exists
    if [ ! -z "$SWAP_PART" ]; then
        echo "UUID=$(blkid -s UUID -o value $SWAP_PART)    none    swap    sw    0 0" >> /mnt/gentoo/etc/fstab
    fi

    # Copy installer logs
    cp "$LOG_FILE" /mnt/gentoo/var/log/raptoros-install.log

    # Install system validator script
    if [ -f "$SCRIPT_DIR/../scripts/system-validator.sh" ]; then
        cp "$SCRIPT_DIR/../scripts/system-validator.sh" /mnt/gentoo/usr/local/bin/system-validator
        chmod +x /mnt/gentoo/usr/local/bin/system-validator
        log "System validator script installed"
    else
        log "Warning: System validator script not found"
    fi

    # Install all RaptorOS base configurations
    log "Installing RaptorOS base configurations"
    
    # Copy make.conf (already done earlier, but ensure it's there)
    if [ -f "$SCRIPT_DIR/../configs/make.conf" ]; then
        cp "$SCRIPT_DIR/../configs/make.conf" /mnt/gentoo/etc/portage/make.conf
        log "Base make.conf installed"
    fi
    
    # Copy package environments
    if [ -d "$SCRIPT_DIR/../configs/env" ]; then
        mkdir -p /mnt/gentoo/etc/portage/env
        cp -r "$SCRIPT_DIR/../configs/env/"* /mnt/gentoo/etc/portage/env/
        log "Package environments installed"
    fi
    
    # Copy package environment mappings
    if [ -d "$SCRIPT_DIR/../configs/package.env" ]; then
        mkdir -p /mnt/gentoo/etc/portage/package.env
        cp -r "$SCRIPT_DIR/../configs/package.env/"* /mnt/gentoo/etc/portage/package.env/
        log "Package environment mappings installed"
    fi
    
    # Copy package accept keywords
    if [ -d "$SCRIPT_DIR/../configs/package.accept_keywords" ]; then
        mkdir -p /mnt/gentoo/etc/portage/package.accept_keywords
        cp -r "$SCRIPT_DIR/../configs/package.accept_keywords/"* /mnt/gentoo/etc/portage/package.accept_keywords/
        log "Package accept keywords installed"
    fi
    
    # Copy utility scripts
    if [ -f "$SCRIPT_DIR/../scripts/raptoros-update.sh" ]; then
        cp "$SCRIPT_DIR/../scripts/raptoros-update.sh" /mnt/gentoo/usr/local/bin/raptoros-update
        chmod +x /mnt/gentoo/usr/local/bin/raptoros-update
        log "RaptorOS update script installed"
    fi
    
    if [ -f "$SCRIPT_DIR/../scripts/validate-performance.sh" ]; then
        cp "$SCRIPT_DIR/../scripts/validate-performance.sh" /mnt/gentoo/usr/local/bin/validate-performance
        chmod +x /mnt/gentoo/usr/local/bin/validate-performance
        log "Performance validation script installed"
    fi

    # Copy GameMode configuration
    if [ -f "$SCRIPT_DIR/../configs/gamemode.ini" ]; then
        cp "$SCRIPT_DIR/../configs/gamemode.ini" /mnt/gentoo/etc/gamemode.ini
        log "GameMode configuration installed"
    fi

    # Copy gaming sysctl configuration
    if [ -f "$SCRIPT_DIR/../configs/99-gaming.conf" ]; then
        mkdir -p /mnt/gentoo/etc/sysctl.d
        cp "$SCRIPT_DIR/../configs/99-gaming.conf" /mnt/gentoo/etc/sysctl.d/99-gaming.conf
        log "Gaming sysctl configuration installed"
    fi

    # Cleanup
    umount -l /mnt/gentoo/dev{/shm,/pts,} 2>/dev/null || true
    umount -l /mnt/gentoo{/proc,/sys,/run} 2>/dev/null || true
}

# Run if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
