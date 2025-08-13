#!/bin/bash
# RaptorOS System Validator
# Validates installation integrity and system health

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/raptoros/system-validator.log"
ERROR_LOG="/var/log/raptoros/validation-errors.log"

# Ensure log directory exists
mkdir -p /var/log/raptoros

# Logging function
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error_log() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$ERROR_LOG"
}

# Validate critical files
validate_critical_files() {
    log "Validating critical system files..."
    
    local required_files=(
        "/etc/portage/make.conf"
        "/boot/grub/grub.cfg"
        "/etc/fstab"
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
    )
    
    local missing_files=0
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error_log "Missing critical file: $file"
            missing_files=$((missing_files + 1))
        else
            log "✓ Found: $file"
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        error_log "Critical files validation failed: $missing_files missing"
        return 1
    fi
    
    log "✓ Critical files validation passed"
    return 0
}

# Validate services
validate_services() {
    log "Validating critical services..."
    
    local services=("NetworkManager" "bluetooth" "sshd" "systemd-resolved")
    local failed_services=0
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            if systemctl is-active "$service" &>/dev/null; then
                log "✓ Service active: $service"
            else
                error_log "Service enabled but not active: $service"
                failed_services=$((failed_services + 1))
            fi
        else
            log "⚠ Service not enabled: $service (optional)"
        fi
    done
    
    if [ $failed_services -gt 0 ]; then
        error_log "Service validation failed: $failed_services services not running"
        return 1
    fi
    
    log "✓ Service validation passed"
    return 0
}

# Validate RaptorOS specific configurations
validate_raptoros_config() {
    log "Validating RaptorOS configurations..."
    
    local configs=(
        "/etc/portage/env/gcc14-latest"
        "/etc/portage/env/llvm20-mesa25"
        "/etc/portage/package.accept_keywords/raptoros-minimal-testing"
        "/etc/portage/package.env/modern-optimizations"
    )
    
    local missing_configs=0
    
    for config in "${configs[@]}"; do
        if [ ! -f "$config" ]; then
            error_log "Missing RaptorOS config: $config"
            missing_configs=$((missing_configs + 1))
        else
            log "✓ Found: $config"
        fi
    done
    
    if [ $missing_configs -gt 0 ]; then
        error_log "RaptorOS config validation failed: $missing_configs missing"
        return 1
    fi
    
    log "✓ RaptorOS config validation passed"
    return 0
}

# Validate hardware detection
validate_hardware() {
    log "Validating hardware detection..."
    
    # Check CPU
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        log "✓ CPU detected: $cpu_model"
    else
        error_log "CPU information not available"
        return 1
    fi
    
    # Check memory
    if [ -f /proc/meminfo ]; then
        local total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print int($2/1024/1024)}')
        log "✓ Total memory: ${total_mem}GB"
    else
        error_log "Memory information not available"
        return 1
    fi
    
    # Check GPU
    if command -v lspci &>/dev/null; then
        local gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1)
        if [ ! -z "$gpu_info" ]; then
            log "✓ GPU detected: $gpu_info"
        else
            log "⚠ No GPU detected"
        fi
    else
        log "⚠ lspci not available for GPU detection"
    fi
    
    log "✓ Hardware validation passed"
    return 0
}

# Validate network configuration
validate_network() {
    log "Validating network configuration..."
    
    # Check network interfaces
    if [ -d /sys/class/net ]; then
        local interfaces=$(ls /sys/class/net | grep -v lo)
        if [ ! -z "$interfaces" ]; then
            log "✓ Network interfaces found: $interfaces"
        else
            error_log "No network interfaces found"
            return 1
        fi
    fi
    
    # Check DNS resolution
    if command -v nslookup &>/dev/null; then
        if nslookup google.com &>/dev/null; then
            log "✓ DNS resolution working"
        else
            error_log "DNS resolution failed"
            return 1
        fi
    fi
    
    # Check internet connectivity
    if command -v ping &>/dev/null; then
        if ping -c 1 8.8.8.8 &>/dev/null; then
            log "✓ Internet connectivity working"
        else
            error_log "Internet connectivity failed"
            return 1
        fi
    fi
    
    log "✓ Network validation passed"
    return 0
}

# Validate gaming components
validate_gaming() {
    log "Validating gaming components..."
    
    local gaming_tools=(
        "steam"
        "wine"
        "gamemoded"
        "mangohud"
    )
    
    local missing_tools=0
    
    for tool in "${gaming_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log "✓ Gaming tool found: $tool"
        else
            log "⚠ Gaming tool not found: $tool (optional)"
            missing_tools=$((missing_tools + 1))
        fi
    done
    
    # Check Vulkan support
    if [ -f /usr/lib64/libvulkan.so ] || [ -f /usr/lib/libvulkan.so ]; then
        log "✓ Vulkan support available"
    else
        log "⚠ Vulkan support not available"
    fi
    
    # Check OpenGL support
    if command -v glxinfo &>/dev/null; then
        if glxinfo | grep -q "OpenGL version"; then
            log "✓ OpenGL support available"
        else
            log "⚠ OpenGL support not available"
        fi
    fi
    
    log "✓ Gaming validation completed"
    return 0
}

# Validate system performance
validate_performance() {
    log "Validating system performance..."
    
    # Check CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        log "✓ CPU governor: $governor"
        
        if [ "$governor" = "performance" ]; then
            log "✓ CPU set to performance mode"
        else
            log "⚠ CPU not in performance mode (current: $governor)"
        fi
    fi
    
    # Check I/O scheduler
    if [ -d /sys/block ]; then
        for disk in /sys/block/sd* /sys/block/nvme*; do
            if [ -d "$disk" ]; then
                local scheduler=$(cat "$disk/queue/scheduler" 2>/dev/null | grep -o '\[[^]]*\]' | tr -d '[]')
                log "✓ I/O scheduler for $(basename "$disk"): $scheduler"
            fi
        done
    fi
    
    # Check ZRAM
    if swapon --show | grep -q zram; then
        log "✓ ZRAM swap active"
    else
        log "⚠ ZRAM swap not active"
    fi
    
    log "✓ Performance validation completed"
    return 0
}

# Generate validation report
generate_report() {
    local report_file="/var/log/raptoros/validation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log "Generating validation report: $report_file"
    
    {
        echo "RaptorOS System Validation Report"
        echo "Generated: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "System Information:"
        echo "  Hostname: $(hostname)"
        echo "  Kernel: $(uname -r)"
        echo "  Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "Unknown")"
        echo "  Uptime: $(uptime)"
        echo ""
        echo "Validation Results:"
        echo "  Critical Files: $([ $1 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  Services: $([ $2 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  RaptorOS Config: $([ $3 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  Hardware: $([ $4 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  Network: $([ $5 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  Gaming: $([ $6 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo "  Performance: $([ $7 -eq 0 ] && echo "PASSED" || echo "FAILED")"
        echo ""
        echo "Overall Status: $([ $(( $1 + $2 + $3 + $4 + $5 + $6 + $7 )) -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED")"
    } > "$report_file"
    
    log "Report saved to: $report_file"
}

# Main validation function
main() {
    log "Starting RaptorOS System Validation..."
    echo ""
    
    # Run all validations
    validate_critical_files
    local critical_files_result=$?
    
    validate_services
    local services_result=$?
    
    validate_raptoros_config
    local raptoros_config_result=$?
    
    validate_hardware
    local hardware_result=$?
    
    validate_network
    local network_result=$?
    
    validate_gaming
    local gaming_result=$?
    
    validate_performance
    local performance_result=$?
    
    # Generate report
    generate_report $critical_files_result $services_result $raptoros_config_result $hardware_result $network_result $gaming_result $performance_result
    
    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Validation Summary:"
    echo "  Critical Files: $([ $critical_files_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Services: $([ $services_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  RaptorOS Config: $([ $raptoros_config_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Hardware: $([ $hardware_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Network: $([ $network_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Gaming: $([ $gaming_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Performance: $([ $performance_result -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo ""
    
    local total_failures=$(( critical_files_result + services_result + raptoros_config_result + hardware_result + network_result + gaming_result + performance_result ))
    
    if [ $total_failures -eq 0 ]; then
        echo -e "${GREEN}🎉 All validations passed! Your RaptorOS system is healthy.${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  $total_failures validation(s) failed. Check the error log for details.${NC}"
        echo "Error log: $ERROR_LOG"
        exit 1
    fi
}

# Run main function
main "$@"
