#!/bin/bash
# GPU Driver Selection Module
# Supports NVIDIA (proprietary/open), AMD, Intel, and Nouveau

# Detect GPU and recommend driver
detect_gpu() {
    local gpu_vendor=""
    local gpu_model=""
    
    if lspci | grep -i "vga.*nvidia" > /dev/null; then
        gpu_vendor="nvidia"
        gpu_model=$(lspci | grep -i "vga.*nvidia" | cut -d: -f3 | xargs)
    elif lspci | grep -i "vga.*amd" > /dev/null; then
        gpu_vendor="amd"
        gpu_model=$(lspci | grep -i "vga.*amd" | cut -d: -f3 | xargs)
    elif lspci | grep -i "vga.*intel" > /dev/null; then
        gpu_vendor="intel"
        gpu_model=$(lspci | grep -i "vga.*intel" | cut -d: -f3 | xargs)
    else
        gpu_vendor="unknown"
        gpu_model="Unknown GPU"
    fi
    
    GPU_VENDOR="$gpu_vendor"
    GPU_MODEL="$gpu_model"
}

# Main GPU driver selection
select_gpu_driver() {
    detect_gpu
    
    case "$GPU_VENDOR" in
        "nvidia")
            select_nvidia_driver
            ;;
        "amd")
            select_amd_driver
            ;;
        "intel")
            select_intel_driver
            ;;
        *)
            select_generic_driver
            ;;
    esac
}

# NVIDIA driver selection
select_nvidia_driver() {
    GPU_DRIVER=$(dialog --backtitle "Gentoo Gaming Installer" \
                        --title "NVIDIA GPU Driver Selection" \
                        --radiolist "\nDetected: $GPU_MODEL\n\nSelect driver:\n" \
                        20 75 7 \
                        "nvidia-proprietary" "NVIDIA Proprietary (Best Performance) [RECOMMENDED]" ON \
                        "nvidia-open" "NVIDIA Open Kernel Modules (Partial Open Source)" OFF \
                        "nouveau" "Nouveau (Open Source, Limited Performance)" OFF \
                        "nouveau-nvk" "Nouveau + NVK Vulkan (Experimental)" OFF \
                        "none" "No GPU Driver (Software Rendering)" OFF \
                        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        echo "Installation cancelled"
        exit 1
    fi
    
    # Show driver information
    case "$GPU_DRIVER" in
        "nvidia-proprietary")
            show_nvidia_proprietary_info
            ;;
        "nvidia-open")
            show_nvidia_open_info
            ;;
        "nouveau")
            show_nouveau_info
            ;;
        "nouveau-nvk")
            show_nouveau_nvk_info
            ;;
        "none")
            show_no_driver_warning
            ;;
    esac
}

# AMD driver selection
select_amd_driver() {
    GPU_DRIVER=$(dialog --backtitle "Gentoo Gaming Installer" \
                        --title "AMD GPU Driver Selection" \
                        --radiolist "\nDetected: $GPU_MODEL\n\nSelect driver:\n" \
                        18 75 5 \
                        "amdgpu" "AMDGPU (Open Source) [RECOMMENDED]" ON \
                        "amdgpu-pro" "AMDGPU-PRO (Proprietary OpenCL/Vulkan)" OFF \
                        "radeon" "Radeon (Legacy open source)" OFF \
                        "none" "No GPU Driver" OFF \
                        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        echo "Installation cancelled"
        exit 1
    fi
}

# Intel driver selection
select_intel_driver() {
    GPU_DRIVER=$(dialog --backtitle "Gentoo Gaming Installer" \
                        --title "Intel GPU Driver Selection" \
                        --radiolist "\nDetected: $GPU_MODEL\n\nSelect driver:\n" \
                        16 75 4 \
                        "i915" "Intel i915 (Modern Intel GPUs) [RECOMMENDED]" ON \
                        "xe" "Intel Xe (Arc GPUs)" OFF \
                        "none" "No GPU Driver" OFF \
                        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        echo "Installation cancelled"
        exit 1
    fi
}

# Generic driver selection
select_generic_driver() {
    GPU_DRIVER=$(dialog --backtitle "Gentoo Gaming Installer" \
                        --title "GPU Driver Selection" \
                        --radiolist "\nNo specific GPU detected.\n\nSelect driver:\n" \
                        16 75 4 \
                        "modesetting" "Generic Modesetting Driver [RECOMMENDED]" ON \
                        "vesa" "VESA (Basic compatibility)" OFF \
                        "none" "No GPU Driver" OFF \
                        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        echo "Installation cancelled"
        exit 1
    fi
}

# Show NVIDIA proprietary driver info
show_nvidia_proprietary_info() {
    dialog --backtitle "Gentoo Gaming Installer" \
           --title "NVIDIA Proprietary Driver" \
           --msgbox "\n\
NVIDIA Proprietary Driver Selected
═══════════════════════════════════════════════════════

✅ Advantages:
• Full GPU performance (100% capability)
• DLSS 3, Ray Tracing, Frame Generation
• CUDA, NVENC, OptiX support
• Resizable BAR support
• Best gaming performance
• G-Sync/VRR support

⚠️ Note:
• Closed source (proprietary)
• Requires kernel module signing
• May need manual updates for new kernels

This is the RECOMMENDED choice for gaming with RTX GPUs!" \
           20 65
}

# Show NVIDIA open kernel modules info
show_nvidia_open_info() {
    dialog --backtitle "Gentoo Gaming Installer" \
           --title "NVIDIA Open Kernel Modules" \
           --msgbox "\n\
NVIDIA Open GPU Kernel Modules Selected
═══════════════════════════════════════════════════════

ℹ️ About:
• Open source kernel modules from NVIDIA
• Userspace remains proprietary
• Supports Turing (RTX 20xx) and newer

✅ Advantages:
• Kernel modules are open source
• Better kernel integration
• Same performance as proprietary
• Supports all RTX features

⚠️ Note:
• Userspace (OpenGL/Vulkan) still proprietary
• Newer, less tested than proprietary

Performance: ~95-100% of proprietary driver" \
           20 65
}

# Show Nouveau info
show_nouveau_info() {
    dialog --colors --backtitle "Gentoo Gaming Installer" \
           --title "⚠️ Nouveau Open Source Driver" \
           --msgbox "\n\
Nouveau - Reverse Engineered Open Driver
═══════════════════════════════════════════════════════

\Z1⚠️ WARNING: Limited RTX Support!\Zn

❌ Limitations for RTX GPUs:
• NO reclocking (stuck at boot clocks ~300MHz)
• Performance: ~5-10% of proprietary
• NO DLSS, Ray Tracing, or CUDA
• NO hardware video acceleration
• May have stability issues

✅ Advantages:
• Fully open source (GPL)
• Part of mainline kernel
• No proprietary code

\Z1NOT RECOMMENDED for gaming!\Zn
Only choose if you require 100% open source." \
           22 65
}

# Show NVK info
show_nouveau_nvk_info() {
    dialog --colors --backtitle "Gentoo Gaming Installer" \
           --title "🧪 Nouveau + NVK (Experimental)" \
           --msgbox "\n\
NVK - New Open Source Vulkan Driver
═══════════════════════════════════════════════════════

\Z1🧪 HIGHLY EXPERIMENTAL!\Zn

ℹ️ About NVK:
• Brand new Vulkan driver for NVIDIA
• Part of Mesa 24.0+
• Very early development stage

⚠️ Current Status:
• Basic Vulkan support only
• Still has reclocking issues
• Performance: ~10-15% of proprietary
• Many games won't work
• Frequent crashes expected

\Z1For testing/development only - NOT for gaming!\Zn" \
           20 65
}

# No driver warning
show_no_driver_warning() {
    dialog --colors --backtitle "Gentoo Gaming Installer" \
           --title "⛔ No GPU Driver" \
           --defaultno \
           --yesno "\n\
\Z1⛔ WARNING: No GPU Acceleration!\Zn

Selecting no driver means:
• Software rendering only (llvmpipe)
• NO hardware acceleration
• NO gaming capability
• Very poor graphics performance
• High CPU usage for graphics

This is only useful for:
• Headless servers
• Recovery situations

\Z1Are you SURE you want no GPU driver?\Zn" \
           18 55
    
    if [ $? -ne 0 ]; then
        select_gpu_driver
    fi
}

# Install GPU driver
install_gpu_driver() {
    case "$GPU_DRIVER" in
        "nvidia-proprietary")
            install_nvidia_proprietary
            ;;
        "nvidia-open")
            install_nvidia_open
            ;;
        "nouveau"|"nouveau-nvk")
            install_nouveau
            ;;
        "amdgpu")
            install_amdgpu
            ;;
        "i915"|"xe")
            install_intel
            ;;
        "none")
            log "No GPU driver selected"
            ;;
    esac
}

# Install NVIDIA proprietary
install_nvidia_proprietary() {
    log "Installing NVIDIA proprietary drivers"
    
    # Use package.env instead of modifying make.conf (RaptorOS modern approach)
    mkdir -p /mnt/gentoo/etc/portage/env
    cat > /mnt/gentoo/etc/portage/env/nvidia-gaming << 'EOF'
VIDEO_CARDS="nvidia"
USE="${USE} nvidia nvenc cuda"
EOF

    # Apply to NVIDIA drivers package
    mkdir -p /mnt/gentoo/etc/portage/package.env
    echo "x11-drivers/nvidia-drivers nvidia-gaming" >> /mnt/gentoo/etc/portage/package.env
    
    # Accept license
    echo "x11-drivers/nvidia-drivers NVIDIA-r2" >> /mnt/gentoo/etc/portage/package.license
    
    # Install in chroot
    chroot /mnt/gentoo emerge -av x11-drivers/nvidia-drivers
    
    # Configure
    cat > /mnt/gentoo/etc/modprobe.d/nvidia.conf << 'EOF'
# RTX 4090 Optimizations
options nvidia NVreg_EnableResizableBar=1
options nvidia NVreg_EnablePCIeGen3=0
options nvidia NVreg_EnableGpuFirmware=1
options nvidia NVreg_EnableStreamMemOPs=1
options nvidia NVreg_DynamicPowerManagement=0
options nvidia-drm modeset=1 fbdev=1
EOF
    
    # Add modules to load
    echo -e "nvidia\nnvidia-modeset\nnvidia-uvm\nnvidia-drm" >> /mnt/gentoo/etc/modules-load.d/nvidia.conf
}

# Install NVIDIA open kernel modules
install_nvidia_open() {
    log "Installing NVIDIA open kernel modules"
    
    # Use package.env instead of modifying make.conf (RaptorOS modern approach)
    mkdir -p /mnt/gentoo/etc/portage/env
    cat > /mnt/gentoo/etc/portage/env/nvidia-open << 'EOF'
VIDEO_CARDS="nvidia"
USE="${USE} nvidia kernel-open"
EOF

    # Apply to NVIDIA drivers package
    mkdir -p /mnt/gentoo/etc/portage/package.env
    echo "x11-drivers/nvidia-drivers nvidia-open" >> /mnt/gentoo/etc/portage/package.env
    echo "x11-drivers/nvidia-drivers kernel-open" >> /mnt/gentoo/etc/portage/package.use/nvidia
    
    chroot /mnt/gentoo emerge -av x11-drivers/nvidia-drivers
}

# Install Nouveau
install_nouveau() {
    log "Installing Nouveau open source driver"
    
    # Use package.env instead of modifying make.conf (RaptorOS modern approach)
    mkdir -p /mnt/gentoo/etc/portage/env
    cat > /mnt/gentoo/etc/portage/env/nouveau-gaming << 'EOF'
VIDEO_CARDS="nouveau"
USE="${USE} gallium"
EOF

    # Apply to Mesa package
    mkdir -p /mnt/gentoo/etc/portage/package.env
    echo "media-libs/mesa nouveau-gaming" >> /mnt/gentoo/etc/portage/package.env
    
    chroot /mnt/gentoo emerge -av media-libs/mesa
    
    if [[ "$GPU_DRIVER" == "nouveau-nvk" ]]; then
        echo "media-libs/mesa nvk" >> /mnt/gentoo/etc/portage/package.use/mesa
    fi
}

# Install AMD GPU driver
install_amdgpu() {
    log "Installing AMDGPU driver"
    
    # Use package.env instead of modifying make.conf (RaptorOS modern approach)
    mkdir -p /mnt/gentoo/etc/portage/env
    cat > /mnt/gentoo/etc/portage/env/amd-gaming << 'EOF'
VIDEO_CARDS="amdgpu radeonsi"
USE="${USE} vulkan vaapi"
EOF

    # Apply to Mesa and AMDGPU packages
    mkdir -p /mnt/gentoo/etc/portage/package.env
    echo "media-libs/mesa amd-gaming" >> /mnt/gentoo/etc/portage/package.env
    echo "x11-drivers/xf86-video-amdgpu amd-gaming" >> /mnt/gentoo/etc/portage/package.env
    
    chroot /mnt/gentoo emerge -av media-libs/mesa x11-drivers/xf86-video-amdgpu
}

# Install Intel driver
install_intel() {
    log "Installing Intel GPU driver"
    
    # Use package.env instead of modifying make.conf (RaptorOS modern approach)
    mkdir -p /mnt/gentoo/etc/portage/env
    cat > /mnt/gentoo/etc/portage/env/intel-gaming << 'EOF'
VIDEO_CARDS="intel i915"
USE="${USE} vulkan vaapi"
EOF

    # Apply to Mesa and Intel packages
    mkdir -p /mnt/gentoo/etc/portage/package.env
    echo "media-libs/mesa intel-gaming" >> /mnt/gentoo/etc/portage/package.env
    echo "x11-drivers/xf86-video-intel intel-gaming" >> /mnt/gentoo/etc/portage/package.env
    
    chroot /mnt/gentoo emerge -av media-libs/mesa x11-drivers/xf86-video-intel
}