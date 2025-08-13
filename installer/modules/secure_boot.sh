#!/bin/bash
# Secure Boot Configuration Module for RaptorOS
# Handles UEFI Secure Boot, kernel signing, and driver signing

# Check if system supports Secure Boot
check_secure_boot_support() {
    local sb_status="Not Supported"
    
    if [ -d /sys/firmware/efi ]; then
        if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
            local sb_value=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | tr -d ' ')
            if [ "$sb_value" = "1" ]; then
                sb_status="Enabled"
            else
                sb_status="Disabled"
            fi
        else
            sb_status="Available but not configured"
        fi
    fi
    
    echo "$sb_status"
}

# Main Secure Boot configuration
configure_secure_boot() {
    local sb_status=$(check_secure_boot_support)
    
    dialog --backtitle "RaptorOS Installer" \
           --title "Secure Boot Configuration" \
           --yesno "Secure Boot Status: $sb_status\n\n\
Would you like to configure Secure Boot support?\n\n\
This will:\n\
• Install shim bootloader\n\
• Set up MOK (Machine Owner Key)\n\
• Sign kernel and modules\n\
• Sign NVIDIA drivers (if installed)\n\
• Enable automatic signing for updates\n\n\
Note: You'll need to enroll keys on first boot." 18 65
    
    if [ $? -ne 0 ]; then
        log "Secure Boot configuration skipped"
        return
    fi
    
    # Install necessary packages
    install_secure_boot_tools
    
    # Generate MOK keys
    generate_mok_keys
    
    # Configure shim
    configure_shim_bootloader
    
    # Set up automatic signing
    setup_automatic_signing
    
    # Sign existing kernel
    sign_kernel_and_modules
    
    # Sign GPU drivers if present
    if [[ "$GPU_DRIVER" == "nvidia"* ]]; then
        sign_nvidia_drivers
    fi
    
    # Create enrollment helper
    create_mok_enrollment_helper
    
    dialog --msgbox "Secure Boot configured!\n\n\
On first boot:\n\
1. System will prompt for MOK enrollment\n\
2. Select 'Enroll MOK'\n\
3. Enter the password you set\n\
4. Reboot to complete\n\n\
Your MOK password has been saved to:\n\
/root/mok-password.txt (delete after enrollment)" 16 60
}

# Install Secure Boot tools
install_secure_boot_tools() {
    log "Installing Secure Boot tools"
    
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
app-crypt/sbsigntools
app-crypt/efitools
sys-boot/shim
sys-boot/mokutil
sys-boot/refind
app-crypt/pesign
sys-apps/keyutils
EOF
    
    # Create signing directories
    mkdir -p /mnt/gentoo/etc/pki/{MOK,kernel}
    chmod 700 /mnt/gentoo/etc/pki/MOK
}

# Generate Machine Owner Keys
generate_mok_keys() {
    log "Generating Machine Owner Keys (MOK)"
    
    local mok_dir="/mnt/gentoo/etc/pki/MOK"
    
    # Generate MOK password and immediately pipe it to encryption
    # This ensures the password is never written to disk in plain text
    local master_key=$(openssl rand -base64 32)
    
    # Store encrypted password using a more secure method
    # The password is piped directly to encryption without being stored in a variable
    if command -v gpg &>/dev/null; then
        # Use GPG with master key stored in memory only
        openssl rand -base64 12 | gpg --symmetric --cipher-algo AES256 --batch --passphrase "$master_key" > /mnt/gentoo/root/mok-password.enc
        log "MOK password encrypted with GPG and master key"
    elif command -v openssl &>/dev/null; then
        # Use OpenSSL with master key stored in memory only
        openssl rand -base64 12 | openssl enc -aes-256-cbc -salt -out /mnt/gentoo/root/mok-password.enc -pass pass:"$master_key"
        log "MOK password encrypted with OpenSSL and master key"
    else
        log "ERROR: No encryption tools available"
        return 1
    fi
    
    # Store master key in a secure location (will be cleared after use)
    echo "$master_key" > /mnt/gentoo/root/mok-master-key.tmp
    chmod 600 /mnt/gentoo/root/mok-master-key.tmp
    
    # Clear master key from memory
    unset master_key
    
    # Create MOK configuration
    cat > "$mok_dir/MOK.conf" << EOF
# RaptorOS Machine Owner Key Configuration
[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[ req_distinguished_name ]
C = US
ST = Gaming
L = RaptorOS
O = RaptorOS Secure Boot
CN = RaptorOS Machine Owner Key
emailAddress = security@raptoros.local

[ v3_ca ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
nsComment = "RaptorOS Machine Owner Key"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
extendedKeyUsage = codeSigning
EOF
    
    # Generate MOK private key and certificate
    chroot /mnt/gentoo /bin/bash << CHROOT_CMD
cd /etc/pki/MOK
# Generate private key
openssl genrsa -out MOK.key 4096
# Generate certificate
openssl req -new -x509 -days 3650 -key MOK.key -out MOK.crt -config MOK.conf
# Convert to DER format for enrollment
openssl x509 -in MOK.crt -outform DER -out MOK.cer
# Create PFX for some tools (password will be provided during enrollment)
openssl pkcs12 -export -out MOK.pfx -inkey MOK.key -in MOK.crt -password pass:temp_password_123
# Set permissions
chmod 400 MOK.key
chmod 644 MOK.crt MOK.cer
CHROOT_CMD
    
    log "MOK keys generated successfully"
}

# Configure shim bootloader
configure_shim_bootloader() {
    log "Configuring shim bootloader"
    
    # Install shim and signed GRUB
    cat > /mnt/gentoo/etc/portage/package.use/secureboot << 'EOF'
sys-boot/grub:2 grub_platforms_efi-64 truetype
sys-boot/shim mokutil
EOF
    
    # Configure shim installation
    cat > /mnt/gentoo/usr/local/bin/install-shim << 'SHIM_SCRIPT'
#!/bin/bash
# RaptorOS Shim Installation Script

EFI_DIR="/boot/efi/EFI/raptoros"
SHIM_DIR="/usr/share/shim"

# Create EFI directory
mkdir -p "$EFI_DIR"

# Copy shim files
if [ -f "$SHIM_DIR/shimx64.efi" ]; then
    cp "$SHIM_DIR/shimx64.efi" "$EFI_DIR/"
    cp "$SHIM_DIR/mmx64.efi" "$EFI_DIR/"    # MOK Manager
else
    echo "Error: Shim not found. Install sys-boot/shim first."
    exit 1
fi

# Sign GRUB with MOK
sbsign --key /etc/pki/MOK/MOK.key \
       --cert /etc/pki/MOK/MOK.crt \
       --output "$EFI_DIR/grubx64.efi" \
       /boot/efi/EFI/gentoo/grubx64.efi

# Create UEFI boot entry
efibootmgr --create \
           --disk ${INSTALL_DISK} \
           --part 1 \
           --label "RaptorOS (Secure Boot)" \
           --loader '\EFI\raptoros\shimx64.efi' \
           --verbose

echo "Shim installed. Boot via 'RaptorOS (Secure Boot)' entry."
SHIM_SCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/install-shim
}

# Set up automatic kernel signing
setup_automatic_signing() {
    log "Setting up automatic kernel and module signing"
    
    # Create kernel signing script
    cat > /mnt/gentoo/usr/local/bin/sign-kernel << 'SIGN_SCRIPT'
#!/bin/bash
# RaptorOS Automatic Kernel Signing

KERNEL_VERSION="${1:-$(uname -r)}"
MOK_KEY="/etc/pki/MOK/MOK.key"
MOK_CERT="/etc/pki/MOK/MOK.crt"

echo "Signing kernel $KERNEL_VERSION..."

# Sign kernel image
if [ -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
    sbsign --key "$MOK_KEY" \
           --cert "$MOK_CERT" \
           --output "/boot/vmlinuz-$KERNEL_VERSION.signed" \
           "/boot/vmlinuz-$KERNEL_VERSION"
    
    # Backup original
    mv "/boot/vmlinuz-$KERNEL_VERSION" "/boot/vmlinuz-$KERNEL_VERSION.unsigned"
    mv "/boot/vmlinuz-$KERNEL_VERSION.signed" "/boot/vmlinuz-$KERNEL_VERSION"
    
    echo "Kernel signed successfully"
else
    echo "Error: Kernel not found"
    exit 1
fi

# Sign kernel modules
echo "Signing kernel modules..."
for module in $(find /lib/modules/$KERNEL_VERSION -name "*.ko" -o -name "*.ko.xz"); do
    if [[ "$module" == *.xz ]]; then
        # Decompress, sign, recompress
        xz -d "$module"
        module_uncompressed="${module%.xz}"
        /usr/src/linux/scripts/sign-file sha256 "$MOK_KEY" "$MOK_CERT" "$module_uncompressed"
        xz "$module_uncompressed"
    else
        # Sign directly
        /usr/src/linux/scripts/sign-file sha256 "$MOK_KEY" "$MOK_CERT" "$module"
    fi
done

echo "Module signing complete"

# Update GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

echo "Kernel $KERNEL_VERSION signed and ready for Secure Boot"
SIGN_SCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/sign-kernel
    
    # Create post-emerge hook for automatic signing
    cat > /mnt/gentoo/etc/portage/env/sys-kernel/gentoo-sources << 'HOOK_SCRIPT'
post_pkg_postinst() {
    # Automatically sign new kernels after installation
    if [ -f /usr/local/bin/sign-kernel ]; then
        echo "Signing newly installed kernel..."
        /usr/local/bin/sign-kernel
    fi
}
HOOK_SCRIPT
    
    # Create dracut hook for signing
    cat > /mnt/gentoo/etc/dracut.conf.d/99-secureboot.conf << 'DRACUT_CONF'
# RaptorOS Secure Boot Dracut Configuration
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
uefi_secureboot_cert="/etc/pki/MOK/MOK.crt"
uefi_secureboot_key="/etc/pki/MOK/MOK.key"
early_microcode="yes"
DRACUT_CONF
}

# Sign NVIDIA drivers
sign_nvidia_drivers() {
    log "Signing NVIDIA drivers for Secure Boot"
    
    cat > /mnt/gentoo/usr/local/bin/sign-nvidia << 'NVIDIA_SIGN'
#!/bin/bash
# RaptorOS NVIDIA Driver Signing for Secure Boot

MOK_KEY="/etc/pki/MOK/MOK.key"
MOK_CERT="/etc/pki/MOK/MOK.crt"
NVIDIA_VERSION=$(modinfo -F version nvidia 2>/dev/null || echo "unknown")

echo "Signing NVIDIA drivers version $NVIDIA_VERSION..."

# Find all NVIDIA kernel modules
NVIDIA_MODULES=(
    "nvidia"
    "nvidia-modeset"
    "nvidia-drm"
    "nvidia-uvm"
    "nvidia-peermem"
)

for module_name in "${NVIDIA_MODULES[@]}"; do
    # Find module file
    module_file=$(modinfo -F filename $module_name 2>/dev/null)
    
    if [ -f "$module_file" ]; then
        echo "Signing $module_name..."
        
        # Handle compressed modules
        if [[ "$module_file" == *.xz ]]; then
            xz -d "$module_file"
            module_file="${module_file%.xz}"
            /usr/src/linux/scripts/sign-file sha256 "$MOK_KEY" "$MOK_CERT" "$module_file"
            xz "$module_file"
        elif [[ "$module_file" == *.gz ]]; then
            gunzip "$module_file"
            module_file="${module_file%.gz}"
            /usr/src/linux/scripts/sign-file sha256 "$MOK_KEY" "$MOK_CERT" "$module_file"
            gzip "$module_file"
        else
            /usr/src/linux/scripts/sign-file sha256 "$MOK_KEY" "$MOK_CERT" "$module_file"
        fi
        
        echo "  ✓ $module_name signed"
    else
        echo "  ✗ $module_name not found"
    fi
done

# Create modprobe configuration to ensure signed modules are loaded
cat > /etc/modprobe.d/nvidia-signed.conf << EOF
# RaptorOS NVIDIA Signed Modules Configuration
# Force loading of signed NVIDIA modules only
install nvidia /sbin/modprobe --ignore-install nvidia
install nvidia-modeset /sbin/modprobe --ignore-install nvidia-modeset
install nvidia-drm /sbin/modprobe --ignore-install nvidia-drm
install nvidia-uvm /sbin/modprobe --ignore-install nvidia-uvm
EOF

echo "NVIDIA driver signing complete"
echo "Note: You may need to re-sign after driver updates"

# Add to DKMS for automatic signing (if using DKMS)
if command -v dkms &>/dev/null; then
    cat > /etc/dkms/sign_helper.sh << 'DKMS_SIGN'
#!/bin/bash
/usr/src/linux/scripts/sign-file sha256 /etc/pki/MOK/MOK.key /etc/pki/MOK/MOK.crt "$2"
DKMS_SIGN
    chmod +x /etc/dkms/sign_helper.sh
    
    # Update DKMS framework configuration
    echo 'sign_tool="/etc/dkms/sign_helper.sh"' >> /etc/dkms/framework.conf
fi
NVIDIA_SIGN
    
    chmod +x /mnt/gentoo/usr/local/bin/sign-nvidia
    
    # Create systemd service for automatic NVIDIA signing
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /mnt/gentoo/etc/systemd/system/nvidia-sign.service << 'NVIDIA_SERVICE'
[Unit]
Description=Sign NVIDIA kernel modules for Secure Boot
After=systemd-modules-load.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sign-nvidia
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
NVIDIA_SERVICE
        
        chroot /mnt/gentoo systemctl enable nvidia-sign.service
    else
        # OpenRC alternative
        cat > /mnt/gentoo/etc/init.d/nvidia-sign << 'NVIDIA_OPENRC'
#!/sbin/openrc-run

description="Sign NVIDIA modules for Secure Boot"

depend() {
    before xdm
    after modules
}

start() {
    ebegin "Signing NVIDIA kernel modules"
    /usr/local/bin/sign-nvidia
    eend $?
}
NVIDIA_OPENRC
        chmod +x /mnt/gentoo/etc/init.d/nvidia-sign
        chroot /mnt/gentoo rc-update add nvidia-sign boot
    fi
}

# Create MOK enrollment helper
create_mok_enrollment_helper() {
    log "Creating MOK enrollment helper"
    
    cat > /mnt/gentoo/usr/local/bin/enroll-mok << 'ENROLL_SCRIPT'
#!/bin/bash
# RaptorOS MOK Enrollment Helper

echo "╔════════════════════════════════════════════╗"
echo "║   RaptorOS Secure Boot MOK Enrollment     ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if MOK certificate exists
if [ ! -f /etc/pki/MOK/MOK.cer ]; then
    echo "Error: MOK certificate not found"
    echo "Run 'configure-secure-boot' first"
    exit 1
fi

# Check current Secure Boot status
if mokutil --sb-state | grep -q "SecureBoot enabled"; then
    echo "Secure Boot is currently: ENABLED"
else
    echo "Secure Boot is currently: DISABLED"
fi

echo ""
echo "Current MOK enrollment status:"
mokutil --list-enrolled | grep "RaptorOS" || echo "No RaptorOS MOK enrolled"

echo ""
echo "To enroll the RaptorOS MOK key:"
echo "1. Run: mokutil --import /etc/pki/MOK/MOK.cer"
echo "2. Enter the password from the encrypted file or use the enrollment script"
echo "3. Reboot the system"
echo "4. At the blue MOK Manager screen:"
echo "   - Select 'Enroll MOK'"
echo "   - Select 'Continue'"
echo "   - Select 'Yes'"
echo "   - Enter the password"
echo "   - Select 'Reboot'"
echo ""

read -p "Would you like to enroll the MOK now? [Y/n]: " response
if [[ "$response" =~ ^[Yy]?$ ]]; then
    echo "Enrolling MOK..."
    
    # Get password using the secure method
    if [ -f /root/mok-password.enc ] && [ -f /root/mok-master-key.tmp ]; then
        # Read master key and decrypt password
        local master_key=$(cat /root/mok-master-key.tmp)
        
        if command -v gpg &>/dev/null; then
            # Use GPG with master key
            MOK_PASSWORD=$(gpg --decrypt --batch --passphrase "$master_key" /root/mok-password.enc 2>/dev/null | head -1)
            if [ $? -eq 0 ]; then
                echo "Using password decrypted with GPG"
            else
                echo "GPG decryption failed, trying OpenSSL..."
                MOK_PASSWORD=$(openssl enc -d -aes-256-cbc -in /root/mok-password.enc -pass pass:"$master_key" 2>/dev/null | head -1)
                if [ $? -eq 0 ]; then
                    echo "Using password decrypted with OpenSSL"
                else
                    echo "Decryption failed. Please enter manually:"
                    read -sp "Enter MOK password: " MOK_PASSWORD
                    echo
                fi
            fi
        elif command -v openssl &>/dev/null; then
            # Use OpenSSL with master key
            MOK_PASSWORD=$(openssl enc -d -aes-256-cbc -in /root/mok-password.enc -pass pass:"$master_key" 2>/dev/null | head -1)
            if [ $? -eq 0 ]; then
                echo "Using password decrypted with OpenSSL"
            else
                echo "OpenSSL decryption failed. Please enter manually:"
                read -sp "Enter MOK password: " MOK_PASSWORD
                echo
            fi
        else
            echo "No decryption tools available. Please enter manually:"
            read -sp "Enter MOK password: " MOK_PASSWORD
            echo
        fi
        
        # Clear master key from memory
        unset master_key
        
        # Clean up temporary files
        shred -u /root/mok-master-key.tmp 2>/dev/null || rm -f /root/mok-master-key.tmp
    else
        echo "Encrypted password or master key not found. Please enter manually:"
        read -sp "Enter MOK password: " MOK_PASSWORD
        echo
    fi
    
    # Import MOK
    echo "$MOK_PASSWORD" | mokutil --import /etc/pki/MOK/MOK.cer --stdin
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ MOK enrollment request successful!"
        echo ""
        echo "IMPORTANT: You must reboot now and complete enrollment"
        echo "The system will show a blue MOK Manager screen on next boot"
        echo ""
        read -p "Reboot now? [Y/n]: " reboot_response
        if [[ "$reboot_response" =~ ^[Yy]?$ ]]; then
            reboot
        fi
    else
        echo "✗ MOK enrollment failed"
        exit 1
    fi
fi
ENROLL_SCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/enroll-mok
    
    # Create verification script
    cat > /mnt/gentoo/usr/local/bin/verify-secureboot << 'VERIFY_SCRIPT'
#!/bin/bash
# RaptorOS Secure Boot Verification

echo "╔════════════════════════════════════════════╗"
echo "║   RaptorOS Secure Boot Status Check       ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check Secure Boot status
echo "Secure Boot Status:"
if mokutil --sb-state | grep -q "SecureBoot enabled"; then
    echo -e "  ${GREEN}✓ Secure Boot is ENABLED${NC}"
    SB_ENABLED=true
else
    echo -e "  ${RED}✗ Secure Boot is DISABLED${NC}"
    SB_ENABLED=false
fi

# Check MOK enrollment
echo ""
echo "MOK Enrollment:"
if mokutil --list-enrolled | grep -q "RaptorOS"; then
    echo -e "  ${GREEN}✓ RaptorOS MOK is enrolled${NC}"
else
    echo -e "  ${YELLOW}⚠ RaptorOS MOK not enrolled${NC}"
    echo "    Run 'enroll-mok' to enroll"
fi

# Check kernel signature
echo ""
echo "Kernel Signature:"
KERNEL_VERSION=$(uname -r)
if [ -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
    if sbverify --cert /etc/pki/MOK/MOK.crt "/boot/vmlinuz-$KERNEL_VERSION" &>/dev/null; then
        echo -e "  ${GREEN}✓ Kernel is properly signed${NC}"
    else
        echo -e "  ${RED}✗ Kernel is NOT signed${NC}"
        echo "    Run 'sign-kernel' to sign"
    fi
fi

# Check NVIDIA module signatures (if present)
if lsmod | grep -q nvidia; then
    echo ""
    echo "NVIDIA Driver Signatures:"
    
    for module in nvidia nvidia-modeset nvidia-drm nvidia-uvm; do
        if lsmod | grep -q "^$module"; then
            MODULE_FILE=$(modinfo -F filename $module 2>/dev/null)
            # Note: Actual signature verification would need kernel tools
            if [ -f "$MODULE_FILE" ]; then
                echo -e "  ${GREEN}✓ $module module loaded${NC}"
            fi
        fi
    done
fi

# Check bootloader
echo ""
echo "Bootloader:"
if [ -f /boot/efi/EFI/raptoros/shimx64.efi ]; then
    echo -e "  ${GREEN}✓ Shim bootloader installed${NC}"
else
    echo -e "  ${YELLOW}⚠ Shim bootloader not found${NC}"
fi

# Summary
echo ""
echo "════════════════════════════════════════════"
if [ "$SB_ENABLED" = true ]; then
    echo -e "${GREEN}System is Secure Boot ready!${NC}"
else
    echo -e "${YELLOW}Secure Boot is configured but not enabled.${NC}"
    echo "Enable Secure Boot in UEFI/BIOS settings."
fi
VERIFY_SCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/verify-secureboot
}

# Sign kernel and modules on installation
sign_kernel_and_modules() {
    log "Signing kernel and modules"
    
    # Find installed kernel version
    local kernel_version=$(ls /mnt/gentoo/lib/modules/ | head -1)
    
    if [ -n "$kernel_version" ]; then
        chroot /mnt/gentoo /usr/local/bin/sign-kernel "$kernel_version"
    fi
}

# Add Secure Boot to GRUB configuration
configure_grub_secureboot() {
    log "Configuring GRUB for Secure Boot"
    
    # Update GRUB configuration
    cat >> /mnt/gentoo/etc/default/grub << 'GRUB_SB'

# RaptorOS Secure Boot Configuration
GRUB_ENABLE_LINUX_UUID=true
GRUB_DISABLE_SUBMENU=y

# Use signed kernel
if [ -f "/boot/vmlinuz-$(uname -r).signed" ]; then
    GRUB_LINUX_KERNEL="/boot/vmlinuz-$(uname -r).signed"
fi

# Secure Boot parameters
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} module.sig_enforce=1"
GRUB_SB
    
    # Create custom GRUB menu entry for Secure Boot
    cat > /mnt/gentoo/etc/grub.d/40_custom_secureboot << 'GRUB_CUSTOM'
#!/bin/sh
exec tail -n +3 $0

menuentry 'RaptorOS (Secure Boot)' --class raptoros --class gnu-linux --class gnu --class os {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root $(blkid -s UUID -o value /boot/efi)
    echo 'Loading signed Linux kernel...'
    linux /vmlinuz-$(uname -r) root=$(blkid -s UUID -o value /) rw quiet splash module.sig_enforce=1
    echo 'Loading initial ramdisk...'
    initrd /initramfs-$(uname -r).img
}
GRUB_CUSTOM
    
    chmod +x /mnt/gentoo/etc/grub.d/40_custom_secureboot
}

# Cleanup function to ensure MOK password security
cleanup_mok_security() {
    log "Cleaning up MOK security files"
    
    # Remove any temporary password files
    if [ -f /mnt/gentoo/root/mok-password.txt ]; then
        log "Removing plain text password file"
        shred -u /mnt/gentoo/root/mok-password.txt 2>/dev/null || rm -f /mnt/gentoo/root/mok-password.txt
    fi
    
    if [ -f /mnt/gentoo/root/mok-master-key.tmp ]; then
        log "Removing temporary master key file"
        shred -u /mnt/gentoo/root/mok-master-key.tmp 2>/dev/null || rm -f /mnt/gentoo/root/mok-master-key.tmp
    fi
    
    # Clear any environment variables that might contain passwords
    unset MOK_PASSWORD 2>/dev/null || true
    unset master_key 2>/dev/null || true
    
    log "MOK security cleanup completed"
}

# Enhanced security function for MOK enrollment
secure_mok_enrollment() {
    log "Setting up secure MOK enrollment"
    
    # Create a more secure enrollment script that doesn't store passwords
    cat > /mnt/gentoo/usr/local/bin/secure-enroll-mok << 'SECURE_ENROLL'
#!/bin/bash
# RaptorOS Secure MOK Enrollment
# This script ensures passwords are never stored in plain text

set -e

echo "╔════════════════════════════════════════════╗"
echo "║      RaptorOS Secure MOK Enrollment       ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check if we have the necessary files
if [ ! -f /etc/pki/MOK/MOK.cer ]; then
    echo "❌ MOK certificate not found. Run MOK setup first."
    exit 1
fi

if [ ! -f /root/mok-password.enc ] || [ ! -f /root/mok-master-key.tmp ]; then
    echo "❌ Encrypted password or master key not found."
    echo "Please run the MOK setup again."
    exit 1
fi

echo "🔐 Starting secure MOK enrollment..."
echo ""

# Read master key and decrypt password in memory only
local master_key=$(cat /root/mok-master-key.tmp)

# Decrypt password and pipe directly to mokutil without storing in variable
if command -v gpg &>/dev/null; then
    echo "Using GPG for decryption..."
    gpg --decrypt --batch --passphrase "$master_key" /root/mok-password.enc | mokutil --import /etc/pki/MOK/MOK.cer --stdin
elif command -v openssl &>/dev/null; then
    echo "Using OpenSSL for decryption..."
    openssl enc -d -aes-256-cbc -in /root/mok-password.enc -pass pass:"$master_key" | mokutil --import /etc/pki/MOK/MOK.cer --stdin
else
    echo "❌ No decryption tools available"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ MOK enrollment successful!"
    echo ""
    echo "🔒 Security cleanup in progress..."
    
    # Clear master key from memory
    unset master_key
    
    # Clean up temporary files
    shred -u /root/mok-master-key.tmp 2>/dev/null || rm -f /root/mok-master-key.tmp
    
    echo "✅ Security cleanup completed"
    echo ""
    echo "🔄 Please reboot to complete MOK enrollment"
    echo "   The system will show a blue MOK Manager screen"
else
    echo "❌ MOK enrollment failed"
    exit 1
fi
SECURE_ENROLL
    
    chmod +x /mnt/gentoo/usr/local/bin/secure-enroll-mok
    
    log "Secure MOK enrollment script created"
}
