#!/bin/bash
# RaptorOS Update System - Simplified for modern stable

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       RaptorOS Update System               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

check_versions() {
    echo "Current System Versions:"
    echo "══════════════════════════"
    
    # GCC
    echo -n "GCC: "
    gcc --version | head -1 | awk '{print $3}'
    
    # LLVM
    echo -n "LLVM: "
    llvm-config --version 2>/dev/null || echo "Not installed"
    
    # Mesa
    echo -n "Mesa: "
    equery l media-libs/mesa -F '$version' 2>/dev/null | head -1
    
    # Kernel
    echo -n "Kernel: "
    uname -r
    
    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        echo -n "NVIDIA: "
        nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null
    fi
    
    echo ""
}

smart_update() {
    echo -e "${GREEN}Starting intelligent update...${NC}"
    
    # Sync repos
    echo "Syncing repositories..."
    emerge --sync --quiet
    
    # Update @world with smart defaults
    echo "Calculating updates..."
    
    # Show what would update
    local updates=$(emerge -pvuDN @world 2>&1 | grep "^\[" | wc -l)
    
    if [ "$updates" -eq 0 ]; then
        echo -e "${GREEN}System is up to date!${NC}"
        return
    fi
    
    echo -e "${YELLOW}Found $updates packages to update${NC}"
    
    # Actual update
    emerge -avuDN @world \
        --keep-going \
        --with-bdeps=y \
        --backtrack=30
    
    # Clean up
    echo "Cleaning up..."
    emerge --depclean -a
    
    # Preserved rebuild
    emerge @preserved-rebuild
    
    # Update config files
    etc-update --automode -3
    
    echo -e "${GREEN}Update complete!${NC}"
}

quick_gaming_update() {
    echo -e "${CYAN}Quick gaming package update...${NC}"
    
    # Just update critical gaming packages
    emerge -av1 \
        media-libs/mesa \
        x11-drivers/nvidia-drivers \
        app-emulation/wine-staging \
        games-util/steam-launcher \
        games-util/gamemode \
        2>/dev/null || echo "Some packages not installed"
}

main_menu() {
    PS3="Select option: "
    options=(
        "Check current versions"
        "Full system update"
        "Quick gaming update"
        "Update kernel only"
        "Check security updates"
        "Exit"
    )
    
    select opt in "${options[@]}"; do
        case $REPLY in
            1) check_versions ;;
            2) smart_update ;;
            3) quick_gaming_update ;;
            4) emerge -av sys-kernel/gentoo-sources ;;
            5) glsa-check -l affected ;;
            6) break ;;
            *) echo "Invalid option" ;;
        esac
        echo ""
        echo "Press Enter to continue..."
        read
    done
}

# Main
check_versions
main_menu
