#!/bin/bash
# RaptorOS ISO Boot Support Module
# Handles initramfs generation, bootloader configuration, and live system setup

# Source colors and functions if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

if [ -f "$(dirname "${BASH_SOURCE[0]}")/functions.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"
fi

# ISO boot configuration
ISO_BOOT_CONFIG="/tmp/raptoros-iso-boot.conf"

# Generate proper initramfs for live system
generate_initramfs() {
    local squashfs_dir="$1"
    local output_file="$2"
    
    log_info "Generating initramfs for live system..."
    
    # Create temporary directory for initramfs
    local initramfs_dir="/tmp/raptoros-initramfs"
    rm -rf "$initramfs_dir"
    mkdir -p "$initramfs_dir"
    
    # Create basic initramfs structure
    mkdir -p "$initramfs_dir"/{bin,dev,etc,lib,lib64,mnt,proc,root,run,sbin,sys,tmp,usr}
    
    # Copy essential binaries and libraries
    local essential_bins=(
        "/bin/busybox" "/bin/sh" "/bin/mount" "/bin/umount"
        "/bin/cat" "/bin/echo" "/bin/ls" "/bin/mkdir"
        "/bin/rm" "/bin/cp" "/bin/mv" "/bin/ln"
        "/bin/dd" "/bin/grep" "/bin/sed" "/bin/awk"
        "/bin/sleep" "/bin/sync" "/bin/true" "/bin/false"
    )
    
    for bin in "${essential_bins[@]}"; do
        if [ -f "$squashfs_dir$bin" ]; then
            cp "$squashfs_dir$bin" "$initramfs_dir$bin"
        elif [ -f "$squashfs_dir/usr$bin" ]; then
            cp "$squashfs_dir/usr$bin" "$initramfs_dir$bin"
        fi
    done
    
    # Copy essential libraries
    local essential_libs=(
        "/lib/ld-linux-x86-64.so.2"
        "/lib/libc.so.6"
        "/lib/libm.so.6"
        "/lib/libdl.so.2"
        "/lib/libpthread.so.0"
        "/lib/libcrypt.so.1"
        "/lib/libresolv.so.2"
        "/lib/libnss_files.so.2"
        "/lib/libnss_dns.so.2"
    )
    
    for lib in "${essential_libs[@]}"; do
        if [ -f "$squashfs_dir$lib" ]; then
            mkdir -p "$(dirname "$initramfs_dir$lib")"
            cp "$squashfs_dir$lib" "$initramfs_dir$lib"
        fi
    done
    
    # Create init script for live system
    cat > "$initramfs_dir/init" << 'INIT_SCRIPT'
#!/bin/sh
# RaptorOS Live System Init Script

# Set up basic environment
export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export HOME="/root"
export TERM="linux"

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs none /tmp

# Create device nodes
mkdir -p /dev/pts
mount -t devpts none /dev/pts

# Set up console
exec < /dev/console
exec > /dev/console
exec 2> /dev/console

echo "RaptorOS Live System Starting..."
echo "Mounting root filesystem..."

# Mount the squashfs root
if [ -f /dev/ram0 ]; then
    mount -t squashfs /dev/ram0 /mnt/root
else
    # Try to find the squashfs on other devices
    for device in /dev/sr0 /dev/loop0 /dev/loop1; do
        if [ -b "$device" ]; then
            mount -t squashfs "$device" /mnt/root 2>/dev/null && break
        fi
    done
fi

if [ ! -d /mnt/root/etc ]; then
    echo "ERROR: Could not mount root filesystem!"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

# Pivot to the new root
cd /mnt/root
pivot_root . mnt
exec chroot . /sbin/init
INIT_SCRIPT
    
    chmod +x "$initramfs_dir/init"
    
    # Create fstab for initramfs
    cat > "$initramfs_dir/etc/fstab" << 'FSTAB'
proc            /proc           proc    defaults        0       0
sysfs           /sys            sysfs   defaults        0       0
devtmpfs        /dev            devtmpfs defaults       0       0
tmpfs           /tmp            tmpfs   defaults        0       0
FSTAB
    
    # Create basic configuration
    cat > "$initramfs_dir/etc/hostname" << 'HOSTNAME'
raptoros-live
HOSTNAME
    
    # Build the initramfs
    log_info "Building initramfs..."
    cd "$initramfs_dir"
    
    if command -v find &> /dev/null && command -v cpio &> /dev/null; then
        find . | cpio -o -H newc | gzip -9 > "$output_file"
    else
        # Fallback to basic tar method
        tar -czf "$output_file" .
    fi
    
    # Cleanup
    cd /
    rm -rf "$initramfs_dir"
    
    log_success "Initramfs generated: $(numfmt --to=iec $(stat -c%s "$output_file"))"
}

# Configure GRUB bootloader
configure_grub() {
    local iso_dir="$1"
    local kernel_path="$2"
    local initramfs_path="$3"
    
    log_info "Configuring GRUB bootloader..."
    
    # Create GRUB directory structure
    mkdir -p "$iso_dir/boot/grub"
    
    # Copy GRUB modules if available
    local grub_modules=(
        "biosdisk" "part_gpt" "part_msdos" "ext2" "fat" "iso9660"
        "squash4" "xfs" "btrfs" "search" "search_fs_file"
        "search_fs_uuid" "search_label" "normal" "linux" "linux16"
        "initrd" "initrd16" "configfile" "menuentry" "set"
    )
    
    # Try to find GRUB modules
    local grub_mod_dir=""
    for dir in "/usr/lib/grub/x86_64-efi" "/usr/lib/grub/i386-pc" "/usr/share/grub/x86_64-efi"; do
        if [ -d "$dir" ]; then
            grub_mod_dir="$dir"
            break
        fi
    done
    
    if [ -n "$grub_mod_dir" ]; then
        log_info "Found GRUB modules in: $grub_mod_dir"
        mkdir -p "$iso_dir/boot/grub/x86_64-efi"
        cp -r "$grub_mod_dir"/* "$iso_dir/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi
    
    # Create GRUB configuration
    cat > "$iso_dir/boot/grub/grub.cfg" << GRUB_CFG
set timeout=10
set default=0
set gfxmode=auto
set gfxpayload=keep

# Load fonts and themes if available
if [ -f /boot/grub/fonts/unicode.pf2 ]; then
    loadfont unicode
fi

# Set background image if available
if [ -f /boot/grub/background.png ]; then
    set background_image=/boot/grub/background.png
fi

# Main boot menu
menuentry "RaptorOS Gaming Live System" {
    set gfxpayload=keep
    linux $kernel_path root=/dev/ram0 init=/init quiet splash nomodeset
    initrd $initramfs_path
}

menuentry "RaptorOS Gaming Live System (Safe Mode)" {
    set gfxpayload=text
    linux $kernel_path root=/dev/ram0 init=/init single nomodeset
    initrd $initramfs_path
}

menuentry "RaptorOS Gaming Live System (Debug Mode)" {
    set gfxpayload=text
    linux $kernel_path root=/dev/ram0 init=/init debug nomodeset
    initrd $initramfs_path
}

menuentry "RaptorOS Gaming Live System (Install Mode)" {
    set gfxpayload=keep
    linux $kernel_path root=/dev/ram0 init=/init install quiet splash nomodeset
    initrd $initramfs_path
}

# Fallback entries
menuentry "RaptorOS Recovery Mode" {
    set gfxpayload=text
    linux $kernel_path root=/dev/ram0 init=/init recovery nomodeset
    initrd $initramfs_path
}

# Advanced options
submenu "Advanced Options" {
    menuentry "Memory Test" {
        memtest86+
    }
    
    menuentry "Boot from first hard disk" {
        set root=(hd0,1)
        chainloader +1
    }
}
GRUB_CFG
    
    # Create GRUB environment file
    cat > "$iso_dir/boot/grub/grubenv" << GRUB_ENV
# GRUB Environment Block
# This file is automatically generated
GRUB_ENV
    
    log_success "GRUB configuration created"
}

# Configure EFI boot support
configure_efi_boot() {
    local iso_dir="$1"
    local kernel_path="$2"
    local initramfs_path="$3"
    
    log_info "Configuring EFI boot support..."
    
    # Create EFI directory structure
    mkdir -p "$iso_dir/EFI/BOOT"
    
    # Copy EFI bootloader if available
    local efi_bootloaders=(
        "/usr/lib/systemd/boot-efi/systemd-bootx64.efi"
        "/usr/lib/grub/x86_64-efi/grub.efi"
        "/usr/share/grub/x86_64-efi/grub.efi"
    )
    
    local efi_bootloader=""
    for loader in "${efi_bootloaders[@]}"; do
        if [ -f "$loader" ]; then
            efi_bootloader="$loader"
            break
        fi
    done
    
    if [ -n "$efi_bootloader" ]; then
        log_info "Found EFI bootloader: $efi_bootloader"
        cp "$efi_bootloader" "$iso_dir/EFI/BOOT/BOOTX64.EFI"
        
        # Create EFI configuration
        cat > "$iso_dir/EFI/BOOT/grub.cfg" << EFI_GRUB_CFG
set timeout=10
set default=0

menuentry "RaptorOS Gaming Live System (EFI)" {
    linux $kernel_path root=/dev/ram0 init=/init quiet splash nomodeset
    initrd $initramfs_path
}

menuentry "RaptorOS Gaming Live System (EFI Safe Mode)" {
    linux $kernel_path root=/dev/ram0 init=/init single nomodeset
    initrd $initramfs_path
}
EFI_GRUB_CFG
        
        log_success "EFI boot support configured"
    else
        log_warning "No EFI bootloader found, EFI boot support disabled"
    fi
}

# Create live system startup scripts
create_live_system_scripts() {
    local squashfs_dir="$1"
    
    log_info "Creating live system startup scripts..."
    
    # Create systemd service for live system
    if [ -d "$squashfs_dir/etc/systemd" ]; then
        mkdir -p "$squashfs_dir/etc/systemd/system"
        
        cat > "$squashfs_dir/etc/systemd/system/raptoros-live.service" << 'LIVE_SERVICE'
[Unit]
Description=RaptorOS Live System Setup
After=network.target
Before=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/raptoros-live-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
LIVE_SERVICE
        
        # Enable the service
        ln -sf "$squashfs_dir/etc/systemd/system/raptoros-live.service" \
               "$squashfs_dir/etc/systemd/system/multi-user.target.wants/"
    fi
    
    # Create OpenRC service for live system
    if [ -d "$squashfs_dir/etc/init.d" ]; then
        cat > "$squashfs_dir/etc/init.d/raptoros-live" << 'LIVE_INIT'
#!/sbin/openrc-run

depend() {
    need net
    before xdm
}

start() {
    ebegin "Starting RaptorOS Live System"
    /usr/local/bin/raptoros-live-setup
    eend $?
}

stop() {
    ebegin "Stopping RaptorOS Live System"
    eend 0
}
LIVE_INIT
        
        chmod +x "$squashfs_dir/etc/init.d/raptoros-live"
        
        # Add to default runlevel
        ln -sf "$squashfs_dir/etc/init.d/raptoros-live" \
               "$squashfs_dir/etc/runlevels/default/"
    fi
    
    # Create live system setup script
    cat > "$squashfs_dir/usr/local/bin/raptoros-live-setup" << 'LIVE_SETUP'
#!/bin/bash
# RaptorOS Live System Setup Script

set -e

# Source environment
source /etc/profile

# Set up live system environment
export RAPTOROS_LIVE="true"
export RAPTOROS_VERSION="$(cat /etc/raptoros-version 2>/dev/null || echo 'unknown')"

# Create live user if it doesn't exist
if ! id "live" &>/dev/null; then
    useradd -m -s /bin/bash -G wheel,audio,video,usb live
    echo "live:live" | chpasswd
    echo "live user created with password: live"
fi

# Set up auto-login for live user
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    systemctl enable getty@tty1.service
fi

# Start display manager if available
if command -v startx &>/dev/null; then
    if [ "$(tty)" = "/dev/tty1" ]; then
        startx -- -nocursor
    fi
fi

# Show welcome message
cat << 'WELCOME'
╔══════════════════════════════════════════════════════════╗
║          Welcome to RaptorOS Gaming Live System          ║
║         Optimized for Intel i9-14900K + RTX 4090         ║
║                                                            ║
║  Type 'install_gentoo' to start the installation          ║
║                                                            ║
║  Default credentials: live/live                           ║
╚══════════════════════════════════════════════════════════╝
WELCOME
LIVE_SETUP
    
    chmod +x "$squashfs_dir/usr/local/bin/raptoros-live-setup"
    
    # Create version file
    echo "$(date +%Y%m%d)" > "$squashfs_dir/etc/raptoros-version"
    
    log_success "Live system startup scripts created"
}

# Validate boot configuration
validate_boot_config() {
    local iso_dir="$1"
    
    log_info "Validating boot configuration..."
    
    local required_boot_files=(
        "boot/vmlinuz"
        "boot/initramfs"
        "boot/grub/grub.cfg"
    )
    
    for file in "${required_boot_files[@]}"; do
        local full_path="$iso_dir/$file"
        if [ ! -f "$full_path" ]; then
            die "Missing required boot file: $file"
        fi
        log_success "Found: $file"
    done
    
    # Check kernel file
    local kernel_file="$iso_dir/boot/vmlinuz"
    if [ ! -s "$kernel_file" ]; then
        die "Kernel file is empty or invalid: $kernel_file"
    fi
    
    # Check initramfs file
    local initramfs_file="$iso_dir/boot/initramfs"
    if [ ! -s "$initramfs_file" ]; then
        die "Initramfs file is empty or invalid: $initramfs_file"
    fi
    
    log_success "Boot configuration validation passed"
}

# Main function to set up complete boot support
setup_complete_boot_support() {
    local squashfs_dir="$1"
    local iso_dir="$2"
    local kernel_path="$3"
    
    log_info "Setting up complete boot support..."
    
    # Generate initramfs
    local initramfs_path="$iso_dir/boot/initramfs"
    generate_initramfs "$squashfs_dir" "$initramfs_path"
    
    # Configure GRUB
    configure_grub "$iso_dir" "$kernel_path" "$initramfs_path"
    
    # Configure EFI boot
    configure_efi_boot "$iso_dir" "$kernel_path" "$initramfs_path"
    
    # Create live system scripts
    create_live_system_scripts "$squashfs_dir"
    
    # Validate configuration
    validate_boot_config "$iso_dir"
    
    log_success "Complete boot support configured"
}
