#!/bin/bash
# Emergency cleanup of Gentoo build mounts
# Use this if your system becomes unstable after interrupting a build

echo "Emergency cleanup of Gentoo build mounts..."

# Find and unmount all gentoo-related mounts
BUILD_DIR="/var/tmp/gentoo-gaming-build"

# Force unmount in reverse order (important!)
if [ -d "$BUILD_DIR/squashfs" ]; then
    echo "Unmounting chroot filesystems..."
    
    # Kill any processes using the mounts
    sudo fuser -km "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/proc" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo fuser -km "$BUILD_DIR/squashfs/run" 2>/dev/null || true
    
    # Unmount everything
    sudo umount -R "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo umount -R "$BUILD_DIR/squashfs/proc" 2>/dev/null || true  
    sudo umount -R "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo umount -R "$BUILD_DIR/squashfs/run" 2>/dev/null || true
    
    # Force unmount if still mounted
    sudo umount -lf "$BUILD_DIR/squashfs/dev" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/proc" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/sys" 2>/dev/null || true
    sudo umount -lf "$BUILD_DIR/squashfs/run" 2>/dev/null || true
fi

# Check what's still mounted
echo ""
echo "Checking for remaining mounts..."
mount | grep "$BUILD_DIR" || echo "All mounts cleaned!"

echo "System should be stable now."
