#!/bin/bash
# Kernel Configuration Module for RaptorOS
# Gaming-optimized kernel configurations

# Main kernel configuration
configure_kernel() {
    log "Starting kernel configuration"

    case "$KERNEL_TYPE" in
        "cachyos")
            configure_cachyos_kernel
            ;;
        "xanmod")
            configure_xanmod_kernel
            ;;
        "zen")
            configure_zen_kernel
            ;;
        "tkg")
            configure_tkg_kernel
            ;;
        "vanilla")
            configure_vanilla_gaming_kernel
            ;;
        *)
            configure_gentoo_gaming_kernel
            ;;
    esac
}

# Base gaming kernel config (common for all)
create_base_gaming_config() {
    cat > /mnt/gentoo/usr/src/linux/.config << 'EOF'
# RaptorOS Gaming Kernel Configuration
# Generated for optimal gaming performance

# General setup
CONFIG_LOCALVERSION="-raptoros"
CONFIG_DEFAULT_HOSTNAME="raptoros"
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
# Timer frequency - 500Hz for better gaming/overhead balance
CONFIG_HZ_500=y
CONFIG_HZ=500

# NO_HZ_IDLE is better for gaming than NO_HZ_FULL
CONFIG_NO_HZ_IDLE=y
CONFIG_NO_HZ_FULL=n
CONFIG_NO_HZ=y
CONFIG_HIGH_RES_TIMERS=y

# Preemption Model - Full for desktop responsiveness
CONFIG_PREEMPT=y
CONFIG_PREEMPT_COUNT=y
CONFIG_PREEMPTION=y
CONFIG_PREEMPT_DYNAMIC=y
CONFIG_IRQ_TIME_ACCOUNTING=y
CONFIG_BSD_PROCESS_ACCT=y
CONFIG_TASKSTATS=y
CONFIG_TASK_DELAY_ACCT=y
CONFIG_TASK_XACCT=y
CONFIG_TASK_IO_ACCOUNTING=y
CONFIG_PSI=y
CONFIG_PSI_DEFAULT_DISABLED=n

# CPU/Task time accounting - Optimized for gaming
CONFIG_TICK_CPU_ACCOUNTING=y
CONFIG_VIRT_CPU_ACCOUNTING_GEN=n  # Reduced overhead
CONFIG_IRQ_TIME_ACCOUNTING=y
CONFIG_BSD_PROCESS_ACCT=y

# RCU Subsystem
CONFIG_PREEMPT_RCU=y
CONFIG_RCU_BOOST=y
CONFIG_RCU_BOOST_DELAY=500

# Kernel Performance Events
CONFIG_PERF_EVENTS=y

# CPU Power Management - Performance oriented
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_POWERSAVE=y
CONFIG_CPU_FREQ_GOV_USERSPACE=y
CONFIG_CPU_FREQ_GOV_ONDEMAND=y
CONFIG_CPU_FREQ_GOV_CONSERVATIVE=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y

# Intel CPU specific
CONFIG_X86_INTEL_PSTATE=y
CONFIG_X86_INTEL_TSX_MODE_ON=y
CONFIG_X86_P_STATE_EPP=y
CONFIG_X86_INTEL_LPSS=y
CONFIG_INTEL_IDLE=y

# AMD CPU specific
CONFIG_X86_AMD_PSTATE=y
CONFIG_X86_AMD_PSTATE_UT=y
CONFIG_X86_AMD_PLATFORM_DEVICE=y
CONFIG_PROCESSOR_SELECT=y
CONFIG_CPU_SUP_AMD=y

# Processor type and features
CONFIG_MCORE2=y  # For Intel, change to CONFIG_MK10=y for AMD
CONFIG_PROCESSOR_SELECT=y
CONFIG_CPU_SUP_INTEL=y
CONFIG_CPU_SUP_AMD=y
CONFIG_SCHED_MC=y
CONFIG_SCHED_MC_PRIO=y
CONFIG_X86_EXTENDED_PLATFORM=y
CONFIG_SCHED_OMIT_FRAME_POINTER=y

# Scheduler - Gaming optimized
CONFIG_SCHED_AUTOGROUP=n  # Can cause issues with some games
CONFIG_SCHED_TUNE=y       # For better task placement

# Add FUTEX_WAIT_MULTIPLE for Wine/Proton
CONFIG_FUTEX=y
CONFIG_FUTEX_PI=y
CONFIG_FUTEX2=y
CONFIG_FUTEX_WAIT_MULTIPLE=y

# Memory Management - Optimized for gaming
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y  # Better than ALWAYS
CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=n
CONFIG_CLEANCACHE=n  # Overhead reduction
CONFIG_FRONTSWAP=n   # Overhead reduction
CONFIG_ZSWAP=y
CONFIG_ZSWAP_COMPRESSOR_DEFAULT_LZ4=y
CONFIG_ZSWAP_ZPOOL_DEFAULT_ZSMALLOC=y
CONFIG_UKSM=y  # If available
CONFIG_KSM=y
CONFIG_MEMORY_FAILURE=y
CONFIG_HWPOISON_INJECT=n

# NUMA
CONFIG_NUMA=y
CONFIG_NUMA_BALANCING=y
CONFIG_NUMA_BALANCING_DEFAULT_ENABLED=y

# Networking - optimized for gaming
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET=y
CONFIG_IP_MULTICAST=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_FIB_TRIE_STATS=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IP_ROUTE_MULTIPATH=y
CONFIG_IP_ROUTE_VERBOSE=y
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_TCP_FASTOPEN=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_NET_SCH_CAKE=y

# Low latency network
CONFIG_NET_RX_BUSY_POLL=y
CONFIG_BQL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_XDP_SOCKETS=y

# File systems
CONFIG_EXT4_FS=y
CONFIG_BTRFS_FS=y
CONFIG_BTRFS_FS_POSIX_ACL=y
CONFIG_XFS_FS=y
CONFIG_F2FS_FS=y
CONFIG_FUSE_FS=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_HUGETLBFS=y

# Graphics support - NVIDIA
CONFIG_DRM=y
CONFIG_DRM_NVIDIA=m
CONFIG_DRM_NVIDIA_MODESET=y
CONFIG_DRM_NVIDIA_UVM=m
CONFIG_DRM_NVIDIA_GSP_RPC=y

# Graphics support - AMD
CONFIG_DRM_AMDGPU=m
CONFIG_DRM_AMDGPU_SI=y
CONFIG_DRM_AMDGPU_CIK=y
CONFIG_DRM_AMDGPU_USERPTR=y
CONFIG_DRM_AMD_ACP=y
CONFIG_DRM_AMD_DC=y
CONFIG_DRM_AMD_DC_HDCP=y
CONFIG_DRM_AMD_DC_SI=y

# Graphics support - Intel
CONFIG_DRM_I915=m
CONFIG_DRM_I915_CAPTURE_ERROR=y
CONFIG_DRM_I915_USERPTR=y
CONFIG_DRM_I915_GVT=y

# Input device support
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_JOYSTICK=y
CONFIG_INPUT_TABLET=y
CONFIG_INPUT_TOUCHSCREEN=y
CONFIG_INPUT_MISC=y

# USB support
CONFIG_USB_SUPPORT=y
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_USB_UAS=y

# Sound card support
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_TIMER=y
CONFIG_SND_PCM=y
CONFIG_SND_HWDEP=y
CONFIG_SND_SEQ_DEVICE=y
CONFIG_SND_RAWMIDI=y
CONFIG_SND_JACK=y
CONFIG_SND_JACK_INPUT_DEV=y
CONFIG_SND_OSSEMUL=y
CONFIG_SND_MIXER_OSS=y
CONFIG_SND_PCM_OSS=y
CONFIG_SND_PCM_OSS_PLUGINS=y
CONFIG_SND_PCM_TIMER=y
CONFIG_SND_HRTIMER=y
CONFIG_SND_DYNAMIC_MINORS=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_HDA_CODEC_REALTEK=y
CONFIG_SND_HDA_CODEC_HDMI=y
CONFIG_SND_USB_AUDIO=y

# Virtualization for gaming
CONFIG_VIRTUALIZATION=y
CONFIG_KVM=y
CONFIG_KVM_INTEL=y  # Or CONFIG_KVM_AMD for AMD
CONFIG_VHOST_NET=y
CONFIG_VHOST_VSOCK=y

# Security options - balanced for performance
CONFIG_SECURITY=y
CONFIG_SECURITY_SELINUX=n  # Disabled for performance
CONFIG_SECURITY_APPARMOR=n
CONFIG_HARDENED_USERCOPY=n
CONFIG_FORTIFY_SOURCE=n
CONFIG_INIT_ON_ALLOC_DEFAULT_ON=n
CONFIG_INIT_ON_FREE_DEFAULT_ON=n

# Crypto acceleration
CONFIG_CRYPTO_AES_NI_INTEL=y
CONFIG_CRYPTO_SHA1_SSSE3=y
CONFIG_CRYPTO_SHA256_SSSE3=y
CONFIG_CRYPTO_SHA512_SSSE3=y
CONFIG_CRYPTO_CRC32C_INTEL=y
CONFIG_CRYPTO_CRC32_PCLMUL=y

# NTFS support for dual-boot gaming
CONFIG_NTFS_FS=y
CONFIG_NTFS3_FS=y
CONFIG_NTFS3_FS_POSIX_ACL=y

# Wine/Proton support
CONFIG_COMPAT=y
CONFIG_COMPAT_32=y
CONFIG_IA32_EMULATION=y
CONFIG_X86_X32=y
CONFIG_BINFMT_MISC=y

# Futex for Wine/Proton
CONFIG_FUTEX=y
CONFIG_FUTEX_PI=y
CONFIG_FUTEX2=y  # If available

# Additional gaming features
CONFIG_DMA_BUF_SYNC_FILE=y
CONFIG_ANDROID=y  # For some anti-cheat
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"

# Disable debug features for performance
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_DEBUG_FS=n
CONFIG_FTRACE=n
CONFIG_KPROBES=n
CONFIG_FUNCTION_TRACER=n
CONFIG_STACK_TRACER=n

# Module support
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SRCVERSION_ALL=y

# Device Drivers - NVMe
CONFIG_BLK_DEV_NVME=y
CONFIG_NVME_MULTIPATH=y
CONFIG_NVME_HWMON=y

# MSI-X support
CONFIG_PCI_MSI=y
CONFIG_IRQ_REMAP=y

# CPU Frequency scaling
CONFIG_X86_ACPI_CPUFREQ=y
CONFIG_X86_POWERNOW_K8=y
CONFIG_X86_PCC_CPUFREQ=y
CONFIG_X86_SPEEDSTEP_CENTRINO=y
CONFIG_INTEL_PSTATE=y
CONFIG_AMD_PSTATE=y

# Gaming peripherals
CONFIG_HID_LOGITECH=y
CONFIG_HID_LOGITECH_DJ=y
CONFIG_HID_LOGITECH_HIDPP=y
CONFIG_LOGITECH_FF=y
CONFIG_HID_CORSAIR=y
CONFIG_HID_RAZER=y
CONFIG_HID_STEELSERIES=y

# RGB support
CONFIG_USB_LED_TRIG=y
CONFIG_LEDS_CLASS=y
CONFIG_LEDS_CLASS_MULTICOLOR=y
EOF
}

# CachyOS specific configuration
configure_cachyos_kernel() {
    log "Configuring CachyOS kernel"

    create_base_gaming_config

    # CachyOS specific options
    cat >> /mnt/gentoo/usr/src/linux/.config << 'EOF'

# CachyOS Optimizations
CONFIG_CACHY=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y
CONFIG_GENERIC_CPU=n
CONFIG_MNATIVE_INTEL=y  # Or CONFIG_MNATIVE_AMD for AMD
CONFIG_NR_CPUS=320
CONFIG_SCHED_BORE=y  # BORE scheduler
CONFIG_SCHED_CLASS_EXT=y

# BORE Scheduler Configuration
CONFIG_BORE_SCHED_CLASS=y
CONFIG_BORE_EDGE=y
CONFIG_BORE_EDGE_SMT=y
CONFIG_BORE_TUNING=y

# CachyOS performance patches
CONFIG_HZ_PERIODIC=n
CONFIG_NO_HZ_IDLE=n
CONFIG_NO_HZ_FULL=y
CONFIG_NO_HZ=y
CONFIG_CONTEXT_TRACKING=y

# ZSTD kernel compression
CONFIG_KERNEL_ZSTD=y
CONFIG_MODULE_COMPRESS_ZSTD=y
CONFIG_ZSTD_COMPRESSION_LEVEL=3

# BBRv3
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_BBR3=y
CONFIG_DEFAULT_BBR3=y

# NTFS3 with CachyOS patches
CONFIG_NTFS3_FS=y
CONFIG_NTFS3_64BIT_CLUSTER=y
CONFIG_NTFS3_LZX_XPRESS=y
CONFIG_NTFS3_FS_POSIX_ACL=y

# FUTEX2 and WINESYNC
CONFIG_FUTEX2=y
CONFIG_WINESYNC=y

# Per-VMA locking
CONFIG_PER_VMA_LOCK=y

# Multigenerational LRU
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y
CONFIG_LRU_GEN_STATS=n

# THP Shrinker
CONFIG_THP_SHRINKER=y
EOF

    # Apply configuration
    cd /mnt/gentoo/usr/src/linux
    make olddefconfig

    dialog --msgbox "CachyOS kernel configured!\n\n\
Features enabled:\n\
- BORE scheduler\n\
- O3 optimization\n\
- BBRv3 TCP\n\
- FUTEX2/WINESYNC\n\
- Per-VMA locking\n\
- MGLRU\n\
- 1000Hz timer" 16 50
}

# XanMod specific configuration
configure_xanmod_kernel() {
    log "Configuring XanMod kernel"

    create_base_gaming_config

    cat >> /mnt/gentoo/usr/src/linux/.config << 'EOF'

# XanMod Optimizations
CONFIG_XANMOD=y
CONFIG_XANMOD_VERSION=1
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y

# Preemptible Tree-RCU
CONFIG_PREEMPT_RCU=y
CONFIG_RCU_BOOST=y
CONFIG_RCU_FANOUT=64
CONFIG_RCU_FANOUT_LEAF=16
CONFIG_RCU_FAST_NO_HZ=y
CONFIG_RCU_NOCB_CPU=y
CONFIG_RCU_NOCB_CPU_DEFAULT_ALL=y

# MuQSS CPU Scheduler (if available)
CONFIG_SCHED_MUQSS=y
CONFIG_SCHED_YIELD_TYPE=1
CONFIG_RQSHARE_MC=y
CONFIG_RQSHARE_SMP=y

# Alternative: BMQ Scheduler
# CONFIG_SCHED_BMQ=y
# CONFIG_BMQ_SCHED_MC=y

# XanMod defaults
CONFIG_HZ_500=y
CONFIG_HZ=500

# Intel Clear Linux patches
CONFIG_MNATIVE_INTEL=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y

# TCP BBR2
CONFIG_TCP_CONG_BBR2=y
CONFIG_DEFAULT_BBR2=y

# Google's Multigenerational LRU
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y

# ZRAM defaults
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_ENTROPY=n

# Page Table Check
CONFIG_PAGE_TABLE_CHECK=n
CONFIG_PAGE_TABLE_CHECK_ENFORCED=n

# Disabled Mitigations for performance
CONFIG_SPECULATION_MITIGATIONS=n
CONFIG_PAGE_TABLE_ISOLATION=n
CONFIG_RETPOLINE=n
CONFIG_CPU_IBRS_ENTRY=n
CONFIG_CPU_IBPB_ENTRY=n
CONFIG_CPU_SRSO=n
EOF

    cd /mnt/gentoo/usr/src/linux
    make olddefconfig
}

# Zen kernel configuration
configure_zen_kernel() {
    log "Configuring Zen kernel"

    create_base_gaming_config

    cat >> /mnt/gentoo/usr/src/linux/.config << 'EOF'

# Zen Kernel Optimizations
CONFIG_ZEN_INTERACTIVE=y
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y

# MuQSS or BMQ scheduler
CONFIG_SCHED_BMQ=y
CONFIG_BMQ_SCHED_MC=y
CONFIG_BMQ_SCHED_SMT=y

# BFQ I/O Scheduler as default
CONFIG_IOSCHED_BFQ=y
CONFIG_BFQ_GROUP_IOSCHED=y
CONFIG_DEFAULT_BFQ=y
CONFIG_DEFAULT_IOSCHED="bfq"

# Zen Interactive tuning
CONFIG_ZEN_SCHED_INTERACTIVITY=y
CONFIG_ZEN_SCHED_LATENCY_NICE=y
CONFIG_ZEN_SCHED_ISO=y
CONFIG_ZEN_SCHED_AUTOGROUP=y

# ZSTD everywhere
CONFIG_KERNEL_ZSTD=y
CONFIG_MODULE_COMPRESS_ZSTD=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y

# Fsync patches
CONFIG_FUTEX2=y
CONFIG_FUTEX_PI=y
CONFIG_WINESYNC=y

# Anbox modules
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y

# VHBA module for CD emulation
CONFIG_VHBA=m

# Additional Zen tweaks
CONFIG_ZEN_ENABLE_ADAPTIVE_READAHEAD=y
CONFIG_ZEN_ENABLE_VM_DEBUG=n
CONFIG_ZEN_ENABLE_ZCACHE=y
EOF

    cd /mnt/gentoo/usr/src/linux
    make olddefconfig
}

# TKG (The King of Gaming) kernel configuration
configure_tkg_kernel() {
    log "Configuring TKG kernel"

    # TKG uses a configuration script
    cat > /mnt/gentoo/usr/src/linux/tkg-config << 'EOF'
# TKG Linux Kernel Configuration for RaptorOS

# CPU scheduler
_cpusched="bore"  # bore, bmq, pds, cacule, or cfs

# Timer frequency
_timer_freq="1000"

# Default CPU governor
_default_cpu_gov="performance"

# Tick rate
_tickless="full"

# Preempt
_preempt_rt="no"
_preempt="full"

# Compiler optimizations
_cc_harder_flags="y"
_cc_optimize_for="native"
_enable_O3="y"

# Clear Linux patches
_clear_patches="y"

# TCP Congestion Control
_tcp_cong_alg="bbr2"

# BORE Scheduler specific
_bore_tuning="gaming"
_bore_yield="0"

# Gaming optimizations
_fsync="y"
_futex2="y"
_winesync="y"
_zen_interactive="y"
_zstd_compression="y"
_bcachefs="n"
_multigenerational_lru="y"

# Security (disabled for performance)
_retpoline="n"
_spectre_v2="off"
_l1tf="off"
_mds="off"
_tsx_async_abort="off"

# Module compression
_module_compress="zstd"

# Additional patches
_user_patches="y"
_user_patches_dir="/etc/kernels/patches"

# Build options
_noccache="y"
_modprobeddb="n"
_menunconfig="n"
_diffconfig="n"
_localmodcfg="n"
EOF

    # Create TKG build script
    cat > /mnt/gentoo/usr/src/build-tkg.sh << 'EOF'
#!/bin/bash
# Build TKG kernel

cd /usr/src/linux
source tkg-config

# Apply TKG patches
git clone https://github.com/Frogging-Family/linux-tkg.git /tmp/linux-tkg
cd /tmp/linux-tkg
./install.sh
EOF

    chmod +x /mnt/gentoo/usr/src/build-tkg.sh

    dialog --msgbox "TKG kernel configured!\n\n\
Run /usr/src/build-tkg.sh to build\n\n\
Features:\n\
- BORE scheduler\n\
- Gaming patches\n\
- FUTEX2/WINESYNC\n\
- Clear Linux optimizations" 14 50
}

# Vanilla kernel with gaming patches
configure_vanilla_gaming_kernel() {
    log "Configuring vanilla kernel with gaming optimizations"

    create_base_gaming_config

    # Use menuconfig for fine-tuning
    dialog --yesno "Would you like to fine-tune the kernel configuration?" 8 50

    if [ $? -eq 0 ]; then
        cd /mnt/gentoo/usr/src/linux
        make menuconfig
    else
        cd /mnt/gentoo/usr/src/linux
        make olddefconfig
    fi
}

# Gentoo sources with gaming patches
configure_gentoo_gaming_kernel() {
    log "Configuring Gentoo kernel with gaming patches"

    create_base_gaming_config

    # Gentoo-specific options
    cat >> /mnt/gentoo/usr/src/linux/.config << 'EOF'

# Gentoo-specific optimizations
CONFIG_GENTOO_LINUX=y
CONFIG_GENTOO_LINUX_UDEV=y
CONFIG_GENTOO_LINUX_PORTAGE=y
CONFIG_GENTOO_LINUX_INIT_SCRIPT=y

# Gentoo default CPU optimizations
CONFIG_MNATIVE=y

# Enable user patches
CONFIG_GENTOO_KERNEL_SELF_PROTECTION=n

# BFQ for Gentoo
CONFIG_IOSCHED_BFQ=y
CONFIG_BFQ_GROUP_IOSCHED=y

# ZRAM for Gentoo
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_WRITEBACK=y
CONFIG_ZRAM_MEMORY_TRACKING=n

# Crypto for Gentoo
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_ZSTD=y

# Gentoo default filesystem support
CONFIG_REISERFS_FS=n
CONFIG_JFS_FS=n
CONFIG_GFS2_FS=n
CONFIG_OCFS2_FS=n
CONFIG_NILFS2_FS=n

# Keep minimal for gaming
CONFIG_GENTOO_PRINT_FIRMWARE_INFO=n
EOF

    cd /mnt/gentoo/usr/src/linux
    make olddefconfig
}

# Build and install kernel
build_kernel() {
    log "Building kernel"

    local build_threads=$CPU_CORES

    (
        cd /mnt/gentoo/usr/src/linux

        echo "10"
        echo "# Configuring kernel..."
        make olddefconfig

        echo "20"
        echo "# Building kernel..."
        make -j$build_threads

        echo "60"
        echo "# Building modules..."
        make modules -j$build_threads

        echo "80"
        echo "# Installing modules..."
        make modules_install

        echo "90"
        echo "# Installing kernel..."
        make install

        echo "95"
        echo "# Generating initramfs..."
        generate_initramfs

        echo "100"
        echo "# Kernel installation complete!"

    ) | dialog --backtitle "RaptorOS Installer" \
               --title "Building Kernel" \
               --gauge "Starting kernel build..." \
               10 70 0
}

# Generate initramfs
generate_initramfs() {
    log "Generating initramfs"

    # Install dracut or genkernel
    echo "sys-kernel/dracut" >> /mnt/gentoo/var/lib/portage/world

    # Dracut configuration for gaming
    cat > /mnt/gentoo/etc/dracut.conf << 'EOF'
# RaptorOS Dracut Configuration

# Modules to include
add_dracutmodules+=" bash kernel-modules resume rootfs-block udev-rules usrmount base fs-lib shutdown "

# Drivers to include
add_drivers+=" nvidia nvidia-modeset nvidia-uvm nvidia-drm "
add_drivers+=" amdgpu radeon nouveau i915 "
add_drivers+=" nvme ahci xhci-hcd "

# Filesystems
filesystems+=" btrfs ext4 xfs f2fs vfat "

# Compression
compress="zstd"
compresslevel="3"

# Strip binaries
do_strip="yes"

# Host-only mode for smaller initramfs
hostonly="yes"
hostonly_cmdline="no"

# Early microcode
early_microcode="yes"

# UEFI
uefi="yes"
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
kernel_cmdline="quiet splash"
EOF

    # Generate initramfs
    chroot /mnt/gentoo dracut --force --kver $(ls /mnt/gentoo/lib/modules | head -1)
}

# Kernel module blacklist for gaming
create_module_blacklist() {
    cat > /mnt/gentoo/etc/modprobe.d/blacklist-gaming.conf << 'EOF'
# RaptorOS Module Blacklist for Gaming Performance

# Disable watchdogs (can cause stutters)
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist sp5100_tco

# Disable unused network protocols
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc

# Disable unused filesystems
blacklist cramfs
blacklist freevxfs
blacklist jffs2
blacklist hfs
blacklist hfsplus
blacklist udf

# Disable PC speaker
blacklist pcspkr
blacklist snd_pcsp

# Disable unused input devices (if not needed)
# blacklist joydev
# blacklist mousedev

# Disable Intel MEI (Management Engine) if not needed
# blacklist mei
# blacklist mei_me

# Disable unused virtualization if not using VMs
# blacklist kvm
# blacklist kvm_intel
# blacklist kvm_amd
EOF
}
