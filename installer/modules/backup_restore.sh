#!/bin/bash
# Backup and Restore Module for RaptorOS
# BTRFS snapshots and system backups

# Main backup menu
backup_restore_menu() {
    local choice=$(dialog --backtitle "RaptorOS Installer" \
                         --title "Backup & Restore" \
                         --menu "\nSelect operation:" \
                         15 70 6 \
                         "snapshot" "Create BTRFS snapshot" \
                         "backup" "Create full system backup" \
                         "restore" "Restore from backup" \
                         "schedule" "Schedule automatic backups" \
                         "list" "List existing backups" \
                         "back" "Return to main menu" \
                         3>&1 1>&2 2>&3)

    case "$choice" in
        "snapshot")
            create_btrfs_snapshot
            ;;
        "backup")
            create_system_backup
            ;;
        "restore")
            restore_from_backup
            ;;
        "schedule")
            schedule_backups
            ;;
        "list")
            list_backups
            ;;
    esac
}

# Create BTRFS snapshot
create_btrfs_snapshot() {
    if [[ "$FILESYSTEM_TYPE" != "btrfs" ]]; then
        dialog --msgbox "Snapshots are only available for BTRFS filesystems!" 8 50
        return
    fi

    local snapshot_name=$(dialog --backtitle "RaptorOS Installer" \
                                 --title "Create Snapshot" \
                                 --inputbox "\nEnter snapshot name:" \
                                 10 50 "raptoros-$(date +%Y%m%d-%H%M%S)" \
                                 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    # Create snapshots directory
    mkdir -p /mnt/gentoo/.snapshots

    # Create snapshot
    btrfs subvolume snapshot -r /mnt/gentoo /mnt/gentoo/.snapshots/$snapshot_name

    if [ $? -eq 0 ]; then
        dialog --msgbox "Snapshot created successfully!\n\nName: $snapshot_name\nLocation: /.snapshots/$snapshot_name" 10 50

        # Create snapshot info
        cat > /mnt/gentoo/.snapshots/$snapshot_name.info << EOF
Snapshot: $snapshot_name
Date: $(date)
Kernel: $KERNEL_TYPE
Desktop: $DESKTOP_ENV
Description: Manual snapshot before system changes
EOF
    else
        dialog --msgbox "Failed to create snapshot!" 8 40
    fi
}

# Schedule automatic backups
schedule_backups() {
    local schedule=$(dialog --backtitle "RaptorOS Installer" \
                           --title "Backup Schedule" \
                           --radiolist "\nSelect backup frequency:" \
                           15 60 5 \
                           "daily" "Daily snapshots (keep 7)" OFF \
                           "weekly" "Weekly snapshots (keep 4)" ON \
                           "monthly" "Monthly snapshots (keep 3)" OFF \
                           "boot" "On every boot" OFF \
                           "none" "Disable automatic backups" OFF \
                           3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && return

    # Create backup script
    cat > /mnt/gentoo/usr/local/bin/auto-snapshot << 'EOF'
#!/bin/bash
# RaptorOS Automatic Snapshot Script

SNAPSHOT_DIR="/.snapshots"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

case "$1" in
    daily)
        SNAPSHOT_NAME="daily-$TIMESTAMP"
        KEEP_COUNT=7
        PREFIX="daily-"
        ;;
    weekly)
        SNAPSHOT_NAME="weekly-$TIMESTAMP"
        KEEP_COUNT=4
        PREFIX="weekly-"
        ;;
    monthly)
        SNAPSHOT_NAME="monthly-$TIMESTAMP"
        KEEP_COUNT=3
        PREFIX="monthly-"
        ;;
    boot)
        SNAPSHOT_NAME="boot-$TIMESTAMP"
        KEEP_COUNT=5
        PREFIX="boot-"
        ;;
    *)
        echo "Usage: $0 {daily|weekly|monthly|boot}"
        exit 1
        ;;
esac

# Create snapshot
mkdir -p "$SNAPSHOT_DIR"
btrfs subvolume snapshot -r / "$SNAPSHOT_DIR/$SNAPSHOT_NAME"

# Clean old snapshots
cd "$SNAPSHOT_DIR"
ls -1 | grep "^$PREFIX" | sort -r | tail -n +$((KEEP_COUNT + 1)) | while read snapshot; do
    btrfs subvolume delete "$snapshot"
done

echo "Snapshot $SNAPSHOT_NAME created successfully"
EOF
    chmod +x /mnt/gentoo/usr/local/bin/auto-snapshot

    # Schedule based on selection
    case "$schedule" in
        "daily")
            echo '0 3 * * * root /usr/local/bin/auto-snapshot daily' >> /mnt/gentoo/etc/crontab
            ;;
        "weekly")
            echo '0 4 * * 1 root /usr/local/bin/auto-snapshot weekly' >> /mnt/gentoo/etc/crontab
            ;;
        "monthly")
            echo '0 5 1 * * root /usr/local/bin/auto-snapshot monthly' >> /mnt/gentoo/etc/crontab
            ;;
        "boot")
            if [[ "$INIT_SYSTEM" == "systemd" ]]; then
                cat > /mnt/gentoo/etc/systemd/system/auto-snapshot.service << 'EOF'
[Unit]
Description=Automatic BTRFS snapshot on boot
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-snapshot boot

[Install]
WantedBy=multi-user.target
EOF
                chroot /mnt/gentoo systemctl enable auto-snapshot.service
            else
                echo '/usr/local/bin/auto-snapshot boot' >> /mnt/gentoo/etc/local.d/snapshot.start
                chmod +x /mnt/gentoo/etc/local.d/snapshot.start
            fi
            ;;
    esac

    dialog --msgbox "Automatic backup schedule configured!" 8 45
}
