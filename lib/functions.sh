#!/bin/bash
# RaptorOS Build Script Functions Library
# Provides utility functions for building, validation, and error handling

# Source colors if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Error handling and logging
set -euo pipefail

# Global variables
BUILD_LOG="/var/tmp/raptoros-build.log"
ERROR_LOG="/var/tmp/raptoros-errors.log"

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$BUILD_LOG"
    
    case $level in
        "ERROR")
            echo "[$timestamp] [$level] $message" >> "$ERROR_LOG"
            ;;
    esac
}

log_info() {
    log_message "INFO" "$1"
    print_info "$1"
}

log_success() {
    log_message "SUCCESS" "$1"
    print_success "$1"
}

log_warning() {
    log_message "WARNING" "$1"
    print_warning "$1"
}

log_error() {
    log_message "ERROR" "$1"
    print_error "$1"
}

# Error handling
die() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "FATAL ERROR: $message"
    print_error "Build failed: $message"
    
    # Cleanup on exit
    cleanup_on_exit
    
    exit "$exit_code"
}

trap 'die "Unexpected error occurred" 1' ERR

# Cleanup function
cleanup_on_exit() {
    log_info "Performing cleanup..."
    
    # Unmount any mounted filesystems
    cleanup_chroot 2>/dev/null || true
    
    # Remove temporary files
    rm -f /tmp/raptoros-* 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Validation functions
validate_file() {
    local file="$1"
    local description="${2:-file}"
    
    if [ ! -f "$file" ]; then
        die "$description not found: $file"
    fi
    
    if [ ! -r "$file" ]; then
        die "$description not readable: $file"
    fi
}

validate_directory() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [ ! -d "$dir" ]; then
        die "$description not found: $dir"
    fi
    
    if [ ! -r "$dir" ]; then
        die "$description not readable: $dir"
    fi
}

validate_command() {
    local cmd="$1"
    local description="${2:-command}"
    
    if ! command -v "$cmd" &> /dev/null; then
        die "$description not found: $cmd"
    fi
}

# System validation
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check for required commands
    local required_commands=(
        "wget" "git" "mksquashfs" "xorriso" "parted" 
        "mkfs.fat" "btrfs" "dialog" "sudo" "mount"
    )
    
    for cmd in "${required_commands[@]}"; do
        validate_command "$cmd" "Required command"
        log_success "Found: $cmd"
    done
    
    # Check disk space
    local required_space=50 # GB
    local available_space=$(df /var/tmp | awk 'NR==2 {print int($4/1048576)}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        die "Insufficient disk space. Need at least ${required_space}GB, available: ${available_space}GB"
    fi
    
    log_success "Disk space: ${available_space}GB available"
    
    # Check memory
    local required_memory=4 # GB
    local available_memory=$(free -g | awk '/^Mem:/{print $2}')
    
    if [ "$available_memory" -lt "$required_memory" ]; then
        die "Insufficient memory. Need at least ${required_memory}GB, available: ${available_memory}GB"
    fi
    
    log_success "Memory: ${available_memory}GB available"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        die "This script must be run as root (use sudo)"
    fi
    
    log_success "System requirements validation passed"
}

# Package management functions
install_package() {
    local package="$1"
    local description="${2:-package}"
    
    log_info "Installing $description: $package"
    
    if command -v pacman &> /dev/null; then
        # Arch-based systems
        pacman -S --noconfirm "$package" || die "Failed to install $description"
    elif command -v apt-get &> /dev/null; then
        # Debian-based systems
        apt-get update && apt-get install -y "$package" || die "Failed to install $description"
    elif command -v dnf &> /dev/null; then
        # Fedora-based systems
        dnf install -y "$package" || die "Failed to install $description"
    elif command -v emerge &> /dev/null; then
        # Gentoo systems
        emerge --quiet "$package" || die "Failed to install $description"
    else
        die "No supported package manager found"
    fi
    
    log_success "Installed $description: $package"
}

# Network functions
check_internet_connection() {
    log_info "Checking internet connection..."
    
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        die "No internet connection available"
    fi
    
    log_success "Internet connection available"
}

# File operations
safe_copy() {
    local source="$1"
    local destination="$2"
    local description="${3:-file}"
    
    log_info "Copying $description: $source -> $destination"
    
    if ! cp -r "$source" "$destination"; then
        die "Failed to copy $description: $source -> $destination"
    fi
    
    log_success "Copied $description successfully"
}

safe_mkdir() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [ ! -d "$dir" ]; then
        log_info "Creating $description: $dir"
        if ! mkdir -p "$dir"; then
            die "Failed to create $description: $dir"
        fi
        log_success "Created $description: $dir"
    fi
}

# Backup functions
create_backup() {
    local source="$1"
    local backup_dir="$2"
    local backup_name="$3"
    
    local backup_path="$backup_dir/${backup_name}-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating backup: $backup_path"
    
    safe_mkdir "$backup_dir" "backup directory"
    
    if ! cp -r "$source" "$backup_path"; then
        die "Failed to create backup: $source -> $backup_path"
    fi
    
    # Create latest symlink
    local latest_link="$backup_dir/latest"
    rm -f "$latest_link" 2>/dev/null || true
    ln -sf "$(basename "$backup_path")" "$latest_link"
    
    log_success "Backup created: $backup_path"
    echo "$backup_path"
}

# Performance monitoring
start_timer() {
    echo "$(date +%s)"
}

end_timer() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}

# Progress tracking
init_progress() {
    local total_steps="$1"
    echo "0" > /tmp/raptoros-progress
    echo "$total_steps" > /tmp/raptoros-total
}

update_progress() {
    local current_step="$1"
    local total_steps=$(cat /tmp/raptoros-total 2>/dev/null || echo "1")
    
    echo "$current_step" > /tmp/raptoros-progress
    
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ]; then
        show_progress "$current_step" "$total_steps"
    fi
}

# System information
get_system_info() {
    local info_file="/tmp/raptoros-system-info.txt"
    
    {
        echo "=== System Information ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
        echo "CPU Cores: $(nproc)"
        echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
        echo "Disk: $(df -h / | tail -1 | awk '{print $1}')"
        echo "Available Space: $(df -h /var/tmp | awk 'NR==2 {print $4}')"
        echo "User: $(whoami)"
        echo "EUID: $EUID"
    } > "$info_file"
    
    echo "$info_file"
}

# Validation helpers
validate_gentoo_stage3() {
    local stage3_file="$1"
    
    log_info "Validating Gentoo stage3 file: $stage3_file"
    
    # Check if file exists and is readable
    validate_file "$stage3_file" "Stage3 file"
    
    # Check file size (should be at least 100MB)
    local file_size=$(stat -c%s "$stage3_file")
    local min_size=$((100 * 1024 * 1024)) # 100MB
    
    if [ "$file_size" -lt "$min_size" ]; then
        die "Stage3 file too small: $(numfmt --to=iec $file_size) (minimum: $(numfmt --to=iec $min_size))"
    fi
    
    # Check if it's a valid tar.xz file
    if ! tar -tJf "$stage3_file" &> /dev/null; then
        die "Invalid tar.xz file: $stage3_file"
    fi
    
    log_success "Stage3 file validation passed: $(numfmt --to=iec $file_size)"
}

# ISO validation
validate_iso_structure() {
    local iso_dir="$1"
    
    log_info "Validating ISO structure: $iso_dir"
    
    local required_files=(
        "boot/vmlinuz"
        "boot/initramfs"
        "boot/grub/grub.cfg"
        "gentoo.squashfs"
    )
    
    for file in "${required_files[@]}"; do
        local full_path="$iso_dir/$file"
        if [ ! -f "$full_path" ]; then
            die "Missing required ISO file: $file"
        fi
        log_success "Found: $file"
    done
    
    log_success "ISO structure validation passed"
}
