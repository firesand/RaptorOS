#!/bin/bash
# Network Configuration Module for RaptorOS Installer
# Handles network setup, WiFi, gaming optimizations

# Network configuration main
configure_network() {
    local net_choice=$(dialog --backtitle "RaptorOS Installer" \
                              --title "Network Configuration" \
                              --menu "\nSelect network configuration:" \
                              15 70 5 \
                              "auto" "Automatic (DHCP) - Recommended" \
                              "static" "Static IP configuration" \
                              "wifi" "WiFi setup" \
                              "gaming" "Gaming optimized network" \
                              "skip" "Skip network configuration" \
                              3>&1 1>&2 2>&3)

    case "$net_choice" in
        "auto")
            configure_dhcp
            ;;
        "static")
            configure_static_ip
            ;;
        "wifi")
            configure_wifi
            ;;
        "gaming")
            configure_gaming_network
            ;;
        "skip")
            log "Network configuration skipped"
            ;;
    esac
}

# Configure DHCP
configure_dhcp() {
    log "Configuring DHCP networking"

    # NetworkManager config for DHCP
    cat > /mnt/gentoo/etc/NetworkManager/conf.d/dhcp.conf << 'EOF'
[main]
dhcp=internal
dns=systemd-resolved

[connection]
connection.autoconnect-retries=3
connection.autoconnect-priority=999

[ipv4]
method=auto
dns-search=

[ipv6]
method=auto
ip6-privacy=2
EOF

    dialog --infobox "DHCP networking configured" 3 40
    sleep 2
}

# Configure static IP
configure_static_ip() {
    local ip_address=$(dialog --backtitle "RaptorOS Installer" \
                              --title "Static IP Configuration" \
                              --inputbox "\nEnter IP address (e.g., 192.168.1.100):" \
                              10 50 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    local netmask=$(dialog --backtitle "RaptorOS Installer" \
                           --title "Static IP Configuration" \
                           --inputbox "\nEnter netmask (e.g., 255.255.255.0):" \
                           10 50 "255.255.255.0" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    local gateway=$(dialog --backtitle "RaptorOS Installer" \
                          --title "Static IP Configuration" \
                          --inputbox "\nEnter gateway (e.g., 192.168.1.1):" \
                          10 50 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    local dns1=$(dialog --backtitle "RaptorOS Installer" \
                       --title "Static IP Configuration" \
                       --inputbox "\nEnter primary DNS (e.g., 1.1.1.1):" \
                       10 50 "1.1.1.1" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    local dns2=$(dialog --backtitle "RaptorOS Installer" \
                       --title "Static IP Configuration" \
                       --inputbox "\nEnter secondary DNS (e.g., 1.0.0.1):" \
                       10 50 "1.0.0.1" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    # Write static configuration
    cat > /mnt/gentoo/etc/NetworkManager/system-connections/static.nmconnection << EOF
[connection]
id=Static-Connection
type=ethernet
autoconnect=true
autoconnect-priority=999

[ipv4]
method=manual
address1=$ip_address/24,$gateway
dns=$dns1;$dns2;

[ipv6]
method=auto
ip6-privacy=2
EOF

    chmod 600 /mnt/gentoo/etc/NetworkManager/system-connections/static.nmconnection

    log "Static IP configured: $ip_address"
}

# Configure WiFi
configure_wifi() {
    log "Configuring WiFi"

    # Check for wireless interfaces
    local wifi_interfaces=($(iw dev | awk '$1=="Interface"{print $2}'))

    if [ ${#wifi_interfaces[@]} -eq 0 ]; then
        dialog --msgbox "No WiFi interfaces detected!" 8 40
        return
    fi

    # Select interface
    local interface_list=()
    for iface in "${wifi_interfaces[@]}"; do
        interface_list+=("$iface" "Wireless interface")
    done

    local wifi_interface=$(dialog --backtitle "RaptorOS Installer" \
                                  --title "WiFi Interface" \
                                  --menu "\nSelect WiFi interface:" \
                                  12 50 4 \
                                  "${interface_list[@]}" \
                                  3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    # Scan for networks
    dialog --infobox "Scanning for WiFi networks..." 3 40
    local networks=$(iwlist "$wifi_interface" scan 2>/dev/null | \
                    grep -E "ESSID:|Quality" | \
                    paste -d' ' - - | \
                    sed 's/.*Quality=\([0-9]*\).*ESSID:"\(.*\)"/\2 \1/')

    if [ -z "$networks" ]; then
        dialog --msgbox "No WiFi networks found!" 8 40
        return
    fi

    # Select network
    local network_list=()
    while IFS= read -r line; do
        local ssid=$(echo "$line" | cut -d' ' -f1)
        local quality=$(echo "$line" | cut -d' ' -f2)
        network_list+=("$ssid" "Signal: $quality/70")
    done <<< "$networks"

    local selected_ssid=$(dialog --backtitle "RaptorOS Installer" \
                                 --title "WiFi Networks" \
                                 --menu "\nSelect WiFi network:" \
                                 20 60 10 \
                                 "${network_list[@]}" \
                                 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    # Get password
    local wifi_password=$(dialog --backtitle "RaptorOS Installer" \
                                 --title "WiFi Password" \
                                 --passwordbox "\nEnter password for $selected_ssid:" \
                                 10 50 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return

    # Save WiFi configuration
    cat > /mnt/gentoo/etc/NetworkManager/system-connections/wifi-$selected_ssid.nmconnection << EOF
[connection]
id=$selected_ssid
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$selected_ssid

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$wifi_password

[ipv4]
method=auto

[ipv6]
method=auto
ip6-privacy=2
EOF

    chmod 600 /mnt/gentoo/etc/NetworkManager/system-connections/wifi-$selected_ssid.nmconnection

    log "WiFi configured for: $selected_ssid"
}

# Gaming optimized network configuration
configure_gaming_network() {
    dialog --backtitle "RaptorOS Installer" \
           --title "Gaming Network Optimization" \
           --yesno "\nApply gaming network optimizations?\n\n\
- Cloudflare DNS (1.1.1.1)\n\
- TCP optimizations for low latency\n\
- Buffer size tuning\n\
- Congestion control (BBR)\n\
- QoS/Traffic shaping ready\n\n\
This will optimize network for gaming performance." 16 60

    if [ $? -ne 0 ]; then
        return
    fi

    log "Applying gaming network optimizations"

    # Backup existing configuration
    if [ -f /mnt/gentoo/etc/resolv.conf ]; then
        cp /mnt/gentoo/etc/resolv.conf /mnt/gentoo/etc/resolv.conf.backup
        log "Backed up existing resolv.conf"
    fi
    
    if [ -f /mnt/gentoo/etc/NetworkManager/NetworkManager.conf ]; then
        cp /mnt/gentoo/etc/NetworkManager/NetworkManager.conf /mnt/gentoo/etc/NetworkManager/NetworkManager.conf.backup
        log "Backed up existing NetworkManager.conf"
    fi

    # DNS configuration for gaming (Cloudflare)
    cat > /mnt/gentoo/etc/resolv.conf.head << 'EOF'
# RaptorOS Gaming DNS Configuration
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 2606:4700:4700::1111
nameserver 2606:4700:4700::1001
options edns0 trust-ad
EOF

    # NetworkManager DNS config
    cat > /mnt/gentoo/etc/NetworkManager/conf.d/dns.conf << 'EOF'
[main]
dns=systemd-resolved
systemd-resolved=false

[global-dns]
searches=
options=edns0,trust-ad

[global-dns-domain-*]
servers=1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001
EOF

    # Network optimization sysctl
    cat > /mnt/gentoo/etc/sysctl.d/60-gaming-network.conf << 'EOF'
# RaptorOS Gaming Network Optimizations
# Low latency, high throughput configuration

# Core network settings
net.core.netdev_max_backlog = 16384
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 5000
net.core.somaxconn = 65535
net.core.rmem_default = 1048576
net.core.rmem_max = 134217728
net.core.wmem_default = 1048576
net.core.wmem_max = 134217728
net.core.optmem_max = 65536
net.core.default_qdisc = fq

# TCP optimizations for gaming
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fastopen_blackhole_timeout_sec = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 1048576 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_collapse_max_bytes = 6291456
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_fin_timeout = 30

# UDP optimizations for game traffic
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# IPv4 settings
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.tcp_synack_retries = 2

# IPv6 settings
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.default.accept_ra = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Netfilter
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
net.netfilter.nf_conntrack_generic_timeout = 60
net.netfilter.nf_conntrack_helper = 0

# Enable BBR TCP congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

    # Install network tools
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
net-analyzer/netcat
net-analyzer/tcpdump
net-analyzer/iftop
net-analyzer/nethogs
net-misc/iperf
net-dns/bind-tools
EOF

    dialog --msgbox "Gaming network optimizations applied!\n\n\
- Cloudflare DNS configured\n\
- TCP BBR enabled\n\
- Low latency settings applied\n\
- Buffer sizes optimized" 12 50
}

# Configure hosts file
configure_hosts() {
    log "Configuring hosts file"

    cat > /mnt/gentoo/etc/hosts << EOF
# /etc/hosts: Local Host Database
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME

# Block Windows telemetry (optional - gaming PCs often dual boot)
0.0.0.0 telemetry.microsoft.com
0.0.0.0 telemetry.urs.microsoft.com
0.0.0.0 vortex.data.microsoft.com
0.0.0.0 vortex-win.data.microsoft.com
0.0.0.0 settings-win.data.microsoft.com

# Steam content servers (optional - can improve download speeds)
# Uncomment and set to your preferred CDN
# 162.254.192.71 valve500.steamcontent.com
# 162.254.192.72 valve501.steamcontent.com
EOF
}

# Enhanced gaming firewall configuration
configure_gaming_firewall() {
    log "Configuring gaming-optimized firewall"
    
    dialog --backtitle "RaptorOS Installer" \
           --title "Gaming Firewall Configuration" \
           --yesno "Configure gaming firewall?\n\n\
This will set up:\n\
• Strict default deny policy\n\
• Gaming platform ports (Steam, Epic, etc.)\n\
• Rate limiting for DDoS protection\n\
• Port forwarding helpers\n\
• Connection tracking optimization" 14 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Install firewall packages
    cat >> /mnt/gentoo/var/lib/portage/world << 'EOF'
net-firewall/iptables
net-firewall/nftables
net-firewall/ufw
net-firewall/firewalld
EOF
    
    # Create comprehensive gaming firewall rules
    cat > /mnt/gentoo/etc/iptables/gaming-firewall.rules << 'FIREWALL_RULES'
*filter
# RaptorOS Gaming Firewall Configuration
# Optimized for low latency and gaming security

# Default policies
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Custom chains for organization
:GAMING_TCP - [0:0]
:GAMING_UDP - [0:0]
:RATE_LIMIT - [0:0]
:DDOS_PROTECT - [0:0]

# Accept loopback
-A INPUT -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT

# Accept established connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DDoS Protection
-A INPUT -j DDOS_PROTECT
-A DDOS_PROTECT -p tcp --tcp-flags ALL NONE -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags ALL ALL -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags ACK,FIN FIN -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags ACK,PSH PSH -j DROP
-A DDOS_PROTECT -p tcp --tcp-flags ACK,URG URG -j DROP

# Rate limiting
-A INPUT -j RATE_LIMIT
-A RATE_LIMIT -p tcp --dport 22 -m recent --set --name SSH
-A RATE_LIMIT -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
-A RATE_LIMIT -p icmp --icmp-type echo-request -m limit --limit 5/second -j ACCEPT
-A RATE_LIMIT -p icmp -j DROP

# Gaming ports
-A INPUT -p tcp -j GAMING_TCP
-A INPUT -p udp -j GAMING_UDP

### TCP Gaming Ports ###

# Steam
-A GAMING_TCP -p tcp --dport 27015 -j ACCEPT
-A GAMING_TCP -p tcp --dport 27036 -j ACCEPT
-A GAMING_TCP -p tcp -m multiport --dports 27015:27030 -j ACCEPT

# Battle.net
-A GAMING_TCP -p tcp -m multiport --dports 1119,3724,6112:6114 -j ACCEPT

# Epic Games
-A GAMING_TCP -p tcp -m multiport --dports 433,443,5222 -j ACCEPT

# Origin/EA
-A GAMING_TCP -p tcp -m multiport --dports 1024:1124,3216,9960:9969,18000,18120,18060,27900,28910,29900 -j ACCEPT

# Ubisoft Connect
-A GAMING_TCP -p tcp -m multiport --dports 443,14000,14001,14008 -j ACCEPT

# Xbox Live
-A GAMING_TCP -p tcp --dport 3074 -j ACCEPT

# PlayStation
-A GAMING_TCP -p tcp -m multiport --dports 80,443,465,993,3478,3479,3480,5223,8080 -j ACCEPT

# Discord
-A GAMING_TCP -p tcp --dport 443 -j ACCEPT

# Minecraft
-A GAMING_TCP -p tcp --dport 25565 -j ACCEPT

# Teamspeak
-A GAMING_TCP -p tcp -m multiport --dports 10011,30033,41144 -j ACCEPT

### UDP Gaming Ports ###

# Steam
-A GAMING_UDP -p udp -m multiport --dports 3478,4379:4380,27000:27031,27036 -j ACCEPT

# CS2 / Source Engine
-A GAMING_UDP -p udp -m multiport --dports 27015:27030 -j ACCEPT

# Battle.net
-A GAMING_UDP -p udp -m multiport --dports 1119,3478,3479,5060,5062,6250,12000:64000 -j ACCEPT

# Epic Games/Fortnite
-A GAMING_UDP -p udp -m multiport --dports 5795:5847,9000:9100 -j ACCEPT

# Call of Duty
-A GAMING_UDP -p udp -m multiport --dports 3074,3075,3076,3077,3078 -j ACCEPT

# Apex Legends
-A GAMING_UDP -p udp -m multiport --dports 1024:1124,9960:9969,18000,18120,18060,27900,28910 -j ACCEPT

# Valorant
-A GAMING_UDP -p udp -m multiport --dports 7000:8000,8180:8181 -j ACCEPT

# Xbox Live
-A GAMING_UDP -p udp -m multiport --dports 88,500,3074,3544,4500 -j ACCEPT

# PlayStation
-A GAMING_UDP -p udp -m multiport --dports 3478,3479,3658 -j ACCEPT

# Discord Voice
-A GAMING_UDP -p udp -m multiport --dports 50000:65535 -j ACCEPT

# Minecraft
-A GAMING_UDP -p udp --dport 25565 -j ACCEPT
-A GAMING_UDP -p udp --dport 19132 -j ACCEPT  # Bedrock

# Teamspeak
-A GAMING_UDP -p udp --dport 9987 -j ACCEPT

# STUN/TURN for WebRTC (game streaming)
-A GAMING_UDP -p udp -m multiport --dports 3478,3479,5349,5350 -j ACCEPT

# Optional: SSH for remote management (rate limited)
-A INPUT -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
-A INPUT -p tcp --dport 22 -j ACCEPT

# Optional: HTTP/HTTPS for local game servers
# -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

# Log dropped packets (optional, can be noisy)
# -A INPUT -m limit --limit 5/min -j LOG --log-prefix "FW-DROP: " --log-level 7

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# NAT for game streaming (Sunshine/Moonlight)
# -A PREROUTING -p tcp --dport 47984:47989 -j DNAT --to-destination 192.168.1.100
# -A PREROUTING -p udp --dport 47998:48000 -j DNAT --to-destination 192.168.1.100

COMMIT

*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# QoS marking for gaming traffic (DSCP)
-A POSTROUTING -p udp --dport 27015:27030 -j DSCP --set-dscp-class EF
-A POSTROUTING -p tcp --dport 27015:27030 -j DSCP --set-dscp-class EF

COMMIT
FIREWALL_RULES
    
    # Create firewall management script
    cat > /mnt/gentoo/usr/local/bin/gaming-firewall << 'FW_SCRIPT'
#!/bin/bash
# RaptorOS Gaming Firewall Manager

case "$1" in
    start)
        echo "Starting RaptorOS Gaming Firewall..."
        iptables-restore < /etc/iptables/gaming-firewall.rules
        echo "Gaming firewall active"
        ;;
    stop)
        echo "Stopping firewall..."
        iptables -F
        iptables -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        echo "Firewall disabled"
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        echo "Current firewall rules:"
        iptables -L -n -v
        ;;
    open-port)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 open-port <port> <tcp|udp>"
            exit 1
        fi
        iptables -A GAMING_${3^^} -p $3 --dport $2 -j ACCEPT
        echo "Opened port $2/$3"
        ;;
    close-port)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 close-port <port> <tcp|udp>"
            exit 1
        fi
        iptables -D GAMING_${3^^} -p $3 --dport $2 -j ACCEPT
        echo "Closed port $2/$3"
        ;;
    game-mode)
        echo "Enabling game mode (reduced security, maximum performance)..."
        # Temporarily allow all gaming ranges
        iptables -I INPUT -p udp --dport 1024:65535 -j ACCEPT
        iptables -I INPUT -p tcp --dport 1024:65535 -j ACCEPT
        echo "Game mode enabled - all high ports open"
        echo "Remember to disable with: $0 secure-mode"
        ;;
    secure-mode)
        echo "Enabling secure mode..."
        iptables -D INPUT -p udp --dport 1024:65535 -j ACCEPT 2>/dev/null
        iptables -D INPUT -p tcp --dport 1024:65535 -j ACCEPT 2>/dev/null
        $0 restart
        echo "Secure mode enabled"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|open-port|close-port|game-mode|secure-mode}"
        exit 1
        ;;
esac
FW_SCRIPT
    
    chmod +x /mnt/gentoo/usr/local/bin/gaming-firewall
    
    # Enable firewall on boot
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /mnt/gentoo/etc/systemd/system/gaming-firewall.service << 'FW_SERVICE'
[Unit]
Description=RaptorOS Gaming Firewall
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gaming-firewall start
ExecStop=/usr/local/bin/gaming-firewall stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FW_SERVICE
        
        chroot /mnt/gentoo systemctl enable gaming-firewall.service
    else
        cat > /mnt/gentoo/etc/init.d/gaming-firewall << 'FW_OPENRC'
#!/sbin/openrc-run

description="RaptorOS Gaming Firewall"

depend() {
    after net
}

start() {
    ebegin "Starting Gaming Firewall"
    /usr/local/bin/gaming-firewall start
    eend $?
}

stop() {
    ebegin "Stopping Gaming Firewall"
    /usr/local/bin/gaming-firewall stop
    eend $?
}
FW_OPENRC
        chmod +x /mnt/gentoo/etc/init.d/gaming-firewall
        chroot /mnt/gentoo rc-update add gaming-firewall default
    fi
    
    dialog --msgbox "Gaming firewall configured!\n\n\
Commands available:\n\
• gaming-firewall start/stop/status\n\
• gaming-firewall open-port <port> <tcp/udp>\n\
• gaming-firewall game-mode (temp open all)\n\
• gaming-firewall secure-mode (strict)\n\n\
Firewall will start automatically on boot." 16 60
}
