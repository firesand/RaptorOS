#!/bin/bash
# Quick Setup Script for Gentoo Gaming ISO Builder
# This script prepares your repository and checks dependencies

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        Gentoo Gaming ISO Builder - Setup Script           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root!${NC}"
   echo -e "${YELLOW}It will ask for sudo when needed.${NC}"
   exit 1
fi

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        echo -e "${GREEN}Detected distribution: $NAME${NC}"
    else
        echo -e "${RED}Cannot detect distribution${NC}"
        exit 1
    fi
}

# Install dependencies based on distribution
install_dependencies() {
    echo -e "${CYAN}Installing required dependencies...${NC}"
    
    case "$DISTRO" in
        arch|cachyos|endeavouros|manjaro)
            echo -e "${YELLOW}Using pacman...${NC}"
            sudo pacman -Syu --needed \
                wget git dialog \
                squashfs-tools cdrtools xorriso \
                parted dosfstools btrfs-progs \
                arch-install-scripts \
                qemu-img qemu-system-x86_64 \
                2>/dev/null || true
            ;;
        
        ubuntu|debian|pop|linuxmint)
            echo -e "${YELLOW}Using apt...${NC}"
            sudo apt update
            sudo apt install -y \
                wget git dialog \
                squashfs-tools genisoimage xorriso \
                parted dosfstools btrfs-progs \
                qemu-utils qemu-system-x86 \
                debootstrap \
                2>/dev/null || true
            ;;
        
        fedora|rhel|centos|rocky|almalinux)
            echo -e "${YELLOW}Using dnf...${NC}"
            sudo dnf install -y \
                wget git dialog \
                squashfs-tools genisoimage xorriso \
                parted dosfstools btrfs-progs \
                qemu-img qemu-system-x86_64 \
                2>/dev/null || true
            ;;
        
        opensuse|suse)
            echo -e "${YELLOW}Using zypper...${NC}"
            sudo zypper install -y \
                wget git dialog \
                squashfs xorriso \
                parted dosfstools btrfsprogs \
                qemu-tools qemu-x86 \
                2>/dev/null || true
            ;;
        
        gentoo)
            echo -e "${YELLOW}Using emerge...${NC}"
            sudo emerge -av \
                net-misc/wget dev-vcs/git dev-util/dialog \
                sys-fs/squashfs-tools dev-libs/libisoburn \
                sys-block/parted sys-fs/dosfstools sys-fs/btrfs-progs \
                app-emulation/qemu \
                2>/dev/null || true
            ;;
        
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo -e "${YELLOW}Please manually install: wget git dialog squashfs-tools xorriso parted dosfstools btrfs-progs${NC}"
            ;;
    esac
}

# Create directory structure
create_structure() {
    echo -e "${CYAN}Creating directory structure...${NC}"
    
    # Create directories
    mkdir -p configs/{kernel,package.use,package.accept_keywords,portage}
    mkdir -p installer/modules
    mkdir -p desktop-configs/{hyprland,kde,gnome,xfce,minimal}
    mkdir -p scripts
    mkdir -p docs
    mkdir -p lib
    
    echo -e "${GREEN}✓ Directory structure created${NC}"
}

# Set permissions
set_permissions() {
    echo -e "${CYAN}Setting permissions...${NC}"
    
    # Make scripts executable
    chmod +x build.sh 2>/dev/null || true
    chmod +x setup.sh 2>/dev/null || true
    chmod +x installer/install_gentoo 2>/dev/null || true
    chmod +x installer/modules/*.sh 2>/dev/null || true
    chmod +x scripts/*.sh 2>/dev/null || true
    
    echo -e "${GREEN}✓ Permissions set${NC}"
}

# Check system requirements
check_requirements() {
    echo -e "${CYAN}Checking system requirements...${NC}"
    
    # Check disk space
    available_space=$(df /var/tmp 2>/dev/null | awk 'NR==2 {print int($4/1048576)}' || df /tmp | awk 'NR==2 {print int($4/1048576)}')
    if [ "$available_space" -lt 50 ]; then
        echo -e "${YELLOW}⚠ Warning: Less than 50GB free space (${available_space}GB available)${NC}"
        echo -e "${YELLOW}  Full builds may fail. Quick builds should work.${NC}"
    else
        echo -e "${GREEN}✓ Disk space: ${available_space}GB available${NC}"
    fi
    
    # Check RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 8 ]; then
        echo -e "${YELLOW}⚠ Warning: Less than 8GB RAM (${total_ram}GB detected)${NC}"
        echo -e "${YELLOW}  Builds may be slow. Consider using swap.${NC}"
    else
        echo -e "${GREEN}✓ RAM: ${total_ram}GB detected${NC}"
    fi
    
    # Check CPU
    cpu_threads=$(nproc)
    echo -e "${GREEN}✓ CPU: ${cpu_threads} threads available${NC}"
}

# Create example configs
create_examples() {
    echo -e "${CYAN}Creating example configurations...${NC}"
    
    # Create package.use examples
    cat > configs/package.use/gaming << 'EOF'
# Gaming-specific USE flags
games-util/steam-launcher steamruntime
games-util/lutris wine
app-emulation/wine-staging mingw staging vulkan
media-libs/mesa vulkan vaapi vdpau
x11-drivers/nvidia-drivers modules tools persistenced
EOF
    
    # Create package.accept_keywords examples
    cat > configs/package.accept_keywords/gaming << 'EOF'
# Accept ~amd64 for gaming packages
games-util/steam-launcher ~amd64
games-util/lutris ~amd64
games-util/gamemode ~amd64
games-util/mangohud ~amd64
app-emulation/wine-staging ~amd64
media-libs/vkd3d-proton ~amd64
EOF
    
    echo -e "${GREEN}✓ Example configurations created${NC}"
}

# Initialize git repository
init_git() {
    if [ ! -d .git ]; then
        echo -e "${CYAN}Initializing git repository...${NC}"
        git init
        git add .
        git commit -m "Initial commit: Gentoo Gaming ISO builder" 2>/dev/null || true
        echo -e "${GREEN}✓ Git repository initialized${NC}"
    else
        echo -e "${GREEN}✓ Git repository already exists${NC}"
    fi
}

# Download latest stage3 URL
get_stage3_info() {
    echo -e "${CYAN}Getting latest stage3 information...${NC}"
    
    STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
    LATEST=$(wget -qO- $STAGE3_URL | tail -1 | cut -d' ' -f1)
    STAGE3_SIZE=$(wget -qO- $STAGE3_URL | tail -1 | cut -d' ' -f2)
    
    echo -e "${GREEN}✓ Latest stage3: $(basename $LATEST)${NC}"
    echo -e "${GREEN}  Size: $((STAGE3_SIZE / 1048576))MB${NC}"
}

# Main setup flow
main() {
    echo ""
    detect_distro
    echo ""
    
    # Ask for confirmation
    echo -e "${YELLOW}This script will:${NC}"
    echo "  1. Install required dependencies"
    echo "  2. Create directory structure"
    echo "  3. Set up configurations"
    echo "  4. Initialize git repository"
    echo ""
    read -p "Continue? [Y/n] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        echo -e "${RED}Setup cancelled${NC}"
        exit 1
    fi
    
    echo ""
    install_dependencies
    echo ""
    create_structure
    set_permissions
    create_examples
    echo ""
    check_requirements
    echo ""
    get_stage3_info
    echo ""
    init_git
    echo ""
    
    # Success message
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Setup completed successfully!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Review and customize ${YELLOW}configs/make.conf${NC}"
    echo -e "  2. Adjust desktop configs in ${YELLOW}desktop-configs/${NC}"
    echo -e "  3. Run ${YELLOW}sudo ./build.sh${NC} to build your ISO"
    echo ""
    echo -e "${CYAN}Quick build command:${NC}"
    echo -e "  ${GREEN}sudo ./build.sh${NC}  # Select option 1 for quick build"
    echo ""
    echo -e "${CYAN}For help:${NC}"
    echo -e "  ${GREEN}./build.sh --help${NC}"
    echo -e "  ${GREEN}cat docs/BUILDING.md${NC}"
    echo ""
}

# Run main function
main "$@"