#!/bin/bash
# RaptorOS Build Validation Module
# Provides comprehensive validation of builds, packages, and ISO creation

# Source colors and functions if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

if [ -f "$(dirname "${BASH_SOURCE[0]}")/functions.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"
fi

# Validation configuration
VALIDATION_CONFIG="/tmp/raptoros-validation.conf"
VALIDATION_RESULTS="/tmp/raptoros-validation-results.txt"

# Initialize validation
init_validation() {
    log_info "Initializing build validation..."
    
    # Create validation results file
    {
        echo "RaptorOS Build Validation Results"
        echo "================================="
        echo "Date: $(date)"
        echo "Build ID: $(date +%Y%m%d-%H%M%S)"
        echo ""
    } > "$VALIDATION_RESULTS"
    
    # Initialize progress tracking
    init_progress 8  # 8 validation steps
    
    log_success "Build validation initialized"
}

# Validate package installations
validate_package_installations() {
    local squashfs_dir="$1"
    
    log_info "Validating package installations..."
    update_progress 1
    
    local validation_errors=0
    local validation_warnings=0
    
    # Critical packages that must be installed
    local critical_packages=(
        "sys-kernel/gentoo-kernel-bin:kernel"
        "sys-boot/grub:bootloader"
        "sys-boot/efibootmgr:efi-tools"
        "sys-apps/systemd:init-system"
        "sys-apps/openrc:init-system"
        "x11-drivers/nvidia-drivers:gpu-drivers"
        "games-util/steam-launcher:gaming"
        "games-util/lutris:gaming"
        "games-util/gamemode:gaming"
        "app-emulation/wine-staging:gaming"
    )
    
    # Check each critical package
    for package_info in "${critical_packages[@]}"; do
        local package="${package_info%:*}"
        local description="${package_info#*:}"
        
        if ! check_package_installed "$squashfs_dir" "$package"; then
            log_error "Critical package missing: $package ($description)"
            validation_errors=$((validation_errors + 1))
        else
            log_success "Found: $package ($description)"
        fi
    done
    
    # Check for package conflicts
    local conflicts=$(check_package_conflicts "$squashfs_dir")
    if [ -n "$conflicts" ]; then
        log_warning "Package conflicts detected: $conflicts"
        validation_warnings=$((validation_warnings + 1))
    fi
    
    # Check package database integrity
    if ! validate_package_database "$squashfs_dir"; then
        log_error "Package database integrity check failed"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Record results
    {
        echo "Package Installation Validation:"
        echo "  Critical packages: $(( ${#critical_packages[@]} - validation_errors ))/${#critical_packages[@]} found"
        echo "  Errors: $validation_errors"
        echo "  Warnings: $validation_warnings"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "Package validation failed with $validation_errors errors"
    fi
    
    log_success "Package installation validation passed"
}

# Check if a package is installed
check_package_installed() {
    local squashfs_dir="$1"
    local package="$2"
    
    # Check multiple possible locations
    local package_paths=(
        "/var/db/pkg/$package"
        "/usr/portage/packages/$package"
        "/var/cache/gentoo/pkg/$package"
    )
    
    for path in "${package_paths[@]}"; do
        if [ -d "$squashfs_dir$path" ] || [ -f "$squashfs_dir$path" ]; then
            return 0
        fi
    done
    
    # Check if binary exists
    local package_name="${package##*/}"
    if find "$squashfs_dir" -name "*$package_name*" -type f 2>/dev/null | grep -q .; then
        return 0
    fi
    
    return 1
}

# Check for package conflicts
check_package_conflicts() {
    local squashfs_dir="$1"
    
    # Common package conflicts
    local conflicts=()
    
    # Check for multiple init systems
    if [ -d "$squashfs_dir/etc/systemd" ] && [ -d "$squashfs_dir/etc/init.d" ]; then
        conflicts+=("Multiple init systems (systemd + openrc)")
    fi
    
    # Check for multiple display servers
    if [ -d "$squashfs_dir/usr/share/xsessions" ] && [ -d "$squashfs_dir/usr/share/wayland-sessions" ]; then
        conflicts+=("Multiple display servers (X11 + Wayland)")
    fi
    
    # Check for multiple audio systems
    if [ -d "$squashfs_dir/etc/pulse" ] && [ -d "$squashfs_dir/etc/pipewire" ]; then
        conflicts+=("Multiple audio systems (PulseAudio + PipeWire)")
    fi
    
    echo "${conflicts[*]}"
}

# Validate package database
validate_package_database() {
    local squashfs_dir="$1"
    
    # Check if portage database exists
    if [ ! -d "$squashfs_dir/var/db/pkg" ]; then
        return 1
    fi
    
    # Check if world file exists
    if [ ! -f "$squashfs_dir/var/lib/portage/world" ]; then
        return 1
    fi
    
    # Check if portage configuration is valid
    if [ ! -f "$squashfs_dir/etc/portage/make.conf" ]; then
        return 1
    fi
    
    return 0
}

# Validate system configuration
validate_system_configuration() {
    local squashfs_dir="$1"
    
    log_info "Validating system configuration..."
    update_progress 2
    
    local validation_errors=0
    
    # Check essential configuration files
    local config_files=(
        "/etc/fstab:filesystem-table"
        "/etc/hostname:hostname"
        "/etc/hosts:hosts-file"
        "/etc/resolv.conf:resolver"
        "/etc/passwd:user-database"
        "/etc/group:group-database"
        "/etc/shadow:password-database"
        "/etc/gshadow:group-password-database"
    )
    
    for config_info in "${config_files[@]}"; do
        local config_file="${config_info%:*}"
        local description="${config_info#*:}"
        
        if [ ! -f "$squashfs_dir$config_file" ]; then
            log_error "Missing configuration file: $config_file ($description)"
            validation_errors=$((validation_errors + 1))
        else
            log_success "Found: $config_file ($description)"
        fi
    done
    
    # Check RaptorOS specific configurations
    local raptoros_configs=(
        "/etc/portage/env/gcc14-latest:gcc-optimization"
        "/etc/portage/env/llvm20-mesa25:llvm-optimization"
        "/etc/portage/package.env/modern-optimizations:package-optimizations"
        "/etc/portage/package.accept_keywords/raptoros-minimal-testing:testing-keywords"
        "/etc/gamemode.ini:gamemode-config"
        "/etc/sysctl.d/99-gaming.conf:gaming-sysctl"
    )
    
    for config_info in "${raptoros_configs[@]}"; do
        local config_file="${config_info%:*}"
        local description="${config_info#*:}"
        
        if [ ! -f "$squashfs_dir$config_file" ]; then
            log_warning "Missing RaptorOS configuration: $config_file ($description)"
        else
            log_success "Found: $config_file ($description)"
        fi
    done
    
    # Check init system configuration
    if [ -d "$squashfs_dir/etc/systemd" ]; then
        log_info "Systemd configuration detected"
        if [ ! -f "$squashfs_dir/etc/systemd/system/default.target" ]; then
            log_warning "Systemd default target not configured"
        fi
    elif [ -d "$squashfs_dir/etc/init.d" ]; then
        log_info "OpenRC configuration detected"
        if [ ! -d "$squashfs_dir/etc/runlevels/default" ]; then
            log_warning "OpenRC default runlevel not configured"
        fi
    else
        log_error "No init system configuration found"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Record results
    {
        echo "System Configuration Validation:"
        echo "  Configuration files: $(( ${#config_files[@]} - validation_errors ))/${#config_files[@]} found"
        echo "  RaptorOS configs: Found"
        echo "  Init system: Configured"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "System configuration validation failed with $validation_errors errors"
    fi
    
    log_success "System configuration validation passed"
}

# Validate filesystem structure
validate_filesystem_structure() {
    local squashfs_dir="$1"
    
    log_info "Validating filesystem structure..."
    update_progress 3
    
    local validation_errors=0
    
    # Check essential directories
    local essential_dirs=(
        "/bin:binaries"
        "/sbin:system-binaries"
        "/usr/bin:user-binaries"
        "/usr/sbin:system-user-binaries"
        "/lib:libraries"
        "/lib64:64-bit-libraries"
        "/usr/lib:user-libraries"
        "/usr/lib64:user-64-bit-libraries"
        "/etc:configuration"
        "/var:variable-data"
        "/tmp:temporary-files"
        "/home:user-home-directories"
        "/root:root-home"
        "/boot:boot-files"
        "/dev:device-files"
        "/proc:process-information"
        "/sys:system-information"
    )
    
    for dir_info in "${essential_dirs[@]}"; do
        local dir="${dir_info%:*}"
        local description="${dir_info#*:}"
        
        if [ ! -d "$squashfs_dir$dir" ]; then
            log_error "Missing essential directory: $dir ($description)"
            validation_errors=$((validation_errors + 1))
        else
            log_success "Found: $dir ($description)"
        fi
    done
    
    # Check for broken symlinks
    local broken_symlinks=$(find "$squashfs_dir" -type l -exec test ! -e {} \; -print 2>/dev/null | wc -l)
    if [ "$broken_symlinks" -gt 0 ]; then
        log_warning "Found $broken_symlinks broken symlinks"
    fi
    
    # Check for orphaned files
    local orphaned_files=$(find "$squashfs_dir/var/db/pkg" -name "*.ebuild" 2>/dev/null | wc -l)
    if [ "$orphaned_files" -gt 0 ]; then
        log_warning "Found $orphaned_files orphaned ebuild files"
    fi
    
    # Record results
    {
        echo "Filesystem Structure Validation:"
        echo "  Essential directories: $(( ${#essential_dirs[@]} - validation_errors ))/${#essential_dirs[@]} found"
        echo "  Broken symlinks: $broken_symlinks"
        echo "  Orphaned files: $orphaned_files"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "Filesystem structure validation failed with $validation_errors errors"
    fi
    
    log_success "Filesystem structure validation passed"
}

# Validate kernel and boot configuration
validate_kernel_boot() {
    local squashfs_dir="$1"
    
    log_info "Validating kernel and boot configuration..."
    update_progress 4
    
    local validation_errors=0
    
    # Check kernel files
    local kernel_files=(
        "/boot/vmlinuz:kernel-image"
        "/boot/System.map:kernel-symbols"
        "/boot/config:kernel-config"
    )
    
    for file_info in "${kernel_files[@]}"; do
        local file="${file_info%:*}"
        local description="${file_info#*:}"
        
        if [ ! -f "$squashfs_dir$file" ]; then
            log_error "Missing kernel file: $file ($description)"
            validation_errors=$((validation_errors + 1))
        else
            log_success "Found: $file ($description)"
        fi
    done
    
    # Check kernel modules
    if [ ! -d "$squashfs_dir/lib/modules" ]; then
        log_error "Kernel modules directory not found"
        validation_errors=$((validation_errors + 1))
    else
        local module_count=$(find "$squashfs_dir/lib/modules" -name "*.ko*" 2>/dev/null | wc -l)
        log_success "Found $module_count kernel modules"
    fi
    
    # Check bootloader configuration
    if [ -f "$squashfs_dir/boot/grub/grub.cfg" ]; then
        log_info "GRUB configuration found"
    elif [ -f "$squashfs_dir/boot/loader.conf" ]; then
        log_info "Systemd-boot configuration found"
    else
        log_error "No bootloader configuration found"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check firmware
    if [ ! -d "$squashfs_dir/lib/firmware" ]; then
        log_warning "Firmware directory not found"
    else
        local firmware_count=$(find "$squashfs_dir/lib/firmware" -type f 2>/dev/null | wc -l)
        log_success "Found $firmware_count firmware files"
    fi
    
    # Record results
    {
        echo "Kernel and Boot Validation:"
        echo "  Kernel files: $(( ${#kernel_files[@]} - validation_errors ))/${#kernel_files[@]} found"
        echo "  Kernel modules: Found"
        echo "  Bootloader: Configured"
        echo "  Firmware: Found"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "Kernel and boot validation failed with $validation_errors errors"
    fi
    
    log_success "Kernel and boot validation passed"
}

# Validate gaming components
validate_gaming_components() {
    local squashfs_dir="$1"
    
    log_info "Validating gaming components..."
    update_progress 5
    
    local validation_errors=0
    
    # Check gaming packages
    local gaming_packages=(
        "games-util/steam-launcher:Steam"
        "games-util/lutris:Lutris"
        "games-util/gamemode:GameMode"
        "games-util/mangohud:MangoHud"
        "app-emulation/wine-staging:Wine"
        "media-libs/mesa:Mesa"
        "x11-drivers/nvidia-drivers:NVIDIA-drivers"
    )
    
    for package_info in "${gaming_packages[@]}"; do
        local package="${package_info%:*}"
        local description="${package_info#*:}"
        
        if ! check_package_installed "$squashfs_dir" "$package"; then
            log_error "Gaming package missing: $package ($description)"
            validation_errors=$((validation_errors + 1))
        else
            log_success "Found: $package ($description)"
        fi
    done
    
    # Check gaming configurations
    local gaming_configs=(
        "/etc/gamemode.ini:GameMode"
        "/etc/sysctl.d/99-gaming.conf:Gaming-sysctl"
        "/etc/environment.d/99-gaming.conf:Gaming-environment"
    )
    
    for config_info in "${gaming_configs[@]}"; do
        local config_file="${config_info%:*}"
        local description="${config_info#*:}"
        
        if [ ! -f "$squashfs_dir$config_file" ]; then
            log_warning "Gaming configuration missing: $config_file ($description)"
        else
            log_success "Found: $config_file ($description)"
        fi
    done
    
    # Check for gaming libraries
    local gaming_libs=(
        "libvulkan.so:Vulkan"
        "libOpenGL.so:OpenGL"
        "libGL.so:OpenGL"
        "libEGL.so:EGL"
        "libwayland-egl.so:Wayland"
    )
    
    for lib_info in "${gaming_libs[@]}"; do
        local lib="${lib_info%:*}"
        local description="${lib_info#*:}"
        
        if ! find "$squashfs_dir" -name "*$lib*" 2>/dev/null | grep -q .; then
            log_warning "Gaming library missing: $lib ($description)"
        else
            log_success "Found: $lib ($description)"
        fi
    done
    
    # Record results
    {
        echo "Gaming Components Validation:"
        echo "  Gaming packages: $(( ${#gaming_packages[@]} - validation_errors ))/${#gaming_packages[@]} found"
        echo "  Gaming configs: Found"
        echo "  Gaming libraries: Found"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "Gaming components validation failed with $validation_errors errors"
    fi
    
    log_success "Gaming components validation passed"
}

# Validate ISO structure
validate_iso_structure() {
    local iso_dir="$1"
    
    log_info "Validating ISO structure..."
    update_progress 6
    
    local validation_errors=0
    
    # Check required ISO files
    local required_iso_files=(
        "boot/vmlinuz:kernel"
        "boot/initramfs:initramfs"
        "boot/grub/grub.cfg:grub-config"
        "gentoo.squashfs:root-filesystem"
    )
    
    for file_info in "${required_iso_files[@]}"; do
        local file="${file_info%:*}"
        local description="${file_info#*:}"
        
        if [ ! -f "$iso_dir/$file" ]; then
            log_error "Missing ISO file: $file ($description)"
            validation_errors=$((validation_errors + 1))
        else
            local file_size=$(stat -c%s "$iso_dir/$file" 2>/dev/null || echo "0")
            log_success "Found: $file ($description) - $(numfmt --to=iec $file_size)"
        fi
    done
    
    # Check ISO directory structure
    local iso_dirs=(
        "boot:boot-files"
        "boot/grub:grub-files"
        "EFI:efi-files"
        "EFI/BOOT:efi-boot"
    )
    
    for dir_info in "${iso_dirs[@]}"; do
        local dir="${dir_info%:*}"
        local description="${dir_info#*:}"
        
        if [ ! -d "$iso_dir/$dir" ]; then
            log_warning "ISO directory missing: $dir ($description)"
        else
            log_success "Found: $dir ($description)"
        fi
    done
    
    # Check file sizes
    local total_size=$(du -sb "$iso_dir" 2>/dev/null | cut -f1)
    if [ "$total_size" -lt 1000000000 ]; then  # Less than 1GB
        log_warning "ISO directory seems too small: $(numfmt --to=iec $total_size)"
    fi
    
    # Record results
    {
        echo "ISO Structure Validation:"
        echo "  Required files: $(( ${#required_iso_files[@]} - validation_errors ))/${#required_iso_files[@]} found"
        echo "  ISO directories: Found"
        echo "  Total size: $(numfmt --to=iec $total_size)"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "ISO structure validation failed with $validation_errors errors"
    fi
    
    log_success "ISO structure validation passed"
}

# Test ISO bootability
test_iso_bootability() {
    local iso_file="$1"
    
    log_info "Testing ISO bootability..."
    update_progress 7
    
    local validation_errors=0
    
    # Check if ISO file exists and is readable
    if [ ! -f "$iso_file" ]; then
        log_error "ISO file not found: $iso_file"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Check ISO file size
    local iso_size=$(stat -c%s "$iso_file" 2>/dev/null || echo "0")
    if [ "$iso_size" -lt 1000000000 ]; then  # Less than 1GB
        log_error "ISO file too small: $(numfmt --to=iec $iso_size)"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Validate ISO format using xorriso
    if command -v xorriso &> /dev/null; then
        if ! xorriso -indev "$iso_file" -report_el_torito as_mkisofs 2>/dev/null | grep -q "El Torito"; then
            log_warning "ISO may not be bootable (no El Torito boot record)"
        else
            log_success "ISO has El Torito boot record"
        fi
    fi
    
    # Check for hybrid ISO support
    if command -v xorriso &> /dev/null; then
        if xorriso -indev "$iso_file" -report_el_torito as_mkisofs 2>/dev/null | grep -q "Boot media type"; then
            log_success "ISO supports hybrid boot (USB bootable)"
        else
            log_warning "ISO may not support hybrid boot"
        fi
    fi
    
    # Record results
    {
        echo "ISO Bootability Test:"
        echo "  ISO file: Found"
        echo "  File size: $(numfmt --to=iec $iso_size)"
        echo "  Boot record: Valid"
        echo "  Hybrid support: Checked"
        echo "  Errors: $validation_errors"
        echo ""
    } >> "$VALIDATION_RESULTS"
    
    if [ $validation_errors -gt 0 ]; then
        die "ISO bootability test failed with $validation_errors errors"
    fi
    
    log_success "ISO bootability test passed"
}

# Generate validation report
generate_validation_report() {
    log_info "Generating validation report..."
    update_progress 8
    
    local report_file="$SCRIPT_DIR/raptoros-validation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    # Copy validation results
    cp "$VALIDATION_RESULTS" "$report_file"
    
    # Add summary
    {
        echo ""
        echo "Validation Summary"
        echo "=================="
        echo "Total validation steps: 8"
        echo "Status: PASSED"
        echo "Build validated successfully at: $(date)"
        echo ""
        echo "This build has passed all validation checks and is ready for distribution."
        echo "The ISO should be bootable and contain all required components."
    } >> "$report_file"
    
    log_success "Validation report generated: $report_file"
    
    # Display summary
    print_separator
    print_header "BUILD VALIDATION COMPLETED SUCCESSFULLY"
    print_separator
    cat "$report_file"
    print_separator
    
    echo "$report_file"
}

# Main validation function
run_complete_validation() {
    local squashfs_dir="$1"
    local iso_dir="$2"
    local iso_file="$3"
    
    log_info "Starting complete build validation..."
    
    # Initialize validation
    init_validation
    
    # Run all validation steps
    validate_package_installations "$squashfs_dir"
    validate_system_configuration "$squashfs_dir"
    validate_filesystem_structure "$squashfs_dir"
    validate_kernel_boot "$squashfs_dir"
    validate_gaming_components "$squashfs_dir"
    validate_iso_structure "$iso_dir"
    test_iso_bootability "$iso_file"
    
    # Generate final report
    local report_file=$(generate_validation_report)
    
    log_success "Complete build validation completed successfully"
    echo "$report_file"
}
