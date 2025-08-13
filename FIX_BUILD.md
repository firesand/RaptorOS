Good news - the build actually completed! But there are several issues to fix. Let's address each error:

## Issue 1: Python Targets Mismatch
The system is trying to use Python 3.13 but packages aren't ready for it.

## Issue 2: ionice Command Syntax Error
The `PORTAGE_IONICE_COMMAND` has wrong syntax.

## Issue 3: Locale Issues
The chroot environment doesn't have proper locale settings.

## Issue 4: emerge --ask in Non-Terminal
The `-av` flag includes `--ask` which requires a terminal.

## Quick Fix Script

Run this to fix the existing build:

```bash
#!/bin/bash
# Save as: fix-build-issues.sh

cd /var/tmp/gentoo-gaming-build

echo "Fixing build issues..."

# 1. Fix Python targets in make.conf
echo "Fixing Python targets..."
sudo sed -i '/PYTHON_TARGETS/d' squashfs/etc/portage/make.conf
sudo sed -i '/PYTHON_SINGLE_TARGET/d' squashfs/etc/portage/make.conf
echo 'PYTHON_TARGETS="python3_11 python3_12"' | sudo tee -a squashfs/etc/portage/make.conf
echo 'PYTHON_SINGLE_TARGET="python3_12"' | sudo tee -a squashfs/etc/portage/make.conf

# 2. Fix ionice command
echo "Fixing ionice command..."
sudo sed -i 's/PORTAGE_IONICE_COMMAND=.*/PORTAGE_IONICE_COMMAND="ionice -c 3"/' squashfs/etc/portage/make.conf

# 3. Fix locale in chroot
echo "Fixing locale..."
echo "en_US.UTF-8 UTF-8" | sudo tee squashfs/etc/locale.gen
echo "LANG=\"en_US.UTF-8\"" | sudo tee squashfs/etc/locale.conf

# 4. Create /dev/pts if missing
echo "Ensuring /dev/pts exists..."
sudo mkdir -p squashfs/dev/pts

echo "✓ Issues fixed!"
echo ""
echo "Now you can either:"
echo "1. Continue with ISO creation (recommended - packages are already installed)"
echo "2. Go into recovery mode to install missing packages"
```

## Update build.sh for Future Builds

Replace the problematic sections in build.sh:

```bash
# Fix configure_portage function
configure_portage() {
    echo -e "${CYAN}Configuring Portage using base config...${NC}"
    
    # ... existing code ...
    
    # Append build-specific flags with FIXES
    sudo tee -a squashfs/etc/portage/make.conf > /dev/null << EOF

# --- Dynamic Resource Management ---
# Generated: $(date)
# System: $(free -h | grep Mem | awk '{print $2}') RAM, $(nproc) cores

# Conservative build settings to prevent OOM
MAKEOPTS="-j${JOBS} -l${LOAD}"
EMERGE_DEFAULT_OPTS="--jobs=${JOBS} --load-average=${LOAD} --keep-going"

# Memory management (FIXED ionice command)
PORTAGE_NICENESS="19"
PORTAGE_IONICE_COMMAND="ionice -c 3"

# Python targets (stable versions only)
PYTHON_TARGETS="python3_11 python3_12"
PYTHON_SINGLE_TARGET="python3_12"

# Prevent memory exhaustion
PORTAGE_TMPDIR="/var/tmp"
EOF
    
    # Setup locale in chroot
    echo "en_US.UTF-8 UTF-8" | sudo tee squashfs/etc/locale.gen > /dev/null
    echo "LANG=\"en_US.UTF-8\"" | sudo tee squashfs/etc/locale.conf > /dev/null
    
    echo -e "${GREEN}✓ Portage configured with RaptorOS base config + build overrides${NC}"
}
```

## Fix build_optimized Function

Replace emerge commands to remove `--ask`:

```bash
build_optimized() {
    echo -e "${CYAN}Starting optimized build...${NC}"
    
    setup_build_env
    configure_portage
    configure_repos
    setup_chroot
    
    # Build critical packages from source WITH FIXES
    sudo chroot squashfs /bin/bash << 'CHROOTCMD'
#!/bin/bash
source /etc/profile
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Generate locale if needed
if [ -f /etc/locale.gen ]; then
    locale-gen
fi

# First ensure git is installed for sync
if ! command -v git &> /dev/null; then
    echo "Installing git first..."
    emerge-webrsync
    emerge --oneshot dev-vcs/git
fi

# Sync portage
echo "Syncing portage tree..."
emerge --sync || emerge-webrsync

# Update Python packages first to fix dependency issues
echo "Fixing Python dependencies..."
emerge --oneshot --update dev-python/trove-classifiers dev-python/setuptools

# Update system
echo "Updating base system..."
emerge --update --deep --newuse @world --keep-going

# Build kernel (without --ask)
echo "Building kernel..."
emerge sys-kernel/gentoo-sources

if [ -d /usr/src/linux ]; then
    cd /usr/src/linux
    make defconfig
    make -j${JOBS:-8}
    make modules_install
    make install
fi

# Install essential packages (without --ask)
echo "Installing essential packages..."
emerge --keep-going \
    sys-kernel/linux-firmware \
    sys-boot/grub \
    sys-boot/efibootmgr \
    sys-apps/systemd

# Install GPU drivers (without --ask)
echo "Installing GPU drivers..."
emerge x11-drivers/nvidia-drivers || \
    emerge --getbinpkg x11-drivers/nvidia-drivers

# Gaming packages (without --ask)
echo "Installing gaming packages..."
emerge --getbinpkg --keep-going \
    games-util/steam-launcher \
    games-util/lutris \
    games-util/gamemode \
    app-emulation/wine-staging || echo "Some gaming packages failed, continuing..."

echo "Build completed!"
CHROOTCMD
    
    cleanup_chroot
    create_backup
    create_installer
    create_iso
}
```

## Continue Your Build Now

Since packages are already installed (even with errors), you can:

### Option 1: Create ISO with What You Have (Recommended)
```bash
cd ~/Downloads/RaptorOS-fresh
./build.sh
# Select option 4 (ISO Only)
```

### Option 2: Fix and Continue in Recovery Mode
```bash
cd ~/Downloads/RaptorOS-fresh
# First run the fix script above
./fix-build-issues.sh

# Then enter recovery mode
./build.sh
# Select option 6 (Recovery Mode)
# Then select option 5 (Chroot into existing build)

# In chroot, manually install missing packages:
emerge --update --deep @world
emerge x11-drivers/nvidia-drivers
emerge games-util/steam-launcher
```

## The Good News

✅ The build actually completed despite the errors!  
✅ Basic system is installed  
✅ Kernel might be built (check `/var/tmp/gentoo-gaming-build/squashfs/boot/`)  
✅ You can create an ISO and test it  

The errors were mostly about:
- Python version conflicts (fixable)
- ionice syntax (fixed above)
- Terminal detection for `--ask` (fixed by removing `-av` flags)

Your build is salvageable! Run the fixes and continue.
