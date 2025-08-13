#!/bin/bash
# Partition Manager Module for RaptorOS Installer
# Handles all partitioning operations

# Select partition scheme
select_partition_scheme() {
    PARTITION_SCHEME=$(dialog --backtitle "RaptorOS Installer" \
                              --title "Partition Scheme" \
                              --radiolist "\nSelect partition layout:\n" \
                              20 75 7 \
                              "gaming" "Gaming optimized: /boot(2G) /(100G) /home(200G) /games(rest)" ON \
                              "standard" "Standard: /boot(2G) /(80G) /home(rest)" OFF \
                              "simple" "Simple: /boot(2G) /(rest)" OFF \
                              "btrfs-subvol" "BTRFS with subvolumes (@root @home @games @snapshots)" OFF \
                              "lvm" "LVM with flexible volumes" OFF \
                              "encrypted" "Full disk encryption with LUKS" OFF \
                              "custom" "Manual partitioning with cfdisk" OFF \
                              3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Show scheme details
    show_partition_scheme_details
}

# Show partition scheme details
show_partition_scheme_details() {
    local details=""

    case "$PARTITION_SCHEME" in
        "gaming")
            details="Gaming Optimized Layout:\n\n\
- /boot/efi - 2GB (FAT32) - EFI System\n\
- / - 100GB (BTRFS) - System files\n\
- /home - 200GB (BTRFS) - User data\n\
- /games - Remaining (BTRFS) - Game library\n\
- swap - RAM size (SWAP) - Optional\n\n\
Perfect for large game libraries!"
            ;;
        "standard")
            details="Standard Layout:\n\n\
- /boot/efi - 2GB (FAT32) - EFI System\n\
- / - 80GB (EXT4/BTRFS) - System files\n\
- /home - Remaining (EXT4/BTRFS) - User data\n\
- swap - RAM/2 (SWAP) - Optional\n\n\
Balanced for general use and gaming."
            ;;
        "simple")
            details="Simple Layout:\n\n\
- /boot/efi - 2GB (FAT32) - EFI System\n\
- / - Remaining (EXT4/BTRFS) - Everything\n\n\
Easy to manage, everything in one place."
            ;;
        "btrfs-subvol")
            details="BTRFS Subvolume Layout:\n\n\
- /boot/efi - 2GB (FAT32) - EFI System\n\
- BTRFS Pool - Remaining with subvolumes:\n\
  - @root - System files\n\
  - @home - User data\n\
  - @games - Game library\n\
  - @snapshots - System snapshots\n\
  - @cache - Package cache\n\n\
Advanced features: snapshots, compression, deduplication!"
            ;;
        "lvm")
            details="LVM Layout:\n\n\
- /boot/efi - 2GB (FAT32) - EFI System\n\
- /boot - 1GB (EXT4) - Kernel/initrd\n\
- LVM Physical Volume - Remaining:\n\
  - lv_root - 80GB - System\n\
  - lv_home - 200GB - Home\n\
  - lv_games - Variable - Games\n\
  - lv_swap - RAM size - Swap\n\n\
Flexible volume management!"
            ;;
        "encrypted")
            details="Encrypted Layout (LUKS):\n\n\
- /boot/efi - 2GB (FAT32) - Unencrypted\n\
- /boot - 1GB (EXT4) - Unencrypted\n\
- LUKS Container - Remaining:\n\
  - / - 80GB (BTRFS) - Encrypted system\n\
  - /home - Rest (BTRFS) - Encrypted home\n\n\
Full disk encryption for security!"
            ;;
    esac

    dialog --backtitle "RaptorOS Installer" \
           --title "Partition Scheme Details" \
           --msgbox "$details" 20 65
}

# Select filesystem type
select_filesystem() {
    FILESYSTEM_TYPE=$(dialog --backtitle "RaptorOS Installer" \
                             --title "Filesystem Selection" \
                             --radiolist "\nSelect filesystem type:\n" \
                             18 75 6 \
                             "btrfs" "BTRFS - CoW, snapshots, compression (RECOMMENDED)" ON \
                             "ext4" "EXT4 - Traditional, stable, fast" OFF \
                             "xfs" "XFS - High performance for large files" OFF \
                             "f2fs" "F2FS - Optimized for SSDs" OFF \
                             "zfs" "ZFS - Advanced features (requires module)" OFF \
                             "bcachefs" "Bcachefs - Next-gen CoW filesystem" OFF \
                             3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Show filesystem features
    show_filesystem_features
}

# Show filesystem features
show_filesystem_features() {
    local features=""

    case "$FILESYSTEM_TYPE" in
        "btrfs")
            features="BTRFS Features:\n\n\
✓ Copy-on-Write (CoW)\n\
✓ Transparent compression (zstd)\n\
✓ Snapshots and rollback\n\
✓ Online defragmentation\n\
✓ RAID support\n\
✓ Online filesystem resize\n\
✓ Deduplication\n\n\
Recommended for gaming with snapshot protection!"
            ;;
        "ext4")
            features="EXT4 Features:\n\n\
✓ Most stable and tested\n\
✓ Good performance\n\
✓ Fast fsck\n\
✓ Extent-based storage\n\
✓ Journal checksumming\n\
✓ Online defragmentation\n\n\
Safe choice for all systems!"
            ;;
        "xfs")
            features="XFS Features:\n\n\
✓ Excellent for large files\n\
✓ High performance\n\
✓ Online defragmentation\n\
✓ Good for parallel I/O\n\
✓ Scales well\n\n\
Great for game libraries!"
            ;;
    esac

    dialog --backtitle "RaptorOS Installer" \
           --title "$FILESYSTEM_TYPE Features" \
           --msgbox "$features" 18 55
}

# Create partitions based on scheme
create_partitions() {
    log "Creating partitions with scheme: $PARTITION_SCHEME"

    case "$PARTITION_SCHEME" in
        "gaming")
            create_gaming_partitions
            ;;
        "standard")
            create_standard_partitions
            ;;
        "simple")
            create_simple_partitions
            ;;
        "btrfs-subvol")
            create_btrfs_subvolume_partitions
            ;;
        "lvm")
            create_lvm_partitions
            ;;
        "encrypted")
            create_encrypted_partitions
            ;;
        "custom")
            create_custom_partitions
            ;;
    esac
}

# Gaming partition scheme with optimal sizes
create_gaming_partitions() {
    log "Creating gaming-optimized partition layout"

    wipe_disk_safe "$INSTALL_DISK"

    # Determine partition naming
    if [[ "$INSTALL_DISK" == *nvme* ]] || [[ "$INSTALL_DISK" == *mmcblk* ]]; then
        PART_PREFIX="${INSTALL_DISK}p"
    else
        PART_PREFIX="${INSTALL_DISK}"
    fi

    # Create GPT partition table
    sgdisk -Z "$INSTALL_DISK"
    sgdisk -o "$INSTALL_DISK"

    # Create partitions
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"EFI" "$INSTALL_DISK"
    sgdisk -n 2:0:+100G -t 2:8300 -c 2:"ROOT" "$INSTALL_DISK"
    sgdisk -n 3:0:+200G -t 3:8300 -c 3:"HOME" "$INSTALL_DISK"

    # Check if we should add swap
    if dialog --yesno "Add swap partition? (Recommended: ${RAM_SIZE}GB)" 8 50; then
        sgdisk -n 4:0:+${RAM_SIZE}G -t 4:8200 -c 4:"SWAP" "$INSTALL_DISK"
        sgdisk -n 5:0:0 -t 5:8300 -c 5:"GAMES" "$INSTALL_DISK"
        SWAP_PART="${PART_PREFIX}4"
        GAMES_PART="${PART_PREFIX}5"
    else
        sgdisk -n 4:0:0 -t 4:8300 -c 4:"GAMES" "$INSTALL_DISK"
        GAMES_PART="${PART_PREFIX}4"
    fi

    # Set partition variables
    BOOT_PART="${PART_PREFIX}1"
    ROOT_PART="${PART_PREFIX}2"
    HOME_PART="${PART_PREFIX}3"

    # Inform kernel
    partprobe "$INSTALL_DISK"
    sync  # Ensure partitions are written to disk
    sleep 3  # Increased from 2 for better stability

    log "Gaming partitions created successfully"
}

# BTRFS with subvolumes
create_btrfs_subvolume_partitions() {
    log "Creating BTRFS subvolume layout"

    wipe_disk_safe "$INSTALL_DISK"

    # Determine partition naming
    if [[ "$INSTALL_DISK" == *nvme* ]] || [[ "$INSTALL_DISK" == *mmcblk* ]]; then
        PART_PREFIX="${INSTALL_DISK}p"
    else
        PART_PREFIX="${INSTALL_DISK}"
    fi

    # Create partitions
    sgdisk -Z "$INSTALL_DISK"
    sgdisk -o "$INSTALL_DISK"
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"EFI" "$INSTALL_DISK"
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"BTRFS" "$INSTALL_DISK"

    BOOT_PART="${PART_PREFIX}1"
    ROOT_PART="${PART_PREFIX}2"

    partprobe "$INSTALL_DISK"
    sync  # Ensure partitions are written to disk
    sleep 3  # Increased from 2 for better stability

    log "BTRFS partition layout created"
}

# Format partitions
format_partitions() {
    log "Formatting partitions with $FILESYSTEM_TYPE"

    # Format EFI partition
    mkfs.fat -F32 -n EFI "$BOOT_PART"

    # Format based on filesystem type
    case "$FILESYSTEM_TYPE" in
        "btrfs")
            format_btrfs_partitions
            ;;
        "ext4")
            format_ext4_partitions
            ;;
        "xfs")
            format_xfs_partitions
            ;;
        "f2fs")
            format_f2fs_partitions
            ;;
    esac

    # Format swap if exists
    if [ ! -z "$SWAP_PART" ]; then
        mkswap -L swap "$SWAP_PART"
        swapon "$SWAP_PART"
    fi
}

# Format BTRFS partitions with optimizations
format_btrfs_partitions() {
    # For simple or standard layout
    if [[ "$PARTITION_SCHEME" != "btrfs-subvol" ]]; then
        mkfs.btrfs -f -L root "$ROOT_PART"
        [ ! -z "$HOME_PART" ] && mkfs.btrfs -f -L home "$HOME_PART"
        [ ! -z "$GAMES_PART" ] && mkfs.btrfs -f -L games "$GAMES_PART"
    else
        # BTRFS with subvolumes
        mkfs.btrfs -f -L raptoros "$ROOT_PART"

        # Mount temporarily to create subvolumes
        mount "$ROOT_PART" /mnt

        # Create subvolumes
        btrfs subvolume create /mnt/@root
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@games
        btrfs subvolume create /mnt/@snapshots
        btrfs subvolume create /mnt/@cache
        btrfs subvolume create /mnt/@log
        btrfs subvolume create /mnt/@tmp

        # Set default subvolume
        btrfs subvolume set-default /mnt/@root

        umount /mnt
    fi
}

# Format EXT4 partitions
format_ext4_partitions() {
    mkfs.ext4 -L root "$ROOT_PART"
    [ ! -z "$HOME_PART" ] && mkfs.ext4 -L home "$HOME_PART"
    [ ! -z "$GAMES_PART" ] && mkfs.ext4 -L games "$GAMES_PART"
}

# Format XFS partitions
format_xfs_partitions() {
    mkfs.xfs -f -L root "$ROOT_PART"
    [ ! -z "$HOME_PART" ] && mkfs.xfs -f -L home "$HOME_PART"
    [ ! -z "$GAMES_PART" ] && mkfs.xfs -f -L games "$GAMES_PART"
}

# Format F2FS partitions
format_f2fs_partitions() {
    mkfs.f2fs -l root "$ROOT_PART"
    [ ! -z "$HOME_PART" ] && mkfs.f2fs -l home "$HOME_PART"
    [ ! -z "$GAMES_PART" ] && mkfs.f2fs -l games "$GAMES_PART"
}

# Gaming-optimized BTRFS mount options
mount_gaming_partitions_optimized() {
    log "Mounting partitions with gaming optimizations"
    
    # Root partition - keep compression for system files
    local root_opts="defaults,noatime,compress=zstd:1,space_cache=v2,discard=async"
    mount -o "$root_opts" "$ROOT_PART" /mnt/gentoo
    
    # Home partition - moderate compression
    if [ ! -z "$HOME_PART" ]; then
        mkdir -p /mnt/gentoo/home
        local home_opts="defaults,noatime,compress=zstd:1,space_cache=v2,discard=async"
        mount -o "$home_opts" "$HOME_PART" /mnt/gentoo/home
    fi
    
    # Games partition - NO compression, optimized for read performance
    if [ ! -z "$GAMES_PART" ]; then
        mkdir -p /mnt/gentoo/games
        local games_opts="defaults,noatime,nodatasum,nocompress,space_cache=v2,discard=async,max_inline=0"
        mount -o "$games_opts" "$GAMES_PART" /mnt/gentoo/games
        
        # Create game library directories
        mkdir -p /mnt/gentoo/games/{steam,lutris,heroic,wine,legendary}
        
        # Set optimal attributes for game directories
        chattr +C /mnt/gentoo/games  # No copy-on-write for better performance
    fi
    
    log "Gaming-optimized mount complete"
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions"
    mkdir -p /mnt/gentoo
    
    # Use optimized mounting for gaming partition scheme
    if [[ "$PARTITION_SCHEME" == "gaming" ]] && [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
        mount_gaming_partitions_optimized
    elif [[ "$FILESYSTEM_TYPE" == "btrfs" ]] && [[ "$PARTITION_SCHEME" == "btrfs-subvol" ]]; then
        mount_btrfs_subvolumes
    else
        mount_standard_partitions
    fi
    
    # Mount EFI
    mkdir -p /mnt/gentoo/boot/efi
    mount "$BOOT_PART" /mnt/gentoo/boot/efi
    
    log "All partitions mounted"
}

# Mount BTRFS subvolumes with optimizations
mount_btrfs_subvolumes() {
    local mount_opts="defaults,noatime,compress=zstd:1,space_cache=v2,discard=async"

    # Mount root subvolume
    mount -o "$mount_opts,subvol=@root" "$ROOT_PART" /mnt/gentoo

    # Create mount points
    mkdir -p /mnt/gentoo/{home,games,var/cache,var/log,var/tmp,.snapshots}

    # Mount other subvolumes
    mount -o "$mount_opts,subvol=@home" "$ROOT_PART" /mnt/gentoo/home
    mount -o "$mount_opts,subvol=@games" "$ROOT_PART" /mnt/gentoo/games
    mount -o "$mount_opts,subvol=@snapshots" "$ROOT_PART" /mnt/gentoo/.snapshots
    mount -o "$mount_opts,subvol=@cache" "$ROOT_PART" /mnt/gentoo/var/cache
    mount -o "$mount_opts,subvol=@log" "$ROOT_PART" /mnt/gentoo/var/log
    mount -o "defaults,noatime,compress=no,subvol=@tmp" "$ROOT_PART" /mnt/gentoo/var/tmp
}

# Mount standard partitions
mount_standard_partitions() {
    # Mount root
    if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
        mount -o defaults,noatime,compress=zstd:1,space_cache=v2 "$ROOT_PART" /mnt/gentoo
    else
        mount "$ROOT_PART" /mnt/gentoo
    fi

    # Mount home if separate
    if [ ! -z "$HOME_PART" ]; then
        mkdir -p /mnt/gentoo/home
        if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
            mount -o defaults,noatime,compress=zstd:1,space_cache=v2 "$HOME_PART" /mnt/gentoo/home
        else
            mount "$HOME_PART" /mnt/gentoo/home
        fi
    fi

    # Mount games if separate
    if [ ! -z "$GAMES_PART" ]; then
        mkdir -p /mnt/gentoo/games
        if [[ "$FILESYSTEM_TYPE" == "btrfs" ]]; then
            mount -o defaults,noatime,compress=zstd:1,space_cache=v2 "$GAMES_PART" /mnt/gentoo/games
        else
            mount "$GAMES_PART" /mnt/gentoo/games
        fi
    fi
}
