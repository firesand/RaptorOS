# 🚨 EMERGENCY PROTECTION GUIDE - Desktop Logout Issue

## 🚨 **CRITICAL ISSUE IDENTIFIED**

Your desktop is being logged out because **systemd services are being killed with SIGKILL**, not because of OOM killer. This is a **system-level issue** that requires immediate action.

## 🔍 **Root Cause Analysis**

From kernel logs:
```
systemd[1]: user@1000.service: Main process exited, code=killed, status=9/KILL
```

**Status=9/KILL** means your entire user session is being forcefully terminated by something other than the OOM killer.

## 🛡️ **IMMEDIATE PROTECTION MEASURES**

### **Step 1: Emergency Diagnostic**
```bash
# Run this immediately to identify the problem
sudo ./scripts/emergency-diagnostic.sh
```

### **Step 2: Session Guardian (CRITICAL)**
```bash
# Run this in a SEPARATE terminal and keep it running
sudo ./scripts/session-guardian.sh
```

### **Step 3: Enhanced OOM Protection**
```bash
# Set up maximum OOM protection
sudo ./scripts/oom-protection.sh

# Start continuous protection in another terminal
sudo ./scripts/continuous-oom-protection.sh
```

## 🚀 **COMPLETE PROTECTION SETUP**

### **Terminal 1: Session Guardian**
```bash
sudo ./scripts/session-guardian.sh
```
**Keep this running at all times during builds!**

### **Terminal 2: OOM Protection**
```bash
sudo ./scripts/oom-protection.sh
sudo ./scripts/continuous-oom-protection.sh
```

### **Terminal 3: Resource Monitor**
```bash
./scripts/resource-monitor.sh
```

### **Terminal 4: Build Process**
```bash
sudo ./build.sh
```

## 🔧 **SYSTEM-LEVEL PROTECTION**

### **Create Systemd Override for User Session**
```bash
# Create protection override
sudo mkdir -p /etc/systemd/system/user@1000.service.d/

sudo tee /etc/systemd/system/user@1000.service.d/emergency-protection.conf > /dev/null << 'EOF'
[Service]
# Maximum OOM protection
OOMScoreAdjust=-1000
# Restart on failure
Restart=always
RestartSec=1
# Maximum restart attempts
StartLimitInterval=0
StartLimitBurst=0
# Memory limits
MemoryMax=80%
MemorySwapMax=0
EOF

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart user@1000.service
```

## 🚨 **IF YOU STILL GET LOGGED OUT**

### **This indicates a deeper system issue:**

1. **Hardware Problem**
   - RAM failure (run `memtest86+`)
   - CPU overheating
   - Power supply issues
   - Motherboard problems

2. **Kernel Issue**
   - Update kernel: `sudo pacman -Syu`
   - Check for kernel bugs
   - Try different kernel version

3. **System Corruption**
   - Check filesystem: `sudo fsck -f /`
   - Reinstall critical packages
   - System restore from backup

## 📋 **EMERGENCY CHECKLIST**

- [ ] Run emergency diagnostic
- [ ] Start Session Guardian
- [ ] Set up OOM protection
- [ ] Create systemd override
- [ ] Monitor resources
- [ ] Check hardware health
- [ ] Update system packages

## 🆘 **LAST RESORT OPTIONS**

### **Option 1: Build in Virtual Machine**
```bash
# Use VirtualBox or QEMU to isolate the build process
# This prevents system crashes from affecting your desktop
```

### **Option 2: Build on Different Machine**
- Use a dedicated build server
- Build in cloud environment
- Use a different physical machine

### **Option 3: Minimal Build Environment**
```bash
# Boot to minimal environment (no desktop)
# Build from console only
# This eliminates desktop session issues
```

## 📞 **IMMEDIATE ACTION REQUIRED**

1. **STOP any current builds**
2. **Run emergency diagnostic**
3. **Start Session Guardian**
4. **Set up all protection measures**
5. **Test with a small build first**

## ⚠️ **WARNING**

This is **NOT** a normal OOM issue. Your entire user session is being killed by something at the system level. The protection measures above are designed to prevent this, but if the issue persists, there is likely a **hardware or kernel problem** that requires professional attention.

**Do not continue building until this issue is resolved!**
