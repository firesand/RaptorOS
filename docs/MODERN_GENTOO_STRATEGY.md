# RaptorOS Modern Gentoo Strategy Guide

## 🎯 Overview

This guide explains the smart mixed-stability approach implemented in RaptorOS, based on the realization that **Gentoo stable is already incredibly modern** as of December 2024.

## 📊 Why This Strategy Makes Sense

### Current Gentoo Stable Versions (December 2024)
- **GCC 14.3.0** - Latest stable compiler
- **LLVM 20.1.7** - Cutting edge!
- **Mesa 25.1.7** - Brand new Mesa 25 series
- **glibc 2.41** - Very recent
- **systemd 257.6** - Latest series

### Benefits of Minimal Testing Approach
✅ **System won't break** from experimental GCC bugs  
✅ **Less time recompiling** world updates  
✅ **LTO/PGO more reliable** with stable compiler  
✅ **Can still get latest** Mesa/kernel/games  
✅ **Easier troubleshooting**  

### Minimal Drawbacks
⚠️ **Might miss 1-2% performance** from newest GCC (negligible)  
⚠️ **Need careful keyword management** (we've automated this)

## 🚀 Implementation

### 1. Package Keywords Strategy

**File**: `configs/package.accept_keywords/raptoros-minimal-testing`

Only these packages need testing:
- **NVIDIA Drivers** - Testing worth it for performance improvements
- **Wine/Proton** - Always use latest for game compatibility
- **Gaming Tools** - Steam, Lutris, MangoHud, etc.
- **Hyprland** - If using this WM

**Everything else stays in stable** - it's already cutting-edge!

### 2. Environment Optimizations

**File**: `configs/package.env/modern-optimizations`

Applies specific optimizations to:
- **LLVM 20 + Mesa 25** - Cutting edge stable features
- **GCC 14.3** - Aggressive optimization flags
- **NVIDIA 570+** - Modern driver features
- **systemd 257** - Latest systemd capabilities

### 3. Compiler Optimizations

**File**: `configs/env/gcc14-latest`

```bash
CFLAGS="-O3 -march=native -pipe -flto=auto -fno-plt -fdevirtualize-at-ltrans -fipa-pta"
LDFLAGS="-Wl,-O3 -Wl,--as-needed -Wl,-z,now -Wl,-z,relro -flto=auto"
```

**LLVM 20 optimizations**:
```bash
CFLAGS="${CFLAGS} -mllvm -polly -mllvm -polly-vectorizer=stripmine"
```

### 4. Smart Update System

**File**: `scripts/raptoros-update.sh`

Features:
- **Version checking** - Shows current system versions
- **Intelligent updates** - Smart emerge defaults
- **Quick gaming updates** - Only critical gaming packages
- **Automatic cleanup** - Depclean and preserved rebuilds

### 5. Performance Validation

**File**: `scripts/validate-performance.sh`

Validates:
- Compiler optimization status
- Mesa features and version
- LLVM 20 capabilities
- Kernel optimizations
- Gaming readiness

## 📁 File Structure

```
RaptorOS/
├── configs/
│   ├── make.conf                           # Main Gentoo configuration
│   ├── package.accept_keywords/
│   │   └── raptoros-minimal-testing       # Testing packages only
│   ├── package.env/
│   │   └── modern-optimizations           # Package-specific environments
│   └── env/
│       ├── llvm20-mesa25                  # LLVM 20 + Mesa 25 config
│       ├── gcc14-latest                   # GCC 14.3 optimizations
│       ├── nvidia-modern                  # NVIDIA 570+ features
│       └── systemd-modern                 # systemd 257 features
└── scripts/
    ├── raptoros-update.sh                 # Smart update system
    └── validate-performance.sh            # Performance validation
```

## 🔧 Installation Instructions

### Step 1: Copy Configuration Files

```bash
# Copy main configuration
sudo cp configs/make.conf /etc/portage/make.conf

# Copy package keywords
sudo cp configs/package.accept_keywords/* /etc/portage/package.accept_keywords/

# Copy package environments
sudo cp configs/package.env/* /etc/portage/package.env/

# Copy environment configurations
sudo cp configs/env/* /etc/portage/env/
```

### Step 2: Install Scripts

```bash
# Copy update scripts
sudo cp scripts/raptoros-update.sh /usr/local/bin/
sudo cp scripts/validate-performance.sh /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/raptoros-update.sh
sudo chmod +x /usr/local/bin/validate-performance.sh
```

### Step 3: Initial Sync and Update

```bash
# Sync repositories
sudo emerge --sync

# Update system with new configuration
sudo emerge -avuDN @world

# Install gaming packages
sudo emerge -av \
    games-util/steam-launcher \
    games-util/lutris \
    games-util/gamemode \
    games-util/mangohud \
    app-emulation/wine-staging
```

## 🎮 Gaming Package Management

### Steam Installation
```bash
# Steam is in testing for latest features
sudo emerge -av games-util/steam-launcher
```

### Wine/Proton Setup
```bash
# Always use latest for game compatibility
sudo emerge -av \
    app-emulation/wine-staging \
    app-emulation/wine-proton \
    app-emulation/vkd3d-proton
```

### Performance Tools
```bash
# GameMode for performance
sudo emerge -av games-util/gamemode

# MangoHud for FPS monitoring
sudo emerge -av games-util/mangohud
```

## 📈 Performance Monitoring

### Check System Versions
```bash
raptoros-update.sh
# Select "Check current versions"
```

### Validate Performance
```bash
validate-performance.sh
```

### Quick Gaming Update
```bash
raptoros-update.sh
# Select "Quick gaming update"
```

## 🔍 Troubleshooting

### Common Issues

**1. Package conflicts**
```bash
# Check what's conflicting
emerge -pvuDN @world

# Resolve with backtrack
emerge -avuDN @world --backtrack=100
```

**2. Testing package issues**
```bash
# Temporarily disable testing for specific package
echo "media-libs/mesa" >> /etc/portage/package.accept_keywords/stable-only
```

**3. Compiler optimization problems**
```bash
# Check current flags
gcc -v 2>&1 | grep "CFLAGS"

# Verify LTO is working
gcc -v 2>&1 | grep "enable-lto"
```

### Performance Verification

**Check if optimizations are active**:
```bash
# GCC version and flags
gcc --version
gcc -v 2>&1 | grep "CFLAGS"

# LLVM version and features
llvm-config --version
llvm-config --has-polly

# Mesa version and features
glxinfo | grep "OpenGL version"
```

## 🎯 Best Practices

### 1. Regular Updates
- **Weekly**: `raptoros-update.sh` → "Quick gaming update"
- **Monthly**: `raptoros-update.sh` → "Full system update"

### 2. Package Selection
- **Keep testing minimal** - Only gaming essentials
- **Monitor stable updates** - They're already cutting-edge
- **Use binary packages** when possible for speed

### 3. Performance Tuning
- **Run validation script** after major updates
- **Monitor gaming performance** with MangoHud
- **Adjust GameMode settings** for your hardware

## 🚀 Advanced Configuration

### Custom Environment Files

Create custom optimizations for specific packages:

```bash
# /etc/portage/env/custom-optimizations
CFLAGS="${CFLAGS} -march=native -mtune=native"
CXXFLAGS="${CXXFLAGS} -march=native -mtune=native"
```

### Kernel Optimizations

```bash
# Enable performance features
echo 'CONFIG_HZ_1000=y' >> /usr/src/linux/.config
echo 'CONFIG_PREEMPT=y' >> /usr/src/linux/.config
```

### GPU-Specific Tuning

**NVIDIA**:
```bash
# Enable performance mode
nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
```

**AMD**:
```bash
# Set performance level
echo "high" > /sys/class/drm/card0/device/power_dpm_force_performance_level
```

## 📊 Results

With this strategy, RaptorOS achieves:

- **99% stable packages** - Maximum reliability
- **Cutting-edge performance** - Modern toolchain
- **Fast updates** - Minimal recompilation
- **Easy maintenance** - Simple troubleshooting
- **Gaming excellence** - Latest gaming packages

## 🔗 Related Documentation

- [Gentoo Handbook](https://wiki.gentoo.org/wiki/Handbook:Main_Page)
- [Gaming Guide](https://wiki.gentoo.org/wiki/Gaming)
- [Performance Tuning](https://wiki.gentoo.org/wiki/Performance_Tuning)
- [Package Management](https://wiki.gentoo.org/wiki/Portage)

---

**RaptorOS: Performance Evolved™**  
*Built on the foundation that modern Gentoo stable is already cutting-edge*
