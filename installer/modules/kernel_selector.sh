#!/bin/bash
# Kernel Selection Module for RaptorOS

# Select kernel type
select_kernel() {
    KERNEL_TYPE=$(dialog --backtitle "RaptorOS Installer" \
                        --title "Kernel Selection" \
                        --radiolist "\nSelect kernel type:\n" \
                        20 75 8 \
                        "cachyos" "CachyOS - Optimized for gaming (BORE scheduler)" ON \
                        "xanmod" "XanMod - Low latency gaming kernel" OFF \
                        "zen" "Zen Kernel - Balanced performance" OFF \
                        "liquorix" "Liquorix - Debian Zen port" OFF \
                        "tkg" "TKG - Custom gaming patches" OFF \
                        "vanilla" "Vanilla - Stock kernel with gaming config" OFF \
                        "gentoo" "Gentoo - Gentoo patched kernel" OFF \
                        "custom" "Custom - Configure your own" OFF \
                        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"

    show_kernel_details
}

# Show kernel details
show_kernel_details() {
    local details=""

    case "$KERNEL_TYPE" in
        "cachyos")
            details="CachyOS Kernel\n\n\
✓ BORE (Burst-Oriented Response Enhancer) scheduler\n\
✓ 1000Hz timer frequency\n\
✓ Full preemption (PREEMPT)\n\
✓ BBRv3 TCP congestion control\n\
✓ FUTEX2 support\n\
✓ Latest ZSTD patches\n\
✓ AMD P-State EPP driver\n\
✓ NTSync for Wine/Proton\n\n\
Best for: Maximum gaming performance"
            ;;
        "xanmod")
            details="XanMod Kernel\n\n\
✓ MuQSS scheduler option\n\
✓ 500/1000Hz timer\n\
✓ Preemptible tree RCU\n\
✓ Hard Kernel Preemption\n\
✓ Budget Fair Queueing\n\
✓ TCP BBR2\n\
✓ Clear Linux patches\n\n\
Best for: Low latency gaming"
            ;;
        "zen")
            details="Zen Kernel\n\n\
✓ MuQSS or BMQ scheduler\n\
✓ 1000Hz timer\n\
✓ Low latency optimizations\n\
✓ BFQ I/O scheduler\n\
✓ Responsive desktop\n\n\
Best for: Balanced gaming/desktop"
            ;;
    esac

    if [ ! -z "$details" ]; then
        dialog --backtitle "RaptorOS Installer" \
               --title "$KERNEL_TYPE Kernel Details" \
               --msgbox "$details" 20 65
    fi
}

# Install kernel
install_kernel_final() {
    log "Installing kernel: $KERNEL_TYPE"

    case "$KERNEL_TYPE" in
        "cachyos")
            install_cachyos_kernel
            ;;
        "xanmod")
            install_xanmod_kernel
            ;;
        "zen")
            install_zen_kernel
            ;;
        "vanilla")
            install_vanilla_kernel
            ;;
        *)
            install_gentoo_kernel
            ;;
    esac

    # Generate initramfs
    generate_initramfs
}

# Install CachyOS kernel
install_cachyos_kernel() {
    # Add CachyOS overlay
    cat > /mnt/gentoo/etc/portage/repos.conf/cachyos.conf << 'EOF'
[cachyos]
location = /var/db/repos/cachyos
sync-type = git
sync-uri = https://github.com/CachyOS/gentoo-overlay.git
priority = 50
EOF

    # Sync overlay
    chroot /mnt/gentoo emerge --sync cachyos

    # Install kernel
    chroot /mnt/gentoo emerge -av sys-kernel/cachyos-kernel

    # Configure for gaming
    configure_gaming_kernel
}

# Configure kernel for gaming
configure_gaming_kernel() {
    cat > /mnt/gentoo/etc/sysctl.d/99-gaming.conf << 'EOF'
# RaptorOS Gaming Optimizations

# Network optimizations for online gaming
net.core.netdev_max_backlog = 16384
net.core.rmem_default = 1048576
net.core.rmem_max = 134217728
net.core.wmem_default = 1048576
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 1048576 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

# Memory management
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 5
vm.dirty_background_ratio = 3

# CPU scheduler
kernel.sched_child_runs_first = 1
kernel.sched_autogroup_enabled = 1

# Gaming specific
kernel.split_lock_mitigate = 0
dev.i915.perf_stream_paranoid = 0
EOF
}
