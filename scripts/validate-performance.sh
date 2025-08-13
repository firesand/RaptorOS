#!/bin/bash
# Validate that modern stable versions are performing well

echo "RaptorOS Performance Validation"
echo "═══════════════════════════════"
echo ""

# Check compiler optimization
echo "Compiler Optimization Test:"
echo -n "GCC 14.3.0 LTO: "
if gcc -v 2>&1 | grep -q "enable-lto"; then
    echo "✓ Enabled"
else
    echo "✗ Disabled"
fi

# Check Mesa features
echo ""
echo "Mesa 25.1.7 Features:"
glxinfo 2>/dev/null | grep -E "OpenGL version|Mesa" | head -2

# Check LLVM
echo ""
echo "LLVM 20.1.7 Status:"
if llvm-config --version | grep -q "20"; then
    echo "✓ Modern LLVM 20 active"
    echo "  Polly: $(llvm-config --has-polly && echo ✓ || echo ✗)"
fi

# Check kernel config
echo ""
echo "Kernel Optimizations:"
if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_HZ_1000=y"; then
    echo "✓ 1000Hz timer"
fi
if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_PREEMPT=y"; then
    echo "✓ Full preemption"
fi

# Gaming readiness
echo ""
echo "Gaming Readiness:"
command -v steam &>/dev/null && echo "✓ Steam installed" || echo "✗ Steam not found"
command -v mangohud &>/dev/null && echo "✓ MangoHud ready" || echo "✗ MangoHud missing"
command -v gamemoded &>/dev/null && echo "✓ GameMode available" || echo "✗ GameMode missing"

echo ""
echo "═══════════════════════════════"
echo "Verdict: $(
    if command -v steam &>/dev/null && [ -f /usr/lib64/libvulkan.so ]; then
        echo "✓ READY FOR GAMING"
    else
        echo "⚠ Missing some components"
    fi
)"
