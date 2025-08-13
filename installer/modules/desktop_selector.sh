#!/bin/bash
# Desktop Environment Selector Module for RaptorOS

# Select desktop environment
select_desktop_environment() {
    DESKTOP_ENV=$(dialog --backtitle "RaptorOS Installer" \
                        --title "Desktop Environment" \
                        --radiolist "\nSelect desktop environment:\n" \
                        22 75 10 \
                        "hyprland" "Hyprland - Wayland tiling WM with gaming optimizations" ON \
                        "kde-plasma" "KDE Plasma 6 - Full featured, gaming friendly" OFF \
                        "gnome" "GNOME 45 - Modern and clean" OFF \
                        "xfce" "XFCE - Lightweight and fast" OFF \
                        "cinnamon" "Cinnamon - Traditional desktop" OFF \
                        "mate" "MATE - Classic GNOME 2 experience" OFF \
                        "sway" "Sway - i3-compatible Wayland compositor" OFF \
                        "awesome" "AwesomeWM - Highly configurable" OFF \
                        "minimal" "Minimal - Window manager only (Openbox)" OFF \
                        "none" "None - CLI only" OFF \
                        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && error_exit "Installation cancelled"

    # Show desktop details
    show_desktop_details
}

# Show desktop environment details
show_desktop_details() {
    local details=""

    case "$DESKTOP_ENV" in
        "hyprland")
            details="Hyprland - Gaming Optimized\n\n\
✓ Wayland native (better for gaming)\n\
✓ Tearing support for games\n\
✓ Beautiful animations and blur\n\
✓ Highly customizable\n\
✓ Excellent multi-monitor support\n\
✓ Low latency input\n\
✓ RaptorOS gaming rice included\n\n\
RAM Usage: ~600MB\n\
Best for: Gaming enthusiasts"
            ;;
        "kde-plasma")
            details="KDE Plasma 6\n\n\
✓ Full desktop environment\n\
✓ Wayland and X11 support\n\
✓ Excellent gaming compatibility\n\
✓ Built-in system monitor\n\
✓ KDE Connect for phone\n\
✓ Highly customizable\n\n\
RAM Usage: ~1.2GB\n\
Best for: Power users who want everything"
            ;;
        "gnome")
            details="GNOME 45\n\n\
✓ Modern and polished\n\
✓ Wayland by default\n\
✓ Good touchpad gestures\n\
✓ Extension ecosystem\n\
✓ Clean interface\n\n\
RAM Usage: ~1.5GB\n\
Best for: Users wanting simplicity"
            ;;
    esac

    if [ ! -z "$details" ]; then
        dialog --backtitle "RaptorOS Installer" \
               --title "$DESKTOP_ENV Details" \
               --msgbox "$details" 20 60
    fi
}

# Install desktop environment
install_desktop_environment() {
    log "Installing desktop environment: $DESKTOP_ENV"

    case "$DESKTOP_ENV" in
        "hyprland")
            install_hyprland
            ;;
        "kde-plasma")
            install_kde_plasma
            ;;
        "gnome")
            install_gnome
            ;;
        "xfce")
            install_xfce
            ;;
        "minimal")
            install_minimal_desktop
            ;;
        "none")
            log "No desktop environment selected"
            ;;
    esac
}

# Install Hyprland with gaming optimizations
install_hyprland() {
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
gui-wm/hyprland
gui-apps/waybar
gui-apps/wofi
gui-apps/mako
x11-terms/kitty
gui-apps/swww
gui-apps/grim
gui-apps/slurp
gui-apps/wl-clipboard
media-fonts/fontawesome
media-fonts/jetbrains-mono
media-fonts/nerd-fonts
x11-themes/tokyo-night-gtk-theme
x11-misc/dunst
sys-apps/brightnessctl
media-sound/pavucontrol
media-sound/playerctl
EOF

    # Copy Hyprland config
    mkdir -p /mnt/gentoo/etc/skel/.config/hypr
    cp "$SCRIPT_DIR/desktop-configs/hyprland/hyprland.conf" \
       /mnt/gentoo/etc/skel/.config/hypr/

    # Create gaming mode script
    cat > /mnt/gentoo/usr/local/bin/gamemode-toggle << 'EOF'
#!/bin/bash
# Toggle gaming optimizations
if pgrep gamemoded > /dev/null; then
    pkill gamemoded
    notify-send "Gaming Mode" "Disabled"
else
    gamemoded -d
    notify-send "Gaming Mode" "Enabled - Performance Optimized"
fi
EOF
    chmod +x /mnt/gentoo/usr/local/bin/gamemode-toggle
}

# Install KDE Plasma
install_kde_plasma() {
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
kde-plasma/plasma-meta
kde-apps/konsole
kde-apps/dolphin
kde-apps/kate
kde-apps/spectacle
kde-apps/ark
kde-plasma/sddm
EOF

    # Enable SDDM
    ln -sf /etc/init.d/sddm /mnt/gentoo/etc/runlevels/default/sddm
}

# Install GNOME
install_gnome() {
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
gnome-base/gnome
gnome-extra/gnome-tweaks
gnome-extra/gnome-shell-extensions
x11-misc/gdm
EOF

    # Enable GDM
    ln -sf /etc/init.d/gdm /mnt/gentoo/etc/runlevels/default/gdm
}
