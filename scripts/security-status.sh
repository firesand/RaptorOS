#!/bin/bash
# RaptorOS Security Status Checker
# Comprehensive security audit and status reporting

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Check Secure Boot status
check_secure_boot() {
    echo -e "${CYAN}=== Secure Boot Status ===${NC}"
    
    if [ -d /sys/firmware/efi ]; then
        if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
            local sb_value=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | tr -d ' ')
            if [ "$sb_value" = "1" ]; then
                echo -e "  ${GREEN}✓ Secure Boot is ENABLED${NC}"
                SB_ENABLED=true
            else
                echo -e "  ${YELLOW}⚠ Secure Boot is DISABLED${NC}"
                SB_ENABLED=false
            fi
        else
            echo -e "  ${YELLOW}⚠ Secure Boot not configured${NC}"
            SB_ENABLED=false
        fi
    else
        echo -e "  ${RED}✗ UEFI not detected${NC}"
        SB_ENABLED=false
    fi
    
    # Check MOK enrollment
    if command -v mokutil &>/dev/null; then
        echo ""
        echo "MOK Enrollment Status:"
        if mokutil --list-enrolled | grep -q "RaptorOS"; then
            echo -e "  ${GREEN}✓ RaptorOS MOK is enrolled${NC}"
        else
            echo -e "  ${YELLOW}⚠ RaptorOS MOK not enrolled${NC}"
            echo "    Run 'enroll-mok' to enroll"
        fi
    fi
}

# Check kernel signature
check_kernel_signature() {
    echo -e "\n${CYAN}=== Kernel Security ===${NC}"
    
    KERNEL_VERSION=$(uname -r)
    echo "Kernel Version: $KERNEL_VERSION"
    
    if [ -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
        if command -v sbverify &>/dev/null && [ -f "/etc/pki/MOK/MOK.crt" ]; then
            if sbverify --cert /etc/pki/MOK/MOK.crt "/boot/vmlinuz-$KERNEL_VERSION" &>/dev/null; then
                echo -e "  ${GREEN}✓ Kernel is properly signed${NC}"
            else
                echo -e "  ${RED}✗ Kernel is NOT signed${NC}"
                echo "    Run 'sign-kernel' to sign"
            fi
        else
            echo -e "  ${YELLOW}⚠ Kernel signature verification tools not available${NC}"
        fi
    fi
    
    # Check module signature enforcement
    if [ -f /proc/cmdline ] && grep -q "module.sig_enforce=1" /proc/cmdline; then
        echo -e "  ${GREEN}✓ Module signature enforcement enabled${NC}"
    else
        echo -e "  ${YELLOW}⚠ Module signature enforcement not enabled${NC}"
    fi
}

# Check firewall status
check_firewall() {
    echo -e "\n${CYAN}=== Firewall Status ===${NC}"
    
    if command -v iptables &>/dev/null; then
        echo "Firewall Rules:"
        local rules_count=$(iptables -L INPUT -n | wc -l)
        if [ $rules_count -gt 3 ]; then
            echo -e "  ${GREEN}✓ Firewall rules active ($((rules_count-3)) rules)${NC}"
            
            # Check if gaming firewall is loaded
            if iptables -L GAMING_TCP -n &>/dev/null; then
                echo -e "  ${GREEN}✓ Gaming firewall chains active${NC}"
            fi
        else
            echo -e "  ${RED}✗ No firewall rules active${NC}"
        fi
        
        # Check firewall service status
        if systemctl is-active --quiet gaming-firewall 2>/dev/null; then
            echo -e "  ${GREEN}✓ Gaming firewall service running${NC}"
        elif rc-service gaming-firewall status &>/dev/null; then
            echo -e "  ${GREEN}✓ Gaming firewall service running (OpenRC)${NC}"
        else
            echo -e "  ${YELLOW}⚠ Gaming firewall service not running${NC}"
        fi
    else
        echo -e "  ${RED}✗ iptables not installed${NC}"
    fi
}

# Check network security
check_network_security() {
    echo -e "\n${CYAN}=== Network Security ===${NC}"
    
    # Check listening ports
    echo "Listening Ports:"
    local open_ports=$(ss -tln | grep -v "127.0.0.1" | wc -l)
    if [ $open_ports -le 5 ]; then
        echo -e "  ${GREEN}✓ Minimal open ports ($open_ports)${NC}"
    else
        echo -e "  ${YELLOW}⚠ Multiple open ports ($open_ports)${NC}"
    fi
    
    # Check for common vulnerable services
    local vulnerable_services=()
    ss -tln | grep -E ":(22|21|23|25|53|80|443|3306|5432|6379|27017)" | while read line; do
        local port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
        case $port in
            22) echo -e "  ${YELLOW}⚠ SSH on port 22 (ensure key-based auth)${NC}" ;;
            21) vulnerable_services+=("FTP") ;;
            23) vulnerable_services+=("Telnet") ;;
            25) vulnerable_services+=("SMTP") ;;
            53) echo -e "  ${YELLOW}⚠ DNS on port 53 (ensure local only)${NC}" ;;
            80|443) echo -e "  ${YELLOW}⚠ HTTP/HTTPS on port $port (ensure local only)${NC}" ;;
            3306) vulnerable_services+=("MySQL") ;;
            5432) vulnerable_services+=("PostgreSQL") ;;
            6379) vulnerable_services+=("Redis") ;;
            27017) vulnerable_services+=("MongoDB") ;;
        esac
    done
    
    if [ ${#vulnerable_services[@]} -gt 0 ]; then
        echo -e "  ${RED}✗ Potentially vulnerable services detected:${NC}"
        for service in "${vulnerable_services[@]}"; do
            echo -e "    - $service"
        done
    fi
}

# Check system hardening
check_system_hardening() {
    echo -e "\n${CYAN}=== System Hardening ===${NC}"
    
    # Check core dumps
    if [ "$(ulimit -c)" = "0" ]; then
        echo -e "  ${GREEN}✓ Core dumps disabled${NC}"
    else
        echo -e "  ${YELLOW}⚠ Core dumps enabled (ulimit -c: $(ulimit -c))${NC}"
    fi
    
    # Check ASLR
    if [ -f /proc/sys/kernel/randomize_va_space ]; then
        local aslr=$(cat /proc/sys/kernel/randomize_va_space)
        case $aslr in
            0) echo -e "  ${RED}✗ ASLR disabled${NC}" ;;
            1) echo -e "  ${YELLOW}⚠ ASLR partially enabled${NC}" ;;
            2) echo -e "  ${GREEN}✓ ASLR fully enabled${NC}" ;;
        esac
    fi
    
    # Check kernel parameters
    echo "Kernel Security Parameters:"
    if [ "$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null)" = "1" ]; then
        echo -e "  ${GREEN}✓ dmesg restricted${NC}"
    else
        echo -e "  ${YELLOW}⚠ dmesg not restricted${NC}"
    fi
    
    if [ "$(cat /proc/sys/kernel/unprivileged_bpf_disabled 2>/dev/null)" = "1" ]; then
        echo -e "  ${GREEN}✓ Unprivileged BPF disabled${NC}"
    else
        echo -e "  ${YELLOW}⚠ Unprivileged BPF enabled${NC}"
    fi
}

# Check package security
check_package_security() {
    echo -e "\n${CYAN}=== Package Security ===${NC}"
    
    # Check for security updates
    if command -v emerge &>/dev/null; then
        echo "Checking for security updates..."
        local security_updates=$(emerge --pretend --update --deep --newuse @world 2>&1 | grep -c "security" || echo "0")
        if [ $security_updates -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ $security_updates security updates available${NC}"
            echo "    Run: emerge --update --deep --newuse @world"
        else
            echo -e "  ${GREEN}✓ No security updates available${NC}"
        fi
    fi
    
    # Check for known vulnerable packages
    echo "Checking for known vulnerabilities..."
    if command -v glsa-check &>/dev/null; then
        local vulns=$(glsa-check -t all 2>/dev/null | grep -c "affected" || echo "0")
        if [ $vulns -gt 0 ]; then
            echo -e "  ${RED}✗ $vulns packages with known vulnerabilities${NC}"
            echo "    Run: glsa-check -t all"
        else
            echo -e "  ${GREEN}✓ No known vulnerabilities detected${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ glsa-check not available${NC}"
    fi
}

# Check user security
check_user_security() {
    echo -e "\n${CYAN}=== User Security ===${NC}"
    
    # Check password policies
    echo "Password Policies:"
    if [ -f /etc/login.defs ]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
        if [ "$pass_max_days" -gt 90 ]; then
            echo -e "  ${YELLOW}⚠ Password max age: $pass_max_days days (recommend ≤90)${NC}"
        else
            echo -e "  ${GREEN}✓ Password max age: $pass_max_days days${NC}"
        fi
    fi
    
    # Check for users with UID 0 (other than root)
    local uid0_users=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd)
    if [ -n "$uid0_users" ]; then
        echo -e "  ${RED}✗ Users with UID 0: $uid0_users${NC}"
    else
        echo -e "  ${GREEN}✓ No unauthorized UID 0 users${NC}"
    fi
    
    # Check for empty passwords
    local empty_passwords=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$empty_passwords" ]; then
        echo -e "  ${RED}✗ Users with empty passwords: $empty_passwords${NC}"
    else
        echo -e "  ${GREEN}✓ No empty passwords detected${NC}"
    fi
}

# Generate security report
generate_report() {
    local report_file="/var/log/raptoros-security-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "RaptorOS Security Status Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "=================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Redirect all output to both console and file
    exec > >(tee -a "$report_file")
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║              RaptorOS Security Status                    ║${NC}"
    echo -e "${PURPLE}║                 Comprehensive Audit                     ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_secure_boot
    check_kernel_signature
    check_firewall
    check_network_security
    check_system_hardening
    check_package_security
    check_user_security
    
    # Security score calculation
    echo -e "\n${CYAN}=== Security Score ===${NC}"
    local score=0
    local max_score=100
    
    # Calculate score based on checks
    [ "$SB_ENABLED" = true ] && score=$((score + 20))
    [ -f "/etc/pki/MOK/MOK.crt" ] && score=$((score + 15))
    command -v iptables &>/dev/null && score=$((score + 15))
    [ "$(ulimit -c)" = "0" ] && score=$((score + 10))
    [ "$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)" = "2" ] && score=$((score + 10))
    
    echo "Overall Security Score: $score/$max_score"
    
    if [ $score -ge 80 ]; then
        echo -e "  ${GREEN}🛡️  EXCELLENT - System is well secured${NC}"
    elif [ $score -ge 60 ]; then
        echo -e "  ${YELLOW}⚠ GOOD - Some improvements recommended${NC}"
    elif [ $score -ge 40 ]; then
        echo -e "  ${YELLOW}⚠ FAIR - Security improvements needed${NC}"
    else
        echo -e "  ${RED}🚨 POOR - Immediate security attention required${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Report saved to: $report_file${NC}"
    echo ""
    echo -e "${BLUE}Recommendations:${NC}"
    echo "• Run 'enroll-mok' if Secure Boot is not configured"
    echo "• Run 'sign-kernel' if kernel is not signed"
    echo "• Run 'gaming-firewall start' if firewall is not active"
    echo "• Review open ports and disable unnecessary services"
    echo "• Keep system updated with 'emerge --sync && emerge -avuDN @world'"
}

# Main function
main() {
    check_root
    generate_report
}

# Run if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
