#!/bin/bash
# Fix locale issues
export LC_ALL=C
export LANG=C
export LANGUAGE=C

# Preserve desktop session environment
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

# Force git sync instead of rsync for better reliability
export PORTAGE_SYNC_STALE=0
export PORTAGE_SYNC_EXTRA_OPTS="--git"
export SYNC="git"

# Gentoo Gaming ISO Builder
# Optimized for Intel i9-14900K + RTX 4090
# Build a custom Gentoo ISO with gaming optimizations

# set -e  # Commented out to prevent unexpected exits that can affect desktop session

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/var/tmp/gentoo-gaming-build"
ISO_OUTPUT="raptoros-gaming-$(date +%Y%m%d)-${STAGE3_TYPE:-desktop-openrc}.iso"
STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
STAGE3_PATTERN="stage3-amd64-desktop-openrc"

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
    echo ""
}

# Initialize with safe defaults
JOBS=4
LOAD=4

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Source modules
source "$SCRIPT_DIR/lib/colors.sh" 2>/dev/null || {
    echo "Warning: colors.sh not found, using fallback colors"
    # Fallback color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    NC='\033[0m'
}

source "$SCRIPT_DIR/lib/functions.sh" 2>/dev/null || {
    echo "Warning: functions.sh not found, using fallback functions"
    # Fallback function definitions
    log_info() { echo "[INFO] $1"; }
    log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
    log_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
    log_error() { echo -e "${RED}[ERROR] $1${NC}"; }
    die() { echo -e "${RED}FATAL ERROR: $1${NC}"; exit 1; }
}

# Source additional modules
source "$SCRIPT_DIR/lib/iso_boot.sh" 2>/dev/null || {
    echo "Warning: iso_boot.sh not found, ISO boot support limited"
}

source "$SCRIPT_DIR/lib/build_validation.sh" 2>/dev/null || {
    echo "Warning: build_validation.sh not found, build validation disabled"
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                RaptorOS Gaming ISO Builder v1.0           ║${NC}"
    echo -e "${CYAN}║         Optimized for i9-14900K + RTX 4090               ║${NC}"
    echo -e "${CYAN}║         Based on Gentoo Handbook:AMD64                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check requirements
check_requirements() {
    log_info "Checking build requirements..."
    
    # Check if running in terminal (prevents desktop session issues)
    if [ ! -t 0 ]; then
        echo -e "${RED}ERROR: This script must be run in a terminal!${NC}"
        echo -e "${YELLOW}Please run: gnome-terminal, konsole, or xterm${NC}"
        echo -e "${YELLOW}Then run: sudo ./build.sh${NC}"
        exit 1
    fi
    
    # Use enhanced validation if available
    if command -v validate_system_requirements &> /dev/null; then
        validate_system_requirements
        return
    fi
    
    # Fallback to basic validation
    echo -e "${CYAN}Checking build requirements...${NC}"
    
    local required_tools="wget git mksquashfs xorriso parted mkfs.fat btrfs dialog"
    local missing_tools=""
    
    for tool in $required_tools; do
        if ! command -v $tool &> /dev/null; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [ ! -z "$missing_tools" ]; then
        echo -e "${RED}Missing required tools:${NC}$missing_tools"
        echo -e "${YELLOW}Install with: sudo pacman -S$missing_tools${NC}"
        exit 1
    fi
    
    # Check disk space
    local available_space=$(df /var/tmp | awk 'NR==2 {print int($4/1048576)}')
    if [ $available_space -lt 50 ]; then
        echo -e "${RED}Insufficient disk space. Need at least 50GB free in /var/tmp${NC}"
        echo -e "${RED}Available: ${available_space}GB${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All requirements met${NC}"
}

# Ensure adequate swap space
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

# Cleanup swap file
cleanup_swap() {
    if [ -f /tmp/gentoo-build-swapfile ]; then
        local swapfile=$(cat /tmp/gentoo-build-swapfile)
        sudo swapoff "$swapfile" 2>/dev/null
        sudo rm -f "$swapfile"
        rm -f /tmp/gentoo-build-swapfile
        echo -e "${GREEN}✓ Temporary swap file cleaned up${NC}"
    fi
}

# Detect hardware
detect_hardware() {
    echo -e "${CYAN}Detecting hardware...${NC}"
    
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Unknown")
    else
        GPU_MODEL=$(lspci | grep VGA | cut -d: -f3 | xargs)
    fi
    
    echo -e "${GREEN}CPU: $CPU_MODEL (${CPU_CORES} threads)${NC}"
    echo -e "${GREEN}RAM: ${TOTAL_RAM}GB${NC}"
    echo -e "${GREEN}GPU: $GPU_MODEL${NC}"
    echo ""
}

# Stage3 selection
select_stage3() {
    echo -e "${CYAN}Select Stage3 type:${NC}"
    echo "1) Desktop OpenRC (Recommended for gaming - includes desktop tools)"
    echo "2) Desktop Systemd (Modern init system with desktop tools)"
    echo "3) Minimal OpenRC (Basic system - requires more setup)"
    echo "4) Minimal Systemd (Basic system with systemd)"
    echo ""
    echo -e "${YELLOW}Note: Desktop profiles include pre-configured desktop tools${NC}"
    echo -e "${YELLOW}and are recommended for gaming systems (Handbook:AMD64)${NC}"
    echo -e "${BLUE}Desktop profiles include: X11, sound, networking, and basic tools${NC}"
    echo -e "${BLUE}Minimal profiles require manual setup of all desktop components${NC}"
    echo ""
    read -p "Select [1-4]: " STAGE3_CHOICE
    
    case $STAGE3_CHOICE in
        1) 
            STAGE3_TYPE="desktop-openrc"
            STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
            STAGE3_PATTERN="stage3-amd64-desktop-openrc"
            echo -e "${GREEN}Selected: Desktop OpenRC Stage3 (Recommended)${NC}"
            ;;
        2) 
            STAGE3_TYPE="desktop-systemd"
            STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
            STAGE3_PATTERN="stage3-amd64-desktop-systemd"
            echo -e "${GREEN}Selected: Desktop Systemd Stage3${NC}"
            ;;
        3) 
            STAGE3_TYPE="minimal-openrc"
            STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
            STAGE3_PATTERN="stage3-amd64-openrc"
            echo -e "${GREEN}Selected: Minimal OpenRC Stage3${NC}"
            ;;
        4) 
            STAGE3_TYPE="minimal-systemd"
            STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
            STAGE3_PATTERN="stage3-amd64-systemd"
            echo -e "${GREEN}Selected: Minimal Systemd Stage3${NC}"
            ;;
        *) 
            echo -e "${RED}Invalid option, defaulting to Desktop OpenRC${NC}"
            STAGE3_TYPE="desktop-openrc"
            STAGE3_URL="https://gentoo.osuosl.org/releases/amd64/autobuilds/"
            STAGE3_PATTERN="stage3-amd64-desktop-openrc"
            ;;
    esac
    echo ""
}

# Build menu
show_build_menu() {
    echo -e "${CYAN}Select build type:${NC}"
    echo "1) Quick Build (1-2 hours) - Uses binary packages where possible"
    echo "2) Optimized Build (3-4 hours) - Compiles critical packages"
    echo "3) Full Build (6-8 hours) - Compiles everything from source"
    echo "4) ISO Only - Use existing build directory"
    echo "5) Clean Build Directory"
    echo "6) Recovery Mode - Fix broken installation"
    echo "7) Validate Build - Run comprehensive validation checks"
    echo ""
    read -p "Select [1-7]: " BUILD_TYPE
    
    case $BUILD_TYPE in
        1) build_quick ;;
        2) build_optimized ;;
        3) build_full ;;
        4) create_iso_only ;;
        5) clean_build ;;
        6) recovery_mode ;;
        7) validate_existing_build ;;
        *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
    esac
}

# Setup build environment
setup_build_env() {
    echo -e "${CYAN}Setting up build environment...${NC}"
    echo -e "${BLUE}Following Gentoo Handbook:AMD64 installation process${NC}"
    echo ""
    
    # Create directories
    mkdir -p "$BUILD_DIR"/{squashfs,iso,work}
    cd "$BUILD_DIR"
    
    # Download stage3 if needed
    if [ ! -f "stage3-*.tar.xz" ]; then
        echo -e "${CYAN}Downloading stage3...${NC}"
        
        # Get the latest stage3 file from the selected URL using pattern matching
        echo -e "${CYAN}Finding latest stage3 for pattern: $STAGE3_PATTERN${NC}"
        
        # Find the latest date directory containing our stage3 pattern
        local latest_date_dir=$(wget -qO- "$STAGE3_URL" | grep -o "href=\"[0-9]*T[0-9]*Z/\"" | grep -o "[0-9]*T[0-9]*Z" | sort -r | head -1)
        
        if [ -z "$latest_date_dir" ]; then
            echo -e "${RED}Error: Could not find latest date directory${NC}"
            echo -e "${YELLOW}URL: $STAGE3_URL${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}Latest date directory: $latest_date_dir${NC}"
        
        # Now find the stage3 file in that directory
        local stage3_file=$(wget -qO- "$STAGE3_URL$latest_date_dir/" | grep -o "stage3-[^\"<>]*\.tar\.xz" | grep "$STAGE3_PATTERN" | grep -v "\.asc\|\.CONTENTS\|\.DIGESTS\|\.sha256" | head -1)
        
        if [ -z "$stage3_file" ]; then
            echo -e "${RED}Error: Could not find stage3 file for pattern: $STAGE3_PATTERN${NC}"
            echo -e "${YELLOW}Date directory: $latest_date_dir${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Downloading: $stage3_file${NC}"
        if ! wget -c "$STAGE3_URL$latest_date_dir/$stage3_file"; then
            echo -e "${RED}Error: Failed to download stage3 tarball${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Stage3 downloaded successfully${NC}"
    fi
    
    # Extract stage3
    if [ ! -d "squashfs/etc" ]; then
        echo -e "${CYAN}Extracting stage3...${NC}"
        
        # Check if stage3 file exists
        local stage3_file=$(find . -name "stage3-*.tar.xz" 2>/dev/null | head -1)
        if [ -z "$stage3_file" ]; then
            echo -e "${RED}Error: No stage3 file found! Cannot continue.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Extracting: $stage3_file${NC}"
        cd squashfs
        if ! sudo tar xpf "../$stage3_file" --xattrs-include='*.*' --numeric-owner; then
            echo -e "${RED}Error: Failed to extract stage3 tarball${NC}"
            cd ..
            exit 1
        fi
        cd ..
        echo -e "${GREEN}✓ Stage3 extracted successfully${NC}"
        
        # Show profile information
        if [[ "$STAGE3_TYPE" == *"desktop"* ]]; then
            echo -e "${GREEN}✓ Desktop profile detected - includes X11, sound, and networking${NC}"
            echo -e "${BLUE}This will significantly speed up the gaming setup process${NC}"
        else
            echo -e "${YELLOW}⚠ Minimal profile detected - additional setup required for desktop${NC}"
            echo -e "${BLUE}Consider using desktop profiles for faster gaming setup${NC}"
        fi
    fi
    
    # Copy configurations
    echo -e "${CYAN}Copying configurations...${NC}"
    sudo cp -r "$SCRIPT_DIR/configs/"* squashfs/etc/portage/ 2>/dev/null || true
    sudo cp "$SCRIPT_DIR/installer/"* squashfs/usr/local/bin/ 2>/dev/null || true
    sudo chmod +x squashfs/usr/local/bin/* 2>/dev/null || true
}

# Configure make.conf
configure_portage() {
    echo -e "${CYAN}Configuring Portage using base config...${NC}"
    
    # Ensure configs directory exists
    if [ ! -f "$SCRIPT_DIR/configs/make.conf" ]; then
        echo -e "${RED}Error: Base make.conf not found at $SCRIPT_DIR/configs/make.conf${NC}"
        echo -e "${YELLOW}Please ensure the RaptorOS configs are properly set up${NC}"
        exit 1
    fi
    
    # Copy the master make.conf
    sudo cp "$SCRIPT_DIR/configs/make.conf" "squashfs/etc/portage/make.conf"
    
    # Copy RaptorOS configuration files
    sudo mkdir -p "squashfs/etc/portage/env"
    sudo mkdir -p "squashfs/etc/portage/package.env"
    sudo mkdir -p "squashfs/etc/portage/package.accept_keywords"
    
    sudo cp -r "$SCRIPT_DIR/configs/env/"* "squashfs/etc/portage/env/" 2>/dev/null || true
    sudo cp -r "$SCRIPT_DIR/configs/package.env/"* "squashfs/etc/portage/package.env/" 2>/dev/null || true
    sudo cp -r "$SCRIPT_DIR/configs/package.accept_keywords/"* "squashfs/etc/portage/package.accept_keywords/" 2>/dev/null || true
    
    # Now, append build-specific flags if needed
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
    
    echo -e "${GREEN}✓ Portage configured with RaptorOS base config + build overrides${NC}"
}

# Configure repository sync method
configure_repos() {
    echo -e "${CYAN}Configuring repository sync method...${NC}"
    
    # Create repos.conf directory
    sudo mkdir -p squashfs/etc/portage/repos.conf
    
    # Copy repos.conf if it exists
    if [ -f "$SCRIPT_DIR/configs/repos.conf" ]; then
        sudo cp "$SCRIPT_DIR/configs/repos.conf" squashfs/etc/portage/repos.conf/gentoo.conf
        echo -e "${GREEN}✓ Git sync configured${NC}"
    else
        # Create repos.conf for git sync
        sudo tee squashfs/etc/portage/repos.conf/gentoo.conf > /dev/null << 'EOF'
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo/gentoo.git
auto-sync = yes
sync-depth = 1
clone-depth = 1
EOF
        echo -e "${GREEN}✓ Git sync configured (generated)${NC}"
    fi
}

# Safe portage sync function
safe_portage_sync() {
    echo -e "${CYAN}Syncing portage tree...${NC}"
    
    # Try git first
    if command -v git &> /dev/null && [ -f /etc/portage/repos.conf/gentoo.conf ]; then
        if grep -q "sync-type = git" /etc/portage/repos.conf/gentoo.conf 2>/dev/null; then
            echo "Using git sync..."
            emerge --sync && return 0
        fi
    fi
    
    # Fallback to webrsync
    echo "Using webrsync (more reliable than rsync)..."
    emerge-webrsync && return 0
    
    # Last resort: try different rsync mirrors
    echo "Trying alternative rsync mirrors..."
    local mirrors=(
        "rsync://rsync.gentoo.org/gentoo-portage"
        "rsync://rsync.us.gentoo.org/gentoo-portage"
        "rsync://rsync.eu.gentoo.org/gentoo-portage"
    )
    
    for mirror in "${mirrors[@]}"; do
        echo "Trying mirror: $mirror"
        PORTAGE_RSYNC_EXTRA_OPTS="--timeout=30" SYNC="$mirror" emerge --sync && return 0
    done
    
    echo -e "${RED}ERROR: Could not sync portage tree${NC}"
    return 1
}

# Setup chroot
setup_chroot() {
    echo -e "${CYAN}Setting up chroot environment...${NC}"
    
    # Mount necessities
    sudo mount -t proc /proc squashfs/proc
    sudo mount --rbind /sys squashfs/sys
    sudo mount --rbind /dev squashfs/dev
    sudo mount --bind /run squashfs/run
    
    # Copy resolv.conf
    sudo cp -L /etc/resolv.conf squashfs/etc/
}

# Enhanced cleanup function with force unmount
force_cleanup_chroot() {
    echo -e "${CYAN}Force cleaning up chroot mounts...${NC}"
    
    local build_dir="${BUILD_DIR:-/var/tmp/gentoo-gaming-build}"
    
    if [ ! -d "$build_dir/squashfs" ]; then
        return
    fi
    
    cd / # Change to root to avoid being in mounted directory
    
    # Kill processes using the mounts
    echo "Terminating processes using mounts..."
    sudo fuser -km "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/proc" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo fuser -km "$build_dir/squashfs/run" 2>/dev/null || true
    
    # Wait a moment for processes to die
    sleep 2
    
    # Unmount in correct order (most specific first)
    echo "Unmounting filesystems..."
    
    # Find all submounts and unmount them first
    for mount in $(findmnt -R "$build_dir/squashfs" -o TARGET --noheadings | tac 2>/dev/null); do
        sudo umount -l "$mount" 2>/dev/null || true
    done
    
    # Force unmount the main ones
    sudo umount -R "$build_dir/squashfs/run" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo umount -R "$build_dir/squashfs/proc" 2>/dev/null || true
    
    # Last resort - lazy unmount
    sudo umount -lf "$build_dir/squashfs/run" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev/pts" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev/shm" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/dev" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/sys" 2>/dev/null || true
    sudo umount -lf "$build_dir/squashfs/proc" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Chroot cleanup complete${NC}"
    
    # Cleanup swap file
    cleanup_swap
}

# Safe chroot execution with automatic cleanup
safe_chroot_exec() {
    local chroot_script="$1"
    local chroot_dir="${BUILD_DIR}/squashfs"
    
    echo -e "${CYAN}Entering safe chroot environment...${NC}"
    
    # Setup chroot
    setup_chroot
    
    # Create a temporary script
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'SCRIPT_END'
#!/bin/bash
# set -e  # Commented out to prevent unexpected exits
source /etc/profile

# Add timeout to prevent hanging
timeout_handler() {
    echo "Command timed out!"
    exit 1
}
trap timeout_handler TERM

SCRIPT_END
    
    # Add the actual commands
    echo "$chroot_script" >> "$temp_script"
    
    # Copy script to chroot
    sudo cp "$temp_script" "$chroot_dir/tmp/chroot_script.sh"
    sudo chmod +x "$chroot_dir/tmp/chroot_script.sh"
    rm "$temp_script"
    
    # Execute with timeout and cleanup
    (
        # Run in subshell to capture PID
        sudo timeout --preserve-status 3600 \
            chroot "$chroot_dir" /tmp/chroot_script.sh
    ) &
    
    CHROOT_PID=$!
    
    # Wait for completion or interruption
    wait $CHROOT_PID 2>/dev/null || {
        local exit_code=$?
        if [ $exit_code -eq 130 ] || [ $exit_code -eq 143 ]; then
            echo -e "${YELLOW}Chroot interrupted by user${NC}"
        elif [ $exit_code -eq 124 ]; then
            echo -e "${RED}Chroot timed out after 1 hour${NC}"
        else
            echo -e "${RED}Chroot failed with exit code: $exit_code${NC}"
        fi
    }
    
    # Always cleanup
    cleanup_chroot
    
    # Remove temporary script
    sudo rm -f "$chroot_dir/tmp/chroot_script.sh"
    
    unset CHROOT_PID
}

# Enhanced signal handling and cleanup
cleanup_on_signal() {
    echo ""
    echo -e "${RED}Build interrupted! Cleaning up...${NC}"
    
    # Set a flag to prevent recursive cleanup
    if [ "${CLEANUP_IN_PROGRESS}" = "true" ]; then
        return
    fi
    export CLEANUP_IN_PROGRESS=true
    
    # Kill any running chroot processes
    if [ -n "${CHROOT_PID}" ]; then
        echo "Killing chroot processes..."
        sudo kill -TERM ${CHROOT_PID} 2>/dev/null || true
        sleep 2
        sudo kill -KILL ${CHROOT_PID} 2>/dev/null || true
    fi
    
    # Force cleanup of mounts
    force_cleanup_chroot
    
    echo -e "${GREEN}Cleanup complete. Your system should be stable.${NC}"
    echo -e "${YELLOW}Returning to build menu...${NC}"
    return 0  # Return instead of exit to prevent session termination
}

# Cleanup chroot (enhanced version)
cleanup_chroot() {
    echo -e "${CYAN}Cleaning up chroot...${NC}"
    
    # Try normal cleanup first
    sudo umount -l squashfs/proc 2>/dev/null || true
    sudo umount -l squashfs/sys 2>/dev/null || true
    sudo umount -l squashfs/dev 2>/dev/null || true
    sudo umount -l squashfs/run 2>/dev/null || true
    
    # If mounts still exist, force cleanup
    if mount | grep -q "squashfs"; then
        echo "Some mounts still exist, forcing cleanup..."
        force_cleanup_chroot
    fi
}

# Quick build using binaries
build_quick() {
    echo -e "${CYAN}Starting quick build (binary packages)...${NC}"
    
    setup_build_env
    configure_portage
    configure_repos  # Add this line
    setup_chroot
    
    # Add binary host
    sudo tee -a squashfs/etc/portage/make.conf > /dev/null << 'EOF'

# Binary packages for quick build
FEATURES="${FEATURES} getbinpkg"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"
PORTAGE_BINHOST="https://gentoo.osuosl.org/experimental/amd64/binpkg/default/linux/17.1/x86-64/"
EOF
    
    # Install packages in chroot
    sudo chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile

# First, check if git is available
if ! command -v git &> /dev/null; then
    echo "Installing git first..."
    # Use webrsync as fallback to get initial portage tree
    emerge-webrsync
    emerge --oneshot dev-vcs/git
fi

# Now sync with git
emerge --sync

# Install essential packages
emerge --quiet --getbinpkg -av \
    sys-kernel/gentoo-kernel-bin \
    sys-kernel/linux-firmware \
    sys-boot/grub \
    sys-boot/efibootmgr \
    sys-apps/pciutils \
    sys-apps/usbutils \
    net-misc/networkmanager \
    net-misc/dhcpcd \
    app-admin/sudo \
    app-editors/neovim \
    app-misc/dialog \
    app-portage/gentoolkit \
    app-portage/cpuid2cpuflags \
    sys-fs/btrfs-progs \
    sys-fs/dosfstools \
    sys-fs/ntfs3g \
    sys-block/zram-init

# Install GPU drivers
emerge --quiet --getbinpkg -av x11-drivers/nvidia-drivers

# Install gaming essentials
emerge --quiet --getbinpkg -av \
    games-util/steam-launcher \
    games-util/lutris \
    games-util/gamemode \
    games-util/mangohud \
    app-emulation/wine-staging

# Install desktop (user choice)
# This will be handled by installer
CHROOTCMD
    
    cleanup_chroot
    
    # Create backup before final steps
    create_backup
    
    create_installer
    create_iso
}

# Optimized build
build_optimized() {
    echo -e "${CYAN}Starting optimized build...${NC}"
    
    setup_build_env
    configure_portage
    configure_repos  # Add this line
    setup_chroot
    
    # Build critical packages from source
    sudo chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile

# Sync portage using git (more reliable than rsync)
emerge --sync --quiet

# Update system
emerge --quiet --update --deep --newuse @world

# Build kernel from source
emerge -av sys-kernel/gentoo-sources
cd /usr/src/linux
make defconfig
make -j48
make modules_install
make install

# Build rest with mix of binary and source
emerge -av \
    sys-kernel/linux-firmware \
    sys-boot/grub \
    sys-apps/systemd \
    x11-drivers/nvidia-drivers \
    games-util/steam-launcher \
    games-util/lutris \
    games-util/gamemode \
    app-emulation/wine-staging
CHROOTCMD
    
    cleanup_chroot
    
    # Create backup before final steps
    create_backup
    
    create_installer
    create_iso
}

# Full build from source
build_full() {
    echo -e "${CYAN}Starting full build (everything from source)...${NC}"
    echo -e "${YELLOW}This will take 6-8 hours!${NC}"
    
    setup_build_env
    configure_portage
    configure_repos  # Add this line
    setup_chroot
    
    # Build everything from source
    sudo chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile

# Sync portage using git (more reliable than rsync)
emerge --sync

# Full system update
emerge --emptytree --update --deep --newuse @world

# Install all packages
emerge -av \
    sys-kernel/gentoo-sources \
    sys-kernel/linux-firmware \
    sys-boot/grub \
    x11-drivers/nvidia-drivers \
    kde-plasma/plasma-meta \
    games-util/steam-launcher \
    games-util/lutris \
    games-util/gamemode \
    app-emulation/wine-staging
CHROOTCMD
    
    cleanup_chroot
    
    # Create backup before final steps
    create_backup
    
    create_installer
    create_iso
}

# Create installer
create_installer() {
    echo -e "${CYAN}Creating TUI installer...${NC}"
    
    # Copy installer files
    sudo cp -r "$SCRIPT_DIR/installer/"* squashfs/usr/local/bin/
    sudo chmod +x squashfs/usr/local/bin/install_gentoo
    
    # Create installer data
    sudo mkdir -p squashfs/usr/share/gentoo-installer
    sudo cp -r "$SCRIPT_DIR/installer/modules/"* squashfs/usr/share/gentoo-installer/
    
    # Create welcome message
    sudo tee squashfs/etc/motd > /dev/null << 'EOF'
╔══════════════════════════════════════════════════════════╗
║          Welcome to Gentoo Gaming Live System             ║
║         Optimized for Intel i9-14900K + RTX 4090          ║
║                                                            ║
║  Type 'install_gentoo' to start the installation          ║
║                                                            ║
║  Default credentials: gentoo/gentoo                       ║
╚══════════════════════════════════════════════════════════╝
EOF
}

# Create ISO
create_iso() {
    log_info "Creating ISO image..."
    
    cd "$BUILD_DIR"
    
    # Create squashfs
    log_info "Creating compressed filesystem..."
    sudo mksquashfs squashfs iso/gentoo.squashfs \
        -comp xz -b 1M -Xdict-size 100% \
        -e boot/lost+found \
        -e var/tmp/portage \
        -e var/cache/distfiles \
        -e var/cache/gentoo \
        -e tmp \
        -e root/.cache
    
    # Setup bootloader
    safe_mkdir "iso/boot" "boot directory"
    safe_mkdir "iso/EFI/BOOT" "EFI boot directory"
    
    # Copy kernel
    local kernel_found=false
    for kernel_pattern in "vmlinuz*" "kernel*" "bzImage*"; do
        if ls squashfs/boot/$kernel_pattern 2>/dev/null | grep -q .; then
            sudo cp squashfs/boot/$kernel_pattern iso/boot/vmlinuz
            kernel_found=true
            log_success "Kernel copied: $(ls squashfs/boot/$kernel_pattern | head -1)"
            break
        fi
    done
    
    if [ "$kernel_found" = false ]; then
        die "No kernel found in squashfs/boot/"
    fi
    
    # Use enhanced ISO boot support if available
    if command -v setup_complete_boot_support &> /dev/null; then
        log_info "Using enhanced ISO boot support..."
        setup_complete_boot_support "squashfs" "iso" "/boot/vmlinuz"
    else
        log_warning "Enhanced ISO boot support not available, using basic setup..."
        
        # Create basic initramfs if needed
        if [ ! -f squashfs/boot/initramfs* ]; then
            log_warning "Creating minimal initramfs..."
            # This is simplified - real initramfs would need more setup
            (cd squashfs && sudo find . | sudo cpio -o -H newc | gzip > ../iso/boot/initramfs)
        else
            sudo cp squashfs/boot/initramfs* iso/boot/initramfs
        fi
        
        # Create basic GRUB config
        cat > iso/boot/grub/grub.cfg << 'GRUBCFG'
set timeout=10
set default=0

menuentry "Gentoo Gaming Live (Install)" {
    linux /boot/vmlinuz root=/dev/ram0 init=/init quiet splash
    initrd /boot/initramfs
}

menuentry "Gentoo Gaming Live (Safe Mode)" {
    linux /boot/vmlinuz root=/dev/ram0 init=/init single
    initrd /boot/initramfs
}
GRUBCFG
    fi
    
    # Create ISO
    log_info "Building ISO image..."
    xorriso -as mkisofs \
        -o "$SCRIPT_DIR/$ISO_OUTPUT" \
        -V "RAPTOROS_GAMING" \
        -J -R -l \
        -b boot/grub/stage2_eltorito \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/syslinux/bios/mbr.bin 2>/dev/null || true \
        iso/
    
    log_success "ISO created: $ISO_OUTPUT"
    log_info "Size: $(du -h "$SCRIPT_DIR/$ISO_OUTPUT" | cut -f1)"
    
    # Run validation if available
    if command -v run_complete_validation &> /dev/null; then
        log_info "Running build validation..."
        run_complete_validation "squashfs" "iso" "$SCRIPT_DIR/$ISO_OUTPUT"
    else
        log_warning "Build validation not available"
    fi
}

# Create ISO only (using existing build)
create_iso_only() {
    if [ ! -d "$BUILD_DIR/squashfs" ]; then
        echo -e "${RED}No build directory found. Run a build first.${NC}"
        exit 1
    fi
    
    create_iso
}

# Clean build directory
clean_build() {
    log_info "Cleaning build directory..."
    
    cleanup_chroot
    
    read -p "This will delete all build files. Continue? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo rm -rf "$BUILD_DIR"
        log_success "Build directory cleaned"
    else
        log_warning "Clean cancelled"
    fi
}

# Validate existing build
validate_existing_build() {
    log_info "Validating existing build..."
    
    if [ ! -d "$BUILD_DIR/squashfs" ]; then
        die "No build directory found. Run a build first."
    fi
    
    if [ ! -d "$BUILD_DIR/iso" ]; then
        die "No ISO directory found. Run a build first."
    fi
    
    # Check if ISO file exists
    local iso_file=""
    for file in "$SCRIPT_DIR"/raptoros-gaming-*.iso; do
        if [ -f "$file" ]; then
            iso_file="$file"
            break
        fi
    done
    
    if [ -z "$iso_file" ]; then
        die "No ISO file found. Run a build first."
    fi
    
    log_info "Found build components:"
    log_info "  SquashFS: $BUILD_DIR/squashfs"
    log_info "  ISO directory: $BUILD_DIR/iso"
    log_info "  ISO file: $iso_file"
    
    # Run validation if available
    if command -v run_complete_validation &> /dev/null; then
        log_info "Running comprehensive build validation..."
        run_complete_validation "$BUILD_DIR/squashfs" "$BUILD_DIR/iso" "$iso_file"
    else
        log_warning "Build validation not available, running basic checks..."
        
        # Basic validation
        echo "=== Basic Build Validation ==="
        echo "SquashFS size: $(du -sh "$BUILD_DIR/squashfs" | cut -f1)"
        echo "ISO directory size: $(du -sh "$BUILD_DIR/iso" | cut -f1)"
        echo "ISO file size: $(du -h "$iso_file" | cut -f1)"
        echo "Kernel: $(ls "$BUILD_DIR/squashfs/boot"/vmlinuz* 2>/dev/null | head -1 || echo 'Not found')"
        echo "Initramfs: $(ls "$BUILD_DIR/squashfs/boot"/initramfs* 2>/dev/null | head -1 || echo 'Not found')"
        echo "GRUB config: $(ls "$BUILD_DIR/iso/boot/grub"/grub.cfg 2>/dev/null | head -1 || echo 'Not found')"
    fi
}

# Recovery mode for fixing broken installations
recovery_mode() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              RaptorOS Recovery Mode                      ║${NC}"
    echo -e "${CYAN}║           Advanced System Recovery & Debugging          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if we have a broken installation to fix
    if [ ! -d "$BUILD_DIR/squashfs" ]; then
        echo -e "${RED}No build directory found. Cannot perform recovery.${NC}"
        echo -e "${YELLOW}Please run a build first, then use recovery mode.${NC}"
        exit 1
    fi
    
    while true; do
        echo -e "${YELLOW}Recovery Options:${NC}"
        echo ""
        echo "1) 🔧 Fix broken package installations"
        echo "2) 💾 Restore from backup"
        echo "3) 🚀 Reset to clean state"
        echo "4) ✅ Validate system integrity"
        echo "5) 🖥️  Chroot into existing build"
        echo "6) 🔄 Reset configurations"
        echo "7) 📊 Advanced diagnostics"
        echo "8) 🆘 Emergency recovery"
        echo "9) 🚪 Exit recovery mode"
        echo ""
        
        read -p "Select recovery option [1-9]: " recovery_option
        
        case $recovery_option in
            1)
                fix_broken_packages
                ;;
            2)
                restore_from_backup
                ;;
            3)
                reset_to_clean_state
                ;;
            4)
                validate_system_integrity
                ;;
            5)
                chroot_into_build
                ;;
            6)
                reset_configurations
                ;;
            7)
                advanced_diagnostics
                ;;
            8)
                emergency_recovery
                ;;
            9)
                echo -e "${YELLOW}Exiting recovery mode${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Invalid recovery option${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Fix broken package installations
fix_broken_packages() {
    echo -e "${CYAN}🔧 Fixing broken package installations...${NC}"
    echo ""
    
    cd "$BUILD_DIR/squashfs"
    
    # Mount necessary filesystems for chroot
    mount_chroot_filesystems
    
    echo "Attempting to resume interrupted emerge..."
    if sudo chroot . emerge --resume --skip-first; then
        echo -e "${GREEN}✓ Package installation resumed successfully${NC}"
    else
        echo -e "${YELLOW}Package resume failed, trying alternative recovery methods...${NC}"
        echo ""
        
        echo "1. Cleaning broken packages..."
        sudo chroot . emerge --depclean -a
        
        echo "2. Rebuilding preserved packages..."
        sudo chroot . emerge @preserved-rebuild
        
        echo "3. Attempting full system update..."
        sudo chroot . emerge -avuDN @world --keep-going
        
        echo "4. Final cleanup..."
        sudo chroot . emerge --depclean -a
        sudo chroot . emerge @preserved-rebuild
        
        echo -e "${GREEN}✓ Package recovery completed${NC}"
    fi
    
    # Unmount chroot filesystems
    unmount_chroot_filesystems
}

# Restore from backup
restore_from_backup() {
    echo -e "${CYAN}💾 Restoring from backup...${NC}"
    echo ""
    
    # Check for different types of backups
    local backup_sources=(
        "$BUILD_DIR/backup"
        "$BUILD_DIR/backup-$(date +%Y%m%d)"
        "$BUILD_DIR/snapshots/latest"
        "$BUILD_DIR/snapshots/$(date +%Y%m%d)"
    )
    
    local backup_found=""
    for backup in "${backup_sources[@]}"; do
        if [ -d "$backup" ]; then
            backup_found="$backup"
            break
        fi
    done
    
    if [ -n "$backup_found" ]; then
        echo -e "${GREEN}Found backup: $backup_found${NC}"
        echo ""
        
        echo "Backup contents:"
        ls -la "$backup_found" | head -20
        
        echo ""
        read -p "Restore from this backup? [y/N]: " restore_confirm
        if [[ "$restore_confirm" =~ ^[Yy]$ ]]; then
            echo "Creating backup of current state..."
            sudo cp -r squashfs "squashfs-broken-$(date +%Y%m%d-%H%M%S)"
            
            echo "Restoring from backup..."
            sudo rm -rf squashfs
            sudo cp -r "$backup_found" squashfs
            
            echo -e "${GREEN}✓ System restored from backup${NC}"
        else
            echo -e "${YELLOW}Restore cancelled${NC}"
        fi
    else
        echo -e "${RED}No backup found in expected locations${NC}"
        echo ""
        echo "Available directories:"
        ls -la "$BUILD_DIR" | grep -E "(backup|snapshot)"
        
        echo ""
        read -p "Enter custom backup path (or press Enter to skip): " custom_backup
        if [ -n "$custom_backup" ] && [ -d "$custom_backup" ]; then
            echo "Restoring from custom backup..."
            sudo rm -rf squashfs
            sudo cp -r "$custom_backup" squashfs
            echo -e "${GREEN}✓ System restored from custom backup${NC}"
        fi
    fi
}

# Reset to clean state
reset_to_clean_state() {
    echo -e "${YELLOW}🚀 Resetting to clean state...${NC}"
    echo ""
    echo -e "${RED}⚠️  WARNING: This will completely reset the system!${NC}"
    echo "All installed packages and configurations will be lost."
    echo ""
    
    read -p "Are you absolutely sure? Type 'YES' to confirm: " reset_confirm
    if [[ "$reset_confirm" == "YES" ]]; then
        echo -e "${CYAN}Resetting system...${NC}"
        
        # Create emergency backup
        if [ -d "squashfs" ]; then
            echo "Creating emergency backup..."
            sudo cp -r squashfs "emergency-backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        # Reset
        sudo rm -rf squashfs
        setup_build_env
        echo -e "${GREEN}✓ System reset to clean state${NC}"
    else
        echo -e "${YELLOW}Reset cancelled${NC}"
    fi
}

# Validate system integrity
validate_system_integrity() {
    echo -e "${CYAN}✅ Validating system integrity...${NC}"
    echo ""
    
    cd "$BUILD_DIR/squashfs"
    
    # Mount chroot filesystems
    mount_chroot_filesystems
    
    local critical_files=(
        "/etc/passwd"
        "/etc/group"
        "/etc/fstab"
        "/etc/hostname"
        "/etc/portage/make.conf"
        "/boot/grub/grub.cfg"
        "/usr/local/bin/raptoros-update"
        "/usr/local/bin/validate-performance"
    )
    
    local missing_files=0
    local total_files=${#critical_files[@]}
    
    echo "Checking critical files..."
    for file in "${critical_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}✗ Missing: $file${NC}"
            missing_files=$((missing_files + 1))
        else
            echo -e "${GREEN}✓ Found: $file${NC}"
        fi
    done
    
    echo ""
    echo "Checking package database..."
    if sudo chroot . emerge --check-news-deps &>/dev/null; then
        echo -e "${GREEN}✓ Package database integrity OK${NC}"
    else
        echo -e "${RED}✗ Package database issues detected${NC}"
        missing_files=$((missing_files + 1))
    fi
    
    echo ""
    echo "Checking RaptorOS configurations..."
    local raptoros_configs=(
        "/etc/portage/env/gcc14-latest"
        "/etc/portage/env/llvm20-mesa25"
        "/etc/portage/package.env/modern-optimizations"
        "/etc/portage/package.accept_keywords/raptoros-minimal-testing"
    )
    
    for config in "${raptoros_configs[@]}"; do
        if [ ! -f "$config" ]; then
            echo -e "${RED}✗ Missing: $config${NC}"
            missing_files=$((missing_files + 1))
        else
            echo -e "${GREEN}✓ Found: $config${NC}"
        fi
    done
    
    echo ""
    echo "═══════════════════════════════"
    echo "Integrity Check Results:"
    echo "Files checked: $total_files"
    echo "Missing files: $missing_files"
    echo "Success rate: $(( (total_files - missing_files) * 100 / total_files ))%"
    
    if [ $missing_files -eq 0 ]; then
        echo -e "${GREEN}🎉 System integrity check PASSED${NC}"
    else
        echo -e "${RED}⚠️  System integrity check FAILED${NC}"
        echo "Consider using recovery options 1, 2, or 6 to fix issues."
    fi
    
    # Unmount chroot filesystems
    unmount_chroot_filesystems
}

# Chroot into existing build
chroot_into_build() {
    echo -e "${CYAN}🖥️  Chroot into existing build...${NC}"
    echo ""
    
    cd "$BUILD_DIR/squashfs"
    
    # Mount necessary filesystems
    mount_chroot_filesystems
    
    echo -e "${GREEN}Entering chroot environment...${NC}"
    echo "Type 'exit' to return to recovery mode"
    echo "Useful commands:"
    echo "  - emerge --resume (resume interrupted emerge)"
    echo "  - emerge @preserved-rebuild (rebuild preserved packages)"
    echo "  - emerge --depclean (clean broken packages)"
    echo "  - system-validator (run system validation)"
    echo ""
    
    sudo chroot . /bin/bash
    
    # Unmount filesystems when exiting
    unmount_chroot_filesystems
    echo -e "${GREEN}Exited chroot environment${NC}"
}

# Reset configurations
reset_configurations() {
    echo -e "${CYAN}🔄 Resetting configurations...${NC}"
    echo ""
    
    cd "$BUILD_DIR/squashfs"
    
    echo "This will reset all RaptorOS configurations to defaults."
    read -p "Continue? [y/N]: " reset_confirm
    if [[ "$reset_confirm" =~ ^[Yy]$ ]]; then
        echo "Resetting configurations..."
        
        # Backup current configs
        if [ -d "etc/portage" ]; then
            sudo cp -r etc/portage "etc/portage-backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        # Reset make.conf
        if [ -f "$SCRIPT_DIR/configs/make.conf" ]; then
            sudo cp "$SCRIPT_DIR/configs/make.conf" "etc/portage/make.conf"
            echo "✓ make.conf reset"
        fi
        
        # Reset package environments
        if [ -d "$SCRIPT_DIR/configs/env" ]; then
            sudo rm -rf etc/portage/env
            sudo mkdir -p etc/portage/env
            sudo cp -r "$SCRIPT_DIR/configs/env/"* etc/portage/env/
            echo "✓ Package environments reset"
        fi
        
        # Reset package environment mappings
        if [ -d "$SCRIPT_DIR/configs/package.env" ]; then
            sudo rm -rf etc/portage/package.env
            sudo mkdir -p etc/portage/package.env
            sudo cp -r "$SCRIPT_DIR/configs/package.env/"* etc/portage/package.env/
            echo "✓ Package environment mappings reset"
        fi
        
        # Reset package accept keywords
        if [ -d "$SCRIPT_DIR/configs/package.accept_keywords" ]; then
            sudo rm -rf etc/portage/package.accept_keywords
            sudo mkdir -p etc/portage/package.accept_keywords
            sudo cp -r "$SCRIPT_DIR/configs/package.accept_keywords/"* etc/portage/package.accept_keywords/
            echo "✓ Package accept keywords reset"
        fi
        
        # Reset gaming configurations
        if [ -f "$SCRIPT_DIR/configs/gamemode.ini" ]; then
            sudo cp "$SCRIPT_DIR/configs/gamemode.ini" "etc/gamemode.ini"
            echo "✓ GameMode configuration reset"
        fi
        
        if [ -f "$SCRIPT_DIR/configs/99-gaming.conf" ]; then
            sudo mkdir -p etc/sysctl.d
            sudo cp "$SCRIPT_DIR/configs/99-gaming.conf" "etc/sysctl.d/99-gaming.conf"
            echo "✓ Gaming sysctl configuration reset"
        fi
        
        echo -e "${GREEN}✓ All configurations reset to defaults${NC}"
    else
        echo -e "${YELLOW}Configuration reset cancelled${NC}"
    fi
}

# Advanced diagnostics
advanced_diagnostics() {
    echo -e "${CYAN}📊 Advanced diagnostics...${NC}"
    echo ""
    
    cd "$BUILD_DIR/squashfs"
    
    # Mount chroot filesystems
    mount_chroot_filesystems
    
    echo "Running comprehensive system diagnostics..."
    echo ""
    
    # Check system status
    echo "=== System Status ==="
    sudo chroot . systemctl --failed 2>/dev/null || echo "No failed services (or not systemd)"
    
    echo ""
    echo "=== Package Issues ==="
    sudo chroot . emerge --check-news-deps 2>&1 | head -20
    
    echo ""
    echo "=== Disk Usage ==="
    sudo chroot . df -h
    
    echo ""
    echo "=== Memory Usage ==="
    sudo chroot . free -h 2>/dev/null || echo "Memory info not available"
    
    echo ""
    echo "=== Recent Logs ==="
    sudo chroot . journalctl --no-pager -n 20 2>/dev/null || echo "Journal logs not available"
    
    # Unmount chroot filesystems
    unmount_chroot_filesystems
}

# Emergency recovery
emergency_recovery() {
    echo -e "${RED}🆘 EMERGENCY RECOVERY MODE${NC}"
    echo ""
    echo -e "${RED}⚠️  This is for critical system failures only!${NC}"
    echo ""
    
    read -p "Are you experiencing a complete system failure? [y/N]: " emergency_confirm
    if [[ "$emergency_confirm" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Initiating emergency recovery...${NC}"
        
        # Create emergency backup
        if [ -d "squashfs" ]; then
            echo "Creating emergency backup..."
            sudo cp -r squashfs "emergency-backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        # Attempt to fix critical issues
        echo "1. Checking filesystem integrity..."
        if [ -d "squashfs" ]; then
            cd squashfs
            sudo find . -type f -name "*.so*" -exec file {} \; 2>/dev/null | grep -i "corrupt\|error" || echo "No corrupted libraries found"
        fi
        
        echo "2. Attempting package database recovery..."
        if [ -d "squashfs" ]; then
            mount_chroot_filesystems
            sudo chroot . emerge --regen 2>/dev/null || echo "Package database recovery failed"
            unmount_chroot_filesystems
        fi
        
        echo "3. Checking for hardware issues..."
        echo "CPU: $(lscpu | grep "Model name" | head -1 | cut -d: -f2 | xargs)"
        echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
        echo "Disk: $(df -h / | tail -1 | awk '{print $1}')"
        
        echo ""
        echo -e "${YELLOW}Emergency recovery completed.${NC}"
        echo "If the system is still broken, consider:"
        echo "1. Complete system reset (option 3)"
        echo "2. Restore from backup (option 2)"
        echo "3. Manual intervention in chroot (option 5)"
    else
        echo -e "${YELLOW}Emergency recovery cancelled${NC}"
    fi
}

# Create backup of the build
create_backup() {
    echo -e "${CYAN}💾 Creating backup of the build...${NC}"
    
    # Create backup directory
    local backup_dir="$BUILD_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$backup_dir"
    
    # Copy the build
    echo "Copying build to backup..."
    sudo cp -r squashfs "$backup_dir/"
    
    # Create a "latest" symlink
    sudo rm -f "$BUILD_DIR/backup-latest"
    sudo ln -s "$(basename "$backup_dir")" "$BUILD_DIR/backup-latest"
    
    # Show backup info
    local backup_size=$(du -sh "$backup_dir" | cut -f1)
    echo -e "${GREEN}✓ Backup created: $backup_dir (${backup_size})${NC}"
    echo "Latest backup: $BUILD_DIR/backup-latest"
    
    # Clean old backups (keep last 3)
    local backup_count=$(find "$BUILD_DIR" -maxdepth 1 -name "backup-*" -type d | wc -l)
    if [ $backup_count -gt 3 ]; then
        echo "Cleaning old backups..."
        find "$BUILD_DIR" -maxdepth 1 -name "backup-*" -type d -printf '%T@ %p\n' | sort -n | head -n $((backup_count - 3)) | cut -d' ' -f2- | xargs -r sudo rm -rf
        echo "✓ Old backups cleaned"
    fi
}

# Mount chroot filesystems
mount_chroot_filesystems() {
    echo "Mounting chroot filesystems..."
    sudo mount -t proc /proc proc 2>/dev/null || true
    sudo mount --rbind /sys sys 2>/dev/null || true
    sudo mount --rbind /dev dev 2>/dev/null || true
    sudo mount --bind /run run 2>/dev/null || true
    sudo cp -L /etc/resolv.conf etc/ 2>/dev/null || true
}

# Unmount chroot filesystems
unmount_chroot_filesystems() {
    echo "Unmounting chroot filesystems..."
    sudo umount -l proc 2>/dev/null || true
    sudo umount -l sys 2>/dev/null || true
    sudo umount -l dev 2>/dev/null || true
    sudo umount -l run 2>/dev/null || true
}

# Main execution
main() {
    local start_time=$(start_timer)
    
    show_banner
    check_requirements
    detect_build_resources  # Add resource detection
    detect_hardware
    ensure_swap  # Add swap management
    select_stage3
    show_build_menu
    
    local end_time=$(end_timer "$start_time")
    log_success "Build process completed in: $end_time"
}

# Enhanced signal handling and cleanup (single handlers to prevent conflicts)
trap cleanup_on_signal INT TERM
trap force_cleanup_chroot EXIT

# Run if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
