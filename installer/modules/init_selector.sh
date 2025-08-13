#!/bin/bash
# Init System Selector Module for RaptorOS

# Select init system
select_init_system() {
    INIT_SYSTEM=$(dialog --backtitle "RaptorOS Installer" \
                        --title "Init System" \
                        --radiolist "\nSelect init system:\n" \
                        15 75 4 \
                        "systemd" "systemd - Modern, full featured (faster boot)" ON \
                        "openrc" "OpenRC - Traditional, simple, reliable" OFF \
                        "runit" "runit - Minimal and fast" OFF \
                        "s6" "s6 - Supervision suite" OFF \
                        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"

    show_init_details
}

# Show init system details
show_init_details() {
    local details=""

    case "$INIT_SYSTEM" in
        "systemd")
            details="systemd\n\n\
✓ Fastest boot times (~5 seconds)\n\
✓ Better game compatibility\n\
✓ Socket activation\n\
✓ Built-in logging (journald)\n\
✓ Timer units (no cron needed)\n\
✓ Automatic service restart\n\
✓ Most software expects it\n\n\
Recommended for gaming systems"
            ;;
        "openrc")
            details="OpenRC\n\n\
✓ Simple and reliable\n\
✓ Traditional Unix approach\n\
✓ Lower memory usage\n\
✓ Easier to understand\n\
✓ Gentoo default\n\n\
Good for users wanting simplicity"
            ;;
    esac

    if [ ! -z "$details" ]; then
        dialog --backtitle "RaptorOS Installer" \
               --title "$INIT_SYSTEM Details" \
               --msgbox "$details" 18 55
    fi
}
