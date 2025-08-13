#!/bin/bash
# Fix Build Issues Script
# This script fixes common issues in existing Gentoo builds

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔧 Fixing Build Issues Script${NC}"
echo "=================================="

# Check if we're in the right directory
if [ ! -d "squashfs" ]; then
    echo -e "${RED}Error: This script must be run from the build directory${NC}"
    echo "Please run: cd /var/tmp/gentoo-gaming-build"
    exit 1
fi

echo -e "${YELLOW}Detected build directory: $(pwd)${NC}"

# 1. Fix Python targets in make.conf
echo -e "\n${CYAN}1. Fixing Python targets...${NC}"
if [ -f "squashfs/etc/portage/make.conf" ]; then
    sudo sed -i '/PYTHON_TARGETS/d' squashfs/etc/portage/make.conf
    sudo sed -i '/PYTHON_SINGLE_TARGET/d' squashfs/etc/portage/make.conf
    echo 'PYTHON_TARGETS="python3_11 python3_12"' | sudo tee -a squashfs/etc/portage/make.conf
    echo 'PYTHON_SINGLE_TARGET="python3_12"' | sudo tee -a squashfs/etc/portage/make.conf
    echo -e "${GREEN}✓ Python targets fixed${NC}"
else
    echo -e "${RED}Warning: make.conf not found${NC}"
fi

# 2. Fix ionice command
echo -e "\n${CYAN}2. Fixing ionice command...${NC}"
if [ -f "squashfs/etc/portage/make.conf" ]; then
    sudo sed -i 's/PORTAGE_IONICE_COMMAND=.*/PORTAGE_IONICE_COMMAND="ionice -c 3"/' squashfs/etc/portage/make.conf
    echo -e "${GREEN}✓ ionice command fixed${NC}"
else
    echo -e "${RED}Warning: make.conf not found${NC}"
fi

# 3. Fix locale in chroot
echo -e "\n${CYAN}3. Fixing locale...${NC}"
echo "en_US.UTF-8 UTF-8" | sudo tee squashfs/etc/locale.gen > /dev/null
echo "LANG=\"en_US.UTF-8\"" | sudo tee squashfs/etc/locale.conf > /dev/null
echo -e "${GREEN}✓ Locale fixed${NC}"

# 4. Create /dev/pts if missing
echo -e "\n${CYAN}4. Ensuring /dev/pts exists...${NC}"
sudo mkdir -p squashfs/dev/pts
echo -e "${GREEN}✓ /dev/pts directory ensured${NC}"

# 5. Check for existing packages
echo -e "\n${CYAN}5. Checking existing packages...${NC}"
if [ -d "squashfs/usr/src/linux" ]; then
    echo -e "${GREEN}✓ Kernel source found${NC}"
else
    echo -e "${YELLOW}⚠ Kernel source not found${NC}"
fi

if [ -f "squashfs/boot/vmlinuz"* ]; then
    echo -e "${GREEN}✓ Kernel binary found${NC}"
else
    echo -e "${YELLOW}⚠ Kernel binary not found${NC}"
fi

echo -e "\n${GREEN}🎉 All issues fixed!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "1. Continue with ISO creation (recommended - packages are already installed)"
echo "   ./build.sh → Select option 4 (ISO Only)"
echo ""
echo "2. Go into recovery mode to install missing packages"
echo "   ./build.sh → Select option 6 (Recovery Mode) → Option 5 (Chroot)"
echo ""
echo "3. Check what's already installed:"
echo "   ls -la squashfs/boot/"
echo "   ls -la squashfs/usr/src/"
echo ""
echo -e "${YELLOW}Your build should now work properly!${NC}"
