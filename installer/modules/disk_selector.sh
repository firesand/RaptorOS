#!/bin/bash
# Disk Selection Module for Gentoo Gaming Installer
# Provides safe disk selection with visual feedback

# Detect available disks
detect_disks() {
    local disk_list=()
    local disk_info=""
    
    # Get all block devices
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local model=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
        local type=""
        
        # Skip if not a disk
        [[ ! -b "/dev/$device" ]] && continue
        
        # Determine disk type
        if [[ "$device" == nvme* ]]; then
            type="NVMe"
        elif lsblk -d -o ROTA "/dev/$device" | tail -1 | grep -q "0"; then
            type="SSD"
        else
            type="HDD"
        fi
        
        # Check for existing partitions
        local partitions=$(lsblk -n "/dev/$device" 2>/dev/null | grep -c "part" || echo "0")
        local has_data="No"
        if [ "$partitions" -gt 0 ]; then
            has_data="Yes ($partitions partitions)"
        fi
        
        # Add to array
        disk_list+=("/dev/$device" "$size $type - $model [$has_data data]")
        
    done < <(lsblk -d -o NAME,SIZE,MODEL | grep -E "^(sd|nvme|vd)" | grep -v "^sr")
    
    echo "${disk_list[@]}"
}

# Main disk selection function
select_installation_disk() {
    local disk_list=($(detect_disks))
    
    if [ ${#disk_list[@]} -eq 0 ]; then
        dialog --msgbox "No suitable disks found for installation!" 10 50
        exit 1
    fi
    
    # Show disk selection dialog
    INSTALL_DISK=$(dialog --backtitle "Gentoo Gaming Installer" \
                          --title "Select Installation Disk" \
                          --extra-button --extra-label "Details" \
                          --menu "\nSelect the disk where Gentoo will be installed:\n\n⚠️  ALL DATA ON THE SELECTED DISK WILL BE ERASED!\n" \
                          20 75 8 \
                          "${disk_list[@]}" \
                          3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    case $exit_code in
        0)  # OK button
            confirm_disk_selection
            ;;
        3)  # Details button
            show_disk_details
            select_installation_disk
            ;;
        *)  # Cancel or ESC
            echo "Installation cancelled by user"
            exit 1
            ;;
    esac
}

# Show detailed disk information
show_disk_details() {
    local details=""
    
    for disk in $(lsblk -d -o NAME | grep -E "^(sd|nvme|vd)" | grep -v "^sr"); do
        local device="/dev/$disk"
        local size=$(lsblk -d -o SIZE -n "$device")
        local model=$(lsblk -d -o MODEL -n "$device" | xargs)
        local serial=$(hdparm -I "$device" 2>/dev/null | grep "Serial Number" | awk '{print $3}')
        local temp=$(smartctl -A "$device" 2>/dev/null | grep "Temperature" | awk '{print $10}')
        
        details+="$device:\n"
        details+="  Size: $size\n"
        details+="  Model: $model\n"
        if [ ! -z "$serial" ]; then
            details+="  Serial: $serial\n"
        fi
        if [ ! -z "$temp" ]; then
            details+="  Temperature: ${temp}°C\n"
        fi
        details+="\n"
        
        # Show partitions if any
        local partitions=$(lsblk -n "$device" | grep "part")
        if [ ! -z "$partitions" ]; then
            details+="  Current partitions:\n"
            while IFS= read -r part; do
                local pname=$(echo "$part" | awk '{print $1}' | sed 's/[├─└│]//g')
                local psize=$(echo "$part" | awk '{print $4}')
                local pfs=$(echo "$part" | awk '{print $2}')
                local pmount=$(echo "$part" | awk '{print $7}')
                details+="    $pname: $psize $pfs $pmount\n"
            done <<< "$partitions"
            details+="\n"
        fi
    done
    
    dialog --backtitle "Gentoo Gaming Installer" \
           --title "Disk Details" \
           --msgbox "$details" 30 70
}

# Confirm disk selection
confirm_disk_selection() {
    # Get disk information
    local disk_size=$(lsblk -d -o SIZE -n "$INSTALL_DISK")
    local disk_model=$(lsblk -d -o MODEL -n "$INSTALL_DISK" | xargs)
    local disk_type=""
    
    if [[ "$INSTALL_DISK" == *nvme* ]]; then
        disk_type="NVMe"
    elif lsblk -d -o ROTA "$INSTALL_DISK" | tail -1 | grep -q "0"; then
        disk_type="SSD"
    else
        disk_type="HDD"
    fi
    
    # Check if disk has data
    local partitions=$(lsblk -n "$INSTALL_DISK" 2>/dev/null | grep -c "part" || echo "0")
    local warning=""
    if [ "$partitions" -gt 0 ]; then
        warning="\n⚠️  This disk contains $partitions partition(s) with data!\n"
    fi
    
    # Store for later use
    DISK_TYPE="$disk_type"
    DISK_SIZE="$disk_size"
    DISK_MODEL="$disk_model"
    
    dialog --colors --backtitle "Gentoo Gaming Installer" \
           --title "Confirm Disk Selection" \
           --yes-label "Yes, ERASE this disk" \
           --no-label "No, go back" \
           --defaultno \
           --yesno "\n\
Selected Disk: $INSTALL_DISK\n\
Size: $disk_size\n\
Type: $disk_type\n\
Model: $disk_model\n\
$warning\n\
\Z1ALL DATA ON THIS DISK WILL BE PERMANENTLY ERASED!\Zn\n\n\
Are you ABSOLUTELY sure you want to continue?" 16 60
    
    if [ $? -ne 0 ]; then
        select_installation_disk
    fi
    
    # Final safety check
    if [ "$partitions" -gt 0 ]; then
        dialog --colors --backtitle "Gentoo Gaming Installer" \
               --title "⛔ FINAL WARNING ⛔" \
               --defaultno \
               --yesno "\n\Z1\ZbTHIS DISK CONTAINS DATA THAT WILL BE LOST!\Zn\n\n\
Disk: $INSTALL_DISK\n\n\
This is your LAST CHANCE to cancel.\n\n\
Type YES to confirm destruction of all data." 14 55
        
        if [ $? -ne 0 ]; then
            select_installation_disk
        fi
    fi
}

# Show current disk layout
show_disk_layout() {
    local layout=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$INSTALL_DISK" 2>/dev/null)
    
    dialog --backtitle "Gentoo Gaming Installer" \
           --title "Current Disk Layout - $INSTALL_DISK" \
           --msgbox "\nCurrent partition layout:\n\n$layout\n\nThis will be ERASED during installation." \
           20 70
}

# Safe disk wiping with progress
wipe_disk_safe() {
    local disk="$1"
    
    (
        echo "10"
        echo "# Unmounting any mounted partitions..."
        umount -R "${disk}"* 2>/dev/null || true
        
        echo "25"
        echo "# Wiping partition signatures..."
        wipefs -a "$disk" 2>/dev/null || true
        
        echo "50"
        echo "# Clearing partition table..."
        sgdisk --zap-all "$disk"
        
        echo "75"
        echo "# Creating new GPT partition table..."
        sgdisk -o "$disk"
        
        echo "90"
        echo "# Verifying disk is ready..."
        partprobe "$disk"
        sleep 2
        
        echo "100"
        echo "# Disk prepared successfully!"
        
    ) | dialog --backtitle "Gentoo Gaming Installer" \
               --title "Preparing Disk" \
               --gauge "Preparing $disk for installation..." \
               10 70 0
}

# Partition creation based on scheme
create_partitions() {
    case "$PARTITION_SCHEME" in
        "standard")
            create_standard_partitions
            ;;
        "simple")
            create_simple_partitions
            ;;
        "gaming")
            create_gaming_partitions
            ;;
        "custom")
            create_custom_partitions
            ;;
    esac
}

# Standard partition scheme: /boot, /, /home
create_standard_partitions() {
    log "Creating standard partition layout on $INSTALL_DISK"
    
    # Wipe disk
    wipe_disk_safe "$INSTALL_DISK"
    
    # Create partitions
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"BOOT" "$INSTALL_DISK"
    sgdisk -n 2:0:+100G -t 2:8300 -c 2:"ROOT" "$INSTALL_DISK"
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"HOME" "$INSTALL_DISK"
    
    # Inform kernel
    partprobe "$INSTALL_DISK"
    sleep 2
    
    log "Partition layout created successfully"
}

# Simple partition scheme: /boot, / (everything)
create_simple_partitions() {
    log "Creating simple partition layout on $INSTALL_DISK"
    
    # Wipe disk
    wipe_disk_safe "$INSTALL_DISK"
    
    # Create partitions
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"BOOT" "$INSTALL_DISK"
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "$INSTALL_DISK"
    
    # Inform kernel
    partprobe "$INSTALL_DISK"
    sleep 2
    
    log "Simple partition layout created successfully"
}

# Gaming partition scheme: /boot, /, /home, /games
create_gaming_partitions() {
    log "Creating gaming partition layout on $INSTALL_DISK"
    
    # Wipe disk
    wipe_disk_safe "$INSTALL_DISK"
    
    # Create partitions
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"BOOT" "$INSTALL_DISK"
    sgdisk -n 2:0:+80G -t 2:8300 -c 2:"ROOT" "$INSTALL_DISK"
    sgdisk -n 3:0:+200G -t 3:8300 -c 3:"HOME" "$INSTALL_DISK"
    sgdisk -n 4:0:0 -t 4:8300 -c 4:"GAMES" "$INSTALL_DISK"
    
    # Inform kernel
    partprobe "$INSTALL_DISK"
    sleep 2
    
    log "Gaming partition layout created successfully"
}

# Custom partitioning
create_custom_partitions() {
    dialog --backtitle "Gentoo Gaming Installer" \
           --title "Custom Partitioning" \
           --msgbox "\nYou will now be dropped into cfdisk for manual partitioning.\n\n\
Remember to create:\n\
• At least one EFI System Partition (ESP)\n\
• At least one root partition\n\n\
Press OK to continue..." 12 60
    
    cfdisk "$INSTALL_DISK"
    
    # Verify partitions were created
    if ! lsblk -n "$INSTALL_DISK" | grep -q "part"; then
        dialog --msgbox "No partitions created! Please try again." 8 50
        create_custom_partitions
    fi
}