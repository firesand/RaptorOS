#!/bin/bash
# RaptorOS UI Helper Module
# Beautiful ASCII art and progress visualization

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Progress bar with ASCII art
show_progress() {
    local current=$1
    local total=$2
    local status=$3
    local width=50
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Clear line and move cursor to beginning
    echo -ne "\r\033[K"
    
    # Draw progress bar
    echo -ne "${CYAN}["
    echo -ne "${GREEN}"
    for ((i=0; i<filled; i++)); do
        echo -ne "█"
    done
    echo -ne "${DIM}${WHITE}"
    for ((i=0; i<empty; i++)); do
        echo -ne "░"
    done
    echo -ne "${NC}${CYAN}]${NC}"
    
    # Show percentage and status
    echo -ne " ${BOLD}${WHITE}${percent}%${NC} - ${YELLOW}${status}${NC}"
}

# Animated spinner
show_spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local delay=0.1
    
    echo -ne "$message "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN}[%c]${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        echo -ne "\b\b\b"
    done
    echo -ne "\b\b\b${GREEN}[✓]${NC}\n"
}

# RaptorOS ASCII art for different stages
show_raptor_stage() {
    local stage=$1
    
    case $stage in
        "welcome")
            cat << 'EOF'
            
                    ▄▄▄▄▄▄▄▄
                  ▄█▀▀    ▀▀█▄
                ▄█▀  ▄▄██▄▄  ▀█▄
               █▀  ▄█▀    ▀█▄  ▀█
              █  ▄█  ▄▀▀▀▄  █▄  █
             █  █   █  ▄  █   █  █
            █  █    █  ▀  █    █  █
            █  █     ▀▄▄▄▀     █  █
            █  ▀█▄    ▄▄▄    ▄█▀  █
             █  ▀█▄  █ R █  ▄█▀  █
              █▄  ▀█▄▄▄▄▄▄█▀  ▄█
               ▀█▄▄        ▄▄█▀
                  ▀▀█▄▄▄▄█▀▀
            
            ╦═╗┌─┐┌─┐┌┬┐┌─┐┬─┐╔═╗╔═╗
            ╠╦╝├─┤├─┘ │ │ │├┬┘║ ║╚═╗
            ╩╚═┴ ┴┴   ┴ └─┘┴└─╚═╝╚═╝
             Performance Evolved™
EOF
            ;;
            
        "partitioning")
            cat << 'EOF'
                    🦖 Hunting for disk space...
                    
                 ╔═══════════════════════╗
                 ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
                 ║ ░░░░░░░░░░░░░░░░░░░░ ║
                 ╚═══════════════════════╝
                    Carving territories
EOF
            ;;
            
        "installing")
            cat << 'EOF'
                    🦖 Evolving system...
                    
                      ╱▔▔▔▔▔▔▔▔▔╲
                     ╱   COMPILING ╲
                    │  ███████░░░░░ │
                     ╲             ╱
                      ╲▁▁▁▁▁▁▁▁▁╱
EOF
            ;;
            
        "complete")
            cat << 'EOF'
            
                 ✨ EVOLUTION COMPLETE ✨
                 
                    ▄▄▄▄▄▄▄▄▄▄▄▄▄
                   █             █
                  █   READY TO    █
                  █     GAME!     █
                   █             █
                    ▀▀▀▀▀▀▀▀▀▀▀▀▀
                    
            ╦═╗┌─┐┌─┐┌┬┐┌─┐┬─┐╔═╗╔═╗
            ╠╦╝├─┤├─┘ │ │ │├┬┘║ ║╚═╗
            ╩╚═┴ ┴┴   ┴ └─┘┴└─╚═╝╚═╝
EOF
            ;;
    esac
}

# Enhanced installation progress with visuals
show_installation_progress() {
    local step=$1
    local total_steps=10
    local description=$2
    
    clear
    
    # Show RaptorOS header
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${BOLD}${GREEN}RaptorOS Installation Progress${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current step
    echo -e "${BOLD}Step ${step}/${total_steps}: ${description}${NC}"
    echo ""
    
    # Visual progress bar
    local percent=$((step * 100 / total_steps))
    local bar_width=60
    local filled=$((bar_width * step / total_steps))
    
    echo -ne "Overall Progress: ${CYAN}["
    
    for ((i=1; i<=bar_width; i++)); do
        if [ $i -le $filled ]; then
            echo -ne "${GREEN}█"
        else
            echo -ne "${DIM}${WHITE}░"
        fi
    done
    
    echo -e "${NC}${CYAN}]${NC} ${BOLD}${percent}%${NC}"
    echo ""
    
    # Show step details with icons
    local steps=(
        "🔍 Hardware Detection"
        "💾 Disk Partitioning" 
        "📦 Base System Extraction"
        "⚙️ Portage Configuration"
        "🐧 Kernel Installation"
        "🎮 GPU Driver Setup"
        "🖥️ Desktop Environment"
        "🎯 Gaming Stack"
        "🔧 System Optimization"
        "✅ Final Configuration"
    )
    
    echo -e "${BOLD}Installation Steps:${NC}"
    for ((i=0; i<${#steps[@]}; i++)); do
        local step_num=$((i + 1))
        if [ $step_num -lt $step ]; then
            echo -e "  ${GREEN}✓${NC} ${steps[$i]}"
        elif [ $step_num -eq $step ]; then
            echo -e "  ${YELLOW}▶${NC} ${BOLD}${steps[$i]}${NC} ${CYAN}[IN PROGRESS]${NC}"
        else
            echo -e "  ${DIM}○ ${steps[$i]}${NC}"
        fi
    done
    
    echo ""
}

# Animated installation with substeps
perform_installation_animated() {
    local total_steps=10
    
    # Step 1: Hardware Detection
    show_installation_progress 1 "Detecting Hardware"
    detect_hardware &
    show_spinner $! "Scanning system components..."
    
    # Step 2: Disk Partitioning
    show_installation_progress 2 "Creating Partitions"
    show_raptor_stage "partitioning"
    create_partitions
    
    # Step 3: Base System
    show_installation_progress 3 "Extracting Base System"
    (
        extract_stage3 2>&1 | while IFS= read -r line; do
            if [[ "$line" == *"Extracting"* ]]; then
                echo -ne "\r${CYAN}Extracting: ${NC}${line: -50}"
            fi
        done
    )
    
    # Continue with remaining steps...
    # Each step would call show_installation_progress with updated values
}

# Beautiful error display
show_error() {
    local error_msg=$1
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                         ERROR DETECTED                        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}  ✗ ${error_msg}${NC}"
    echo ""
    echo -e "${YELLOW}  Press any key to continue...${NC}"
    read -n 1
}

# Success message with ASCII art
show_success() {
    local message=$1
    
    echo ""
    echo -e "${GREEN}     ✨ SUCCESS ✨${NC}"
    echo -e "${GREEN}  ╔════════════════╗${NC}"
    echo -e "${GREEN}  ║       ✓        ║${NC}"
    echo -e "${GREEN}  ╚════════════════╝${NC}"
    echo -e "${CYAN}  ${message}${NC}"
    echo ""
}
