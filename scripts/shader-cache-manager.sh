#!/bin/bash
# RaptorOS Shader Cache Manager
# Manages DXVK, VKD3D, and GL shader caches

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cache locations
DXVK_CACHE="$HOME/.cache/dxvk"
VKD3D_CACHE="$HOME/.cache/vkd3d"
GL_CACHE="$HOME/.cache/mesa_shader_cache"
NVIDIA_GL_CACHE="$HOME/.nv/GLCache"

# Function to get cache size
get_cache_size() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Function to show cache info
show_cache_info() {
    echo -e "${CYAN}=== RaptorOS Shader Cache Status ===${NC}\n"
    
    echo -e "${GREEN}DXVK Cache:${NC}"
    echo "  Location: $DXVK_CACHE"
    echo "  Size: $(get_cache_size "$DXVK_CACHE")"
    echo "  Files: $(find "$DXVK_CACHE" -type f 2>/dev/null | wc -l)"
    
    echo -e "\n${GREEN}VKD3D Cache:${NC}"
    echo "  Location: $VKD3D_CACHE"
    echo "  Size: $(get_cache_size "$VKD3D_CACHE")"
    echo "  Files: $(find "$VKD3D_CACHE" -type f 2>/dev/null | wc -l)"
    
    echo -e "\n${GREEN}Mesa GL Cache:${NC}"
    echo "  Location: $GL_CACHE"
    echo "  Size: $(get_cache_size "$GL_CACHE")"
    
    if [ -d "$NVIDIA_GL_CACHE" ]; then
        echo -e "\n${GREEN}NVIDIA GL Cache:${NC}"
        echo "  Location: $NVIDIA_GL_CACHE"
        echo "  Size: $(get_cache_size "$NVIDIA_GL_CACHE")"
    fi
    
    # Total size
    local total=0
    for cache in "$DXVK_CACHE" "$VKD3D_CACHE" "$GL_CACHE" "$NVIDIA_GL_CACHE"; do
        if [ -d "$cache" ]; then
            total=$((total + $(du -sb "$cache" 2>/dev/null | cut -f1)))
        fi
    done
    echo -e "\n${CYAN}Total Cache Size: $(numfmt --to=iec-i --suffix=B $total)${NC}"
}

# Function to clean old cache files
clean_old_cache() {
    local days="${1:-30}"
    echo -e "${YELLOW}Cleaning cache files older than $days days...${NC}"
    
    local cleaned=0
    
    # Clean DXVK cache
    if [ -d "$DXVK_CACHE" ]; then
        local count=$(find "$DXVK_CACHE" -type f -mtime +$days 2>/dev/null | wc -l)
        find "$DXVK_CACHE" -type f -mtime +$days -delete 2>/dev/null
        cleaned=$((cleaned + count))
        echo "  Removed $count old DXVK cache files"
    fi
    
    # Clean VKD3D cache
    if [ -d "$VKD3D_CACHE" ]; then
        local count=$(find "$VKD3D_CACHE" -type f -mtime +$days 2>/dev/null | wc -l)
        find "$VKD3D_CACHE" -type f -mtime +$days -delete 2>/dev/null
        cleaned=$((cleaned + count))
        echo "  Removed $count old VKD3D cache files"
    fi
    
    echo -e "${GREEN}Cleaned $cleaned cache files total${NC}"
}

# Function to backup shader cache
backup_cache() {
    local backup_dir="$HOME/shader-cache-backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "${CYAN}Backing up shader caches to $backup_dir...${NC}"
    
    mkdir -p "$backup_dir"
    
    [ -d "$DXVK_CACHE" ] && cp -r "$DXVK_CACHE" "$backup_dir/"
    [ -d "$VKD3D_CACHE" ] && cp -r "$VKD3D_CACHE" "$backup_dir/"
    [ -d "$GL_CACHE" ] && cp -r "$GL_CACHE" "$backup_dir/"
    [ -d "$NVIDIA_GL_CACHE" ] && cp -r "$NVIDIA_GL_CACHE" "$backup_dir/"
    
    # Compress backup
    tar czf "$backup_dir.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    echo -e "${GREEN}Backup saved to: $backup_dir.tar.gz${NC}"
}

# Function to restore shader cache
restore_cache() {
    local backup_file="$1"
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Restoring shader cache from $backup_file...${NC}"
    
    # Extract to temp directory
    local temp_dir="/tmp/shader-cache-restore-$$"
    mkdir -p "$temp_dir"
    tar xzf "$backup_file" -C "$temp_dir"
    
    # Restore caches
    local backup_content="$temp_dir/$(ls "$temp_dir")"
    [ -d "$backup_content/dxvk" ] && cp -r "$backup_content/dxvk" "$HOME/.cache/"
    [ -d "$backup_content/vkd3d" ] && cp -r "$backup_content/vkd3d" "$HOME/.cache/"
    [ -d "$backup_content/mesa_shader_cache" ] && cp -r "$backup_content/mesa_shader_cache" "$HOME/.cache/"
    [ -d "$backup_content/GLCache" ] && cp -r "$backup_content/GLCache" "$HOME/.nv/"
    
    rm -rf "$temp_dir"
    echo -e "${GREEN}Cache restored successfully${NC}"
}

# Function to optimize cache
optimize_cache() {
    echo -e "${CYAN}Optimizing shader caches...${NC}"
    
    # Set cache size limits
    export MESA_GLSL_CACHE_MAX_SIZE="1G"
    export MESA_SHADER_CACHE_MAX_SIZE="1G"
    
    # Create config for persistent settings
    cat > "$HOME/.config/shader-cache.conf" << EOF
# RaptorOS Shader Cache Configuration
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="$DXVK_CACHE"
export MESA_GLSL_CACHE_MAX_SIZE="1G"
export MESA_SHADER_CACHE_MAX_SIZE="1G"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_SHADER_DISK_CACHE_SIZE=1073741824
export VKD3D_SHADER_CACHE_PATH="$VKD3D_CACHE"
EOF
    
    # Add to bashrc if not already there
    if ! grep -q "shader-cache.conf" "$HOME/.bashrc"; then
        echo "[ -f ~/.config/shader-cache.conf ] && source ~/.config/shader-cache.conf" >> "$HOME/.bashrc"
    fi
    
    echo -e "${GREEN}Cache optimization complete${NC}"
}

# Main menu
main_menu() {
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   RaptorOS Shader Cache Manager     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Show cache information"
    echo "2) Clean old cache files (30+ days)"
    echo "3) Clean all cache files"
    echo "4) Backup shader cache"
    echo "5) Restore shader cache"
    echo "6) Optimize cache settings"
    echo "7) Set cache size limit"
    echo "8) Exit"
    echo ""
    read -p "Select option [1-8]: " choice
    
    case $choice in
        1)
            show_cache_info
            ;;
        2)
            read -p "Clean files older than how many days? [30]: " days
            days=${days:-30}
            clean_old_cache "$days"
            ;;
        3)
            read -p "Are you sure you want to delete ALL shader caches? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -rf "$DXVK_CACHE" "$VKD3D_CACHE" "$GL_CACHE" "$NVIDIA_GL_CACHE"
                echo -e "${GREEN}All caches cleared${NC}"
            fi
            ;;
        4)
            backup_cache
            ;;
        5)
            read -p "Enter backup file path: " backup_file
            restore_cache "$backup_file"
            ;;
        6)
            optimize_cache
            ;;
        7)
            read -p "Enter max cache size (e.g., 1G, 500M): " size
            export MESA_GLSL_CACHE_MAX_SIZE="$size"
            export MESA_SHADER_CACHE_MAX_SIZE="$size"
            echo "Cache size limit set to $size"
            ;;
        8)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
    main_menu
}

# Run main menu if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    clear
    main_menu
fi
