#!/data/data/com.termux/files/usr/bin/bash

# ================================================
# TermuxEnv Manager v2.4.1 (Path & Glob Fix)
# Professional Termux Environment Backup & Restore
# Author: @Black-1-owl
# GitHub: https://github.com/Black-1-owl/TermuxEnv-Manager
# Created: April 2025
# Eeleased: January 2026
# License: MIT
# ================================================

# Configuration
AUTHOR="@Black-1-owl"
VERSION="2.4.1"
REPO_URL="https://github.com/Black-1-owl/TermuxEnv-Manager"
CREATED_BY="Black-1-owl"
LICENSE="MIT"

# Colors for better UI
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Backup configuration - Ahhhhhhh 🤧
BACKUP_DIR="$HOME/storage/shared/Download/TermuxBackups"
TERMUX_PATH="/data/data/com.termux/files"  # ✅ FIXED: Removed the extra path navigation
METADATA_FILE=".backup_meta.info"
INSTALLED_MARKER="$HOME/.termux_manager_installed"

# Backup Types
TYPE_FULL="FULL_DATA"
TYPE_HOME="HOME_ONLY"
TYPE_QUICK="QUICK"
TYPE_CUSTOM="CUSTOM"

# Display header with branding - I sucks with ASCII so get used to this 🥲
show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     ████████╗███████╗██████╗ ███╗   ███╗    ║${NC}"
    echo -e "${BLUE}║     ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║    ║${NC}"
    echo -e "${GREEN}║        ██║   █████╗  ██████╔╝██╔████╔██║    ║${NC}"
    echo -e "${GREEN}║        ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║    ║${NC}"
    echo -e "${CYAN}║        ██║   ███████╗██║  ██║██║ ╚═╝ ██║    ║${NC}"
    echo -e "${CYAN}║        ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝    ║${NC}"
    echo -e "${BLUE}║                                              ║${NC}"
    echo -e "${BLUE}║       TermuxEnv Manager v${VERSION}         ║${NC}"
    echo -e "${BLUE}║       by ${WHITE}${AUTHOR}${BLUE}                      ║${NC}"
    echo -e "${BLUE}║       ${WHITE}${REPO_URL}${BLUE} ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# storage permission
setup_storage() {
    if [ ! -d "$HOME/storage" ]; then
        echo -e "${YELLOW}Granting storage permission...${NC}"
        termux-setup-storage
        sleep 2
    fi
}

# Check for required commands
check_requirements() {
    local missing=()
    
    if ! command -v tar &> /dev/null; then
        echo -e "${YELLOW}Installing tar...${NC}"
        pkg update -y && pkg install -y tar
    fi
    
    if ! command -v pv &> /dev/null; then
        echo -e "${YELLOW}Installing pv (progress viewer)...${NC}"
        pkg install -y pv
    fi
    
    if ! command -v rsync &> /dev/null; then
        echo -e "${YELLOW}Installing rsync...${NC}"
        pkg install -y rsync
    fi
    
    if ! command -v grep &> /dev/null || ! command -v awk &> /dev/null; then
        pkg install -y grep gawk
    fi
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}Created backup directory: $BACKUP_DIR${NC}"
    fi
}

# Check available disk space
check_disk_space() {
    local required_mb=$1
    local backup_location="$BACKUP_DIR"
    
    if [ ! -d "$backup_location" ]; then
        backup_location="$HOME/storage/shared/Download"
    fi
    
    echo -e "${BLUE}Checking available disk space...${NC}"
    
    local available_kb=$(df "$backup_location" 2>/dev/null | tail -1 | awk '{print $4}')
    
    if [ -z "$available_kb" ]; then
        echo -e "${YELLOW}Warning: Cannot determine available disk space${NC}"
        return 0
    fi
    
    local available_mb=$((available_kb / 1024))
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        echo -e "${RED}Insufficient disk space!${NC}"
        echo -e "${YELLOW}Required: ${required_mb}MB | Available: ${available_mb}MB${NC}"
        return 1
    fi
    
    return 0
}

# Verify backup integrity
verify_backup() {
    local backup_file=$1
    echo -e "${BLUE}Verifying backup integrity...${NC}"
    
    if tar -tzf "$backup_file" &>/dev/null; then
        echo -e "${GREEN}✓ Backup verified${NC}"
        return 0
    else
        echo -e "${RED}✗ Backup corrupted!${NC}"
        echo -e "${YELLOW}Removing corrupted backup...${NC}"
        rm -f "$backup_file"
        return 1
    fi
}

# Rotate old backups
rotate_backups() {
    shopt -s nullglob
    
    local max_backups=15
    local backup_count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    
    if [ "$backup_count" -gt "$max_backups" ]; then
        echo -e "${YELLOW}Rotating old backups (keeping ${max_backups} most recent)...${NC}"
        ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +$((max_backups + 1)) | while read old_backup; do
            echo -e "${BLUE}Removing: $(basename "$old_backup")${NC}"
            rm -f "$old_backup"
        done
        echo -e "${GREEN}✓ Backup rotation complete${NC}"
    fi
    
    shopt -u nullglob
}

# Create metadata file
create_metadata() {
    local backup_type=$1
    local custom_note=$2
    local metadata_path=$3
    
    cat > "$metadata_path" << EOF
BACKUP_TYPE=$backup_type
CREATED=$(date +"%Y-%m-%d %H:%M:%S %Z")
TERMUX_VERSION=$(termux-info 2>/dev/null | head -n1 | sed 's/.*: //' || echo "Unknown")
USER=$USER
CUSTOM_NOTE=$custom_note
SCRIPT_VERSION=$VERSION
EOF
}

# Full data backup (Home + Package List)
backup_full_data() {
    show_header
    echo -e "${GREEN}Creating Full Data Backup${NC}"
    echo -e "${YELLOW}✓ Includes:${NC}"
    echo "  • Home directory (scripts, configs, projects)"
    echo "  • List of installed packages"
    echo -e "${YELLOW}⚠️  Note:${NC}"
    echo "  • System files are NOT included (safety)"
    echo "  • Packages will be saved for auto-reinstall"
    echo ""
    
    # Estimate space needed
    echo -e "${BLUE}Calculating backup size... This may take a moment...${NC}"
    local home_size_kb=$(du -sk "$HOME" 2>/dev/null | awk '{print $1}')
    local required_mb=$((home_size_kb / 1024 + 50))
    
    if ! check_disk_space "$required_mb"; then
        read -p "Press Enter to continue..."
        return
    fi
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_data_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    create_metadata "$TYPE_FULL" "Full data backup" "$METADATA_PATH"
    
    # Save package list
    echo -e "${BLUE}Saving package list...${NC}"
    pkg list-installed > "$BACKUP_DIR/installed_packages_$TIMESTAMP.txt"
    echo -e "${GREEN}✓ Package list saved${NC}"
    
    # Create backup with progress
    echo -e "${BLUE}Creating backup archive... This might take several minutes...${NC}"
    cd "$TERMUX_PATH" || exit 1
    
    if command -v du &> /dev/null; then
        TOTAL_SIZE=$(du -sk ./home 2>/dev/null | awk '{print $1}')
        if [ -n "$TOTAL_SIZE" ]; then
            tar -czf - ./home "$METADATA_FILE" 2>/dev/null | \
                pv -s ${TOTAL_SIZE}k > "$BACKUP_FILE"
        else
            tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
        fi
    else
        tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
    fi
    
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        if verify_backup "$BACKUP_FILE"; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
            echo -e "${GREEN}✓ Backup successful!${NC}"
            echo -e "${BLUE}File: $(basename "$BACKUP_FILE")${NC}"
            echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
            echo -e "${BLUE}Package list: installed_packages_$TIMESTAMP.txt${NC}"
            
            rotate_backups
        else
            echo -e "${RED}✗ Backup verification failed!${NC}"
        fi
    else
        echo -e "${RED}✗ Backup failed!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Backup home directory only
backup_home() {
    show_header
    echo -e "${GREEN}Backup Home Directory Only${NC}"
    echo -e "${YELLOW}Backups:${NC}"
    echo "  • Scripts and config files"
    echo "  • Projects and personal files"
    echo "  • Settings and dotfiles"
    echo ""
    
    echo -e "${BLUE}Calculating backup size... This may take a moment...${NC}"
    local home_size_kb=$(du -sk "$HOME" 2>/dev/null | awk '{print $1}')
    local required_mb=$((home_size_kb / 1024 + 50))
    
    if ! check_disk_space "$required_mb"; then
        read -p "Press Enter to continue..."
        return
    fi
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_home_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    create_metadata "$TYPE_HOME" "Home directory backup" "$METADATA_PATH"
    
    echo -e "${BLUE}Creating backup... This might take several minutes...${NC}"
    cd "$TERMUX_PATH" || exit 1
    
    if command -v du &> /dev/null; then
        TOTAL_SIZE=$(du -sk ./home 2>/dev/null | awk '{print $1}')
        if [ -n "$TOTAL_SIZE" ]; then
            tar -czf - ./home "$METADATA_FILE" 2>/dev/null | \
                pv -s ${TOTAL_SIZE}k > "$BACKUP_FILE"
        else
            tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
        fi
    else
        tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
    fi
    
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        if verify_backup "$BACKUP_FILE"; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
            echo -e "${GREEN}✓ Backup successful!${NC}"
            echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
            
            rotate_backups
        else
            echo -e "${RED}✗ Backup verification failed!${NC}"
        fi
    else
        echo -e "${RED}✗ Backup failed!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Backup custom selection
backup_custom() {
    show_header
    echo -e "${GREEN}Custom Backup Selection${NC}"
    echo -e "${YELLOW}Enter paths (space separated):${NC}"
    echo "Examples:"
    echo "  .bashrc .config/nano"
    echo "  scripts projects/myapp"
    echo ""
    
    read -p "Paths or 'list': " input
    
    if [ "$input" = "list" ]; then
        echo -e "${BLUE}Loading home directory contents...${NC}"
        ls -la "$HOME"
        echo ""
        read -p "Enter paths: " input
    fi
    
    if [ -z "$input" ]; then
        echo -e "${RED}No paths specified${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    IFS=' ' read -ra paths <<< "$input"
    
    local valid_paths=()
    local invalid_paths=()
    
    echo -e "${BLUE}Validating paths...${NC}"
    for path in "${paths[@]}"; do
        if [ -e "$HOME/$path" ]; then
            valid_paths+=("./home/$path")
        else
            invalid_paths+=("$path")
        fi
    done
    
    if [ ${#invalid_paths[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: These paths don't exist:${NC}"
        printf '%s\n' "${invalid_paths[@]}"
        echo ""
        
        if [ ${#valid_paths[@]} -eq 0 ]; then
            echo -e "${RED}No valid paths to backup${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        read -p "Continue with valid paths only? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            return
        fi
    fi
    
    if ! check_disk_space 100; then
        read -p "Press Enter to continue..."
        return
    fi
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_custom_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    create_metadata "$TYPE_CUSTOM" "Custom backup: $input" "$METADATA_PATH"
    
    echo -e "${BLUE}Creating custom backup... Please wait...${NC}"
    cd "$TERMUX_PATH" || exit 1
    
    tar -czf "$BACKUP_FILE" "${valid_paths[@]}" "$METADATA_FILE" 2>/dev/null
    
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        if verify_backup "$BACKUP_FILE"; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
            echo -e "${GREEN}✓ Custom backup successful!${NC}"
            echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
            
            rotate_backups
        else
            echo -e "${RED}✗ Backup verification failed!${NC}"
        fi
    else
        echo -e "${RED}✗ Backup failed!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Read metadata from backup 
read_backup_metadata() {
    local backup_file=$1
    local temp_dir=$(mktemp -d) || {
        echo "UNKNOWN|Unknown date|Unknown version|Failed to create temp directory"
        return 1
    }
    
    if tar -tzf "$backup_file" 2>/dev/null | grep -q "$METADATA_FILE"; then
        tar -xzf "$backup_file" -C "$temp_dir" --wildcards "*$METADATA_FILE" 2>/dev/null
        local found_meta=$(find "$temp_dir" -name "$METADATA_FILE" -type f 2>/dev/null | head -1)
        
        if [ -f "$found_meta" ]; then
            BACKUP_TYPE=""
            CREATED=""
            TERMUX_VERSION=""
            CUSTOM_NOTE=""
            
            while IFS='=' read -r key value; do
                case $key in
                    BACKUP_TYPE) BACKUP_TYPE="$value" ;;
                    CREATED) CREATED="$value" ;;
                    TERMUX_VERSION) TERMUX_VERSION="$value" ;;
                    CUSTOM_NOTE) CUSTOM_NOTE="$value" ;;
                esac
            done < "$found_meta"
            
            BACKUP_TYPE="${BACKUP_TYPE:-UNKNOWN}"
            CREATED="${CREATED:-Unknown date}"
            TERMUX_VERSION="${TERMUX_VERSION:-Unknown version}"
            CUSTOM_NOTE="${CUSTOM_NOTE:-No metadata}"
            
            echo "$BACKUP_TYPE|$CREATED|$TERMUX_VERSION|$CUSTOM_NOTE"
        else
            echo "UNKNOWN|Unknown date|Unknown version|No metadata"
        fi
    else
        local filename=$(basename "$backup_file")
        if [[ "$filename" == *"termux_data_"* ]]; then
            echo "FULL_DATA|Unknown date|Unknown version|Legacy backup"
        elif [[ "$filename" == *"termux_home_"* ]]; then
            echo "HOME_ONLY|Unknown date|Unknown version|Legacy backup"
        else
            echo "UNKNOWN|Unknown date|Unknown version|No metadata"
        fi
    fi
    
    if [[ -n "$temp_dir" ]] && [[ "$temp_dir" != "/" ]] && [[ "$temp_dir" == /tmp/* ]]; then
        rm -rf "$temp_dir" 2>/dev/null
    fi
}

# List available backups with metadata - What you doing here 👀 
list_backups() {
    shopt -s nullglob
    
    show_header
    echo -e "${GREEN}Available Backups:${NC}"
    echo ""
    echo -e "${BLUE}Loading backups... This may take a moment...${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backups found (directory doesn't exist)${NC}"
        shopt -u nullglob
        return 1
    fi
    
    # Check if any .tar.gz files exist
    local backup_files=("$BACKUP_DIR"/*.tar.gz)
    
    if [ ${#backup_files[@]} -eq 0 ] || [ ! -f "${backup_files[0]}" ]; then
        echo -e "${YELLOW}No backups found${NC}"
        shopt -u nullglob
        return 1
    fi
    
    count=1
    
    echo -e "${CYAN}No. | Type        | Date       | Size   | File${NC}"
    echo -e "${CYAN}----|-------------|------------|--------|----------------${NC}"
    
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "??")
            
            metadata=$(read_backup_metadata "$file")
            IFS='|' read -r backup_type created_date version custom_note <<< "$metadata"
            
            case $backup_type in
                FULL_DATA) type_color=$GREEN; type_display="FULL DATA" ;;
                HOME_ONLY) type_color=$YELLOW; type_display="HOME ONLY" ;;
                CUSTOM) type_color=$BLUE; type_display="CUSTOM" ;;
                QUICK) type_color=$CYAN; type_display="QUICK" ;;
                *) type_color=$WHITE; type_display="UNKNOWN" ;;
            esac
            
            short_date=$(echo "$created_date" | cut -d' ' -f1 | sed 's/202[0-9]-//' 2>/dev/null || echo "??-??")
            
            printf "${WHITE}%2d) ${type_color}%-11s${WHITE} | %-10s | %-6s | %s${NC}\n" \
                "$count" "$type_display" "$short_date" "$size" "$filename"
            
            ((count++))
        fi
    done
    
    echo ""
    echo -e "${CYAN}Total backups: $((count-1))${NC}"
    
    shopt -u nullglob
    
    if [ $count -eq 1 ]; then
        return 1
    fi
    return 0
}

# Validate package exists in repository
validate_package() {
    local pkg_name=$1
    
    if pkg show "$pkg_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Safe restore using rsync + Auto Package Install
restore_backup() {
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}Select backup to restore (enter number):${NC}"
    read -p "Choice: " choice
    
    shopt -s nullglob
    
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    
    echo -e "${BLUE}Reading backup metadata... Please wait...${NC}"
    metadata=$(read_backup_metadata "$BACKUP_FILE")
    IFS='|' read -r backup_type created_date version custom_note <<< "$metadata"
    
    show_header
    echo -e "${RED}⚠️  IMPORTANT RESTORE INFORMATION${NC}"
    echo -e "${YELLOW}Backup: $BACKUP_NAME${NC}"
    echo -e "${BLUE}Type: $backup_type${NC}"
    echo -e "${BLUE}Created: $created_date${NC}"
    echo ""
    
    echo -e "${RED}WARNING: This will overwrite existing files!${NC}"
    read -p "Type 'RESTORE' to confirm: " confirm
    
    if [ "$confirm" != "RESTORE" ]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}Creating temporary directory...${NC}"
    TEMP_DIR=$(mktemp -d) || {
        echo -e "${RED}✗ Failed to create temporary directory!${NC}"
        read -p "Press Enter to continue..."
        return
    }
    
    echo -e "${BLUE}Extracting backup... This might take several minutes...${NC}"
    if command -v pv &> /dev/null; then
        pv "$BACKUP_FILE" | tar -xz -C "$TEMP_DIR" 2>/dev/null
    else
        tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" 2>/dev/null
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Extract failed! File may be corrupted${NC}"
        if [[ -n "$TEMP_DIR" ]] && [[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" == /tmp/* ]]; then
            rm -rf "$TEMP_DIR"
        fi
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}Restoring files... This may take a few minutes...${NC}"
    
    if [ -d "$TEMP_DIR/home" ]; then
        echo -e "${YELLOW}Restoring home directory...${NC}"
        rsync -av --progress "$TEMP_DIR/home/" "$HOME/" 2>/dev/null
        
        if [ -d "$HOME/bin" ]; then
            chmod 755 "$HOME/bin" 2>/dev/null
        fi
        echo -e "${GREEN}✓ Home directory restored${NC}"
    fi

    # Automated Package Restore with Validation
    if [ "$backup_type" = "FULL_DATA" ]; then
        backup_ts=$(echo "$BACKUP_NAME" | grep -oE '[0-9]{8}_[0-9]{6}')
        pkg_list_file="$BACKUP_DIR/installed_packages_${backup_ts}.txt"
        
        if [ -f "$pkg_list_file" ]; then
            echo ""
            echo -e "${CYAN}Found associated package list!${NC}"
            echo -e "${YELLOW}Do you want to auto-install missing packages? (y/n)${NC}"
            read -p "Choice: " install_pkg
            
            if [ "$install_pkg" = "y" ]; then
                echo -e "${BLUE}Reading and validating package list...${NC}"
                
                packages=$(grep -v "Listing..." "$pkg_list_file" | awk -F/ '{print $1}' | grep -v '^$')
                
                if [ -n "$packages" ]; then
                    echo -e "${BLUE}Updating package database... Please wait...${NC}"
                    pkg update -y
                    
                    local validated_pkgs=""
                    local skipped_pkgs=""
                    local total_pkgs=0
                    local valid_pkgs=0
                    
                    echo -e "${BLUE}Validating packages... This may take a minute...${NC}"
                    for pkg_name in $packages; do
                        ((total_pkgs++))
                        
                        if validate_package "$pkg_name"; then
                            validated_pkgs="$validated_pkgs $pkg_name"
                            ((valid_pkgs++))
                            echo -e "${GREEN}✓${NC} $pkg_name"
                        else
                            skipped_pkgs="$skipped_pkgs $pkg_name"
                            echo -e "${YELLOW}⊘${NC} $pkg_name (not found in repository)"
                        fi
                    done
                    
                    echo ""
                    echo -e "${CYAN}Validation Summary:${NC}"
                    echo -e "  Total packages: $total_pkgs"
                    echo -e "  Valid packages: $valid_pkgs"
                    echo -e "  Skipped packages: $((total_pkgs - valid_pkgs))"
                    echo ""
                    
                    if [ -n "$validated_pkgs" ]; then
                        echo -e "${BLUE}Installing validated packages...${NC}"
                        echo -e "${YELLOW}⏳ This will take several minutes. Please be patient...${NC}"
                        
                        if pkg install -y $validated_pkgs; then
                            echo -e "${GREEN}✓ Package installation complete${NC}"
                        else
                            echo -e "${YELLOW}⚠ Some packages failed to install${NC}"
                        fi
                    else
                        echo -e "${YELLOW}No valid packages to install${NC}"
                    fi
                    
                    if [ -n "$skipped_pkgs" ]; then
                        echo ""
                        echo -e "${YELLOW}Skipped packages:${NC}"
                        echo "$skipped_pkgs" | tr ' ' '\n' | grep -v '^$'
                    fi
                else
                    echo -e "${RED}Could not parse package list${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}Note: No matching package list found in backup folder.${NC}"
        fi
    fi
    
    if [[ -n "$TEMP_DIR" ]] && [[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" == /tmp/* ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Restore completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Recommendation: Restart Termux for best results${NC}"
    
    read -p "Press Enter to continue..."
}

# Quick backup (one-click)
quick_backup() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/quick_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    echo -e "${GREEN}Creating quick backup...${NC}"
    echo -e "${BLUE}Calculating size...${NC}"
    local home_size_kb=$(du -sk "$HOME" 2>/dev/null | awk '{print $1}')
    local required_mb=$((home_size_kb / 1024 + 50))
    
    if ! check_disk_space "$required_mb"; then
        return 1
    fi
    
    cd "$TERMUX_PATH" || exit 1
    create_metadata "$TYPE_QUICK" "Quick backup" "$METADATA_PATH"
    
    echo -e "${BLUE}Creating archive... Please wait...${NC}"
    tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
    
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        if verify_backup "$BACKUP_FILE"; then
            echo -e "${GREEN}✓ Quick backup created: $(basename "$BACKUP_FILE")${NC}"
            rotate_backups
        else
            echo -e "${RED}✗ Quick backup verification failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Quick backup failed${NC}"
        return 1
    fi
}

# Install manager permanently
install_manager() {
    show_header
    echo -e "${GREEN}Installing Termux Environment Manager${NC}"
    echo ""
    
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin"
        chmod 755 "$HOME/bin"
    fi
    
    SCRIPT_PATH="$HOME/bin/termux-manager"
    
    echo -e "${BLUE}Installing script...${NC}"
    
    # ✅ FIXED: Look for correct filename
    if [ -f "TermuxEnvManager.bash" ]; then
        cp "TermuxEnvManager.bash" "$SCRIPT_PATH"
    else
        cp "$0" "$SCRIPT_PATH" 2>/dev/null || {
            echo -e "${RED}Cannot locate script to install${NC}"
            read -p "Press Enter to continue..."
            return
        }
    fi
    
    chmod +x "$SCRIPT_PATH"
    
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
        fi
    fi
    
    touch "$INSTALLED_MARKER"
    
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo -e "${BLUE}You can now run 'termux-manager' from anywhere${NC}"
    read -p "Press Enter to continue..."
}

# Show help
show_help() {
    show_header
    echo -e "${GREEN}Termux Environment Manager - Help${NC}"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  termux-manager          - Launch interactive menu"
    echo "  termux-manager --quick  - Create quick backup"
    echo "  termux-manager --help   - Show this help"
    echo ""
    echo -e "${CYAN}New in v2.4.1:${NC}"
    echo "  • FIXED: Backup directory path (now uses correct Android path)"
    echo "  • FIXED: Glob expansion bug (no more empty backup listings)"
    echo "  • Validated package re-installation (security enhancement)"
    echo "  • Disk space checking before operations"
    echo "  • Backup integrity verification"
    echo "  • Automatic backup rotation (keeps 15 most recent)"
    echo "  • Enhanced temp directory security"
    echo "  • Improved error handling and recovery"
    echo "  • Loading indicators for all operations"
    echo ""
    echo -e "${CYAN}Backup Types:${NC}"
    echo "  • FULL DATA - Home directory + package list"
    echo "  • HOME ONLY - Just your home directory files"
    echo "  • CUSTOM - Select specific files/folders"
    echo "  • QUICK - Fast one-click home backup"
    echo ""
    echo -e "${CYAN}Safety Features:${NC}"
    echo "  • All backups are verified after creation"
    echo "  • Package validation before installation"
    echo "  • Confirmation required for destructive operations"
    echo "  • Automatic old backup cleanup"
    echo "  • Safe temp directory handling"
    echo ""
    echo -e "${CYAN}Backup Location:${NC}"
    echo "  $BACKUP_DIR"
    echo ""
    echo -e "${CYAN}Tips:${NC}"
    echo "  • Regular backups recommended (weekly or before major changes)"
    echo "  • Test restore on non-critical data first"
    echo "  • Keep backups on external storage or cloud for safety"
    echo "  • Use FULL DATA backup before system updates"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Advanced restore options
advanced_restore_menu() {
    show_header
    echo -e "${RED}⚠️  ADVANCED RESTORE OPTIONS ⚠️${NC}"
    echo ""
    echo "1) Test Backup Integrity (Dry Run)"
    echo "2) View Backup Contents"
    echo "3) Extract Single File from Backup"
    echo "4) Compare Backup with Current System"
    echo "5) Back to Main Menu"
    echo ""
    
    read -p "Choose [1-5]: " choice
    
    case $choice in
        1) test_backup_integrity ;;
        2) view_backup_contents ;;
        3) extract_single_file ;;
        4) compare_backup ;;
        5) return ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1; advanced_restore_menu ;;
    esac
}

# Test backup integrity
test_backup_integrity() {
    show_header
    echo -e "${GREEN}Test Backup Integrity${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup to test (number): " choice
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    
    echo ""
    echo -e "${BLUE}Testing: $(basename "$BACKUP_FILE")${NC}"
    echo -e "${BLUE}⏳ This may take a moment... Please wait...${NC}"
    echo ""
    
    if tar -tzf "$BACKUP_FILE" &>/dev/null; then
        echo -e "${GREEN}✓ Backup integrity: GOOD${NC}"
        
        echo -e "${BLUE}Counting files...${NC}"
        local file_count=$(tar -tzf "$BACKUP_FILE" 2>/dev/null | wc -l)
        echo -e "${BLUE}Files in backup: $file_count${NC}"
        
        echo -e "${BLUE}Reading metadata...${NC}"
        metadata=$(read_backup_metadata "$BACKUP_FILE")
        IFS='|' read -r backup_type created_date version custom_note <<< "$metadata"
        
        echo -e "${BLUE}Type: $backup_type${NC}"
        echo -e "${BLUE}Created: $created_date${NC}"
        echo -e "${BLUE}Note: $custom_note${NC}"
    else
        echo -e "${RED}✗ Backup integrity: FAILED${NC}"
        echo -e "${YELLOW}This backup appears to be corrupted${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    advanced_restore_menu
}

# View backup contents
view_backup_contents() {
    show_header
    echo -e "${GREEN}View Backup Contents${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup to view (number): " choice
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    
    echo ""
    echo -e "${BLUE}⏳ Loading contents... Please wait...${NC}"
    echo ""
    echo -e "${BLUE}Contents of: $(basename "$BACKUP_FILE")${NC}"
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    
    tar -tzf "$BACKUP_FILE" 2>/dev/null | head -50
    
    local total_files=$(tar -tzf "$BACKUP_FILE" 2>/dev/null | wc -l)
    
    if [ "$total_files" -gt 50 ]; then
        echo -e "${YELLOW}... and $((total_files - 50)) more files${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Total files: $total_files${NC}"
    
    read -p "Press Enter to continue..."
    advanced_restore_menu
}

# Extract single file from backup
extract_single_file() {
    show_header
    echo -e "${GREEN}Extract Single File from Backup${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup (number): " choice
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    
    echo ""
    echo -e "${YELLOW}Enter file path to extract (e.g., home/.bashrc):${NC}"
    read -p "Path: " file_path
    
    if [ -z "$file_path" ]; then
        echo -e "${RED}No path specified${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    TEMP_DIR=$(mktemp -d) || {
        echo -e "${RED}Failed to create temp directory${NC}"
        read -p "Press Enter to continue..."
        return
    }
    
    echo ""
    echo -e "${BLUE}⏳ Extracting file... Please wait...${NC}"
    
    if tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" "$file_path" 2>/dev/null; then
        local extracted_file="$TEMP_DIR/$file_path"
        
        if [ -f "$extracted_file" ]; then
            echo -e "${GREEN}✓ File extracted successfully${NC}"
            echo ""
            echo -e "${BLUE}Preview (first 20 lines):${NC}"
            echo -e "${CYAN}─────────────────────────────────────${NC}"
            head -20 "$extracted_file"
            echo -e "${CYAN}─────────────────────────────────────${NC}"
            echo ""
            
            read -p "Restore this file to its original location? (y/n): " restore_choice
            
            if [ "$restore_choice" = "y" ]; then
                local target_path="${file_path#home/}"
                cp "$extracted_file" "$HOME/$target_path" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ File restored to: $HOME/$target_path${NC}"
                else
                    echo -e "${RED}✗ Failed to restore file${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ File not found in backup${NC}"
        fi
    else
        echo -e "${RED}✗ Extraction failed${NC}"
        echo -e "${YELLOW}File may not exist in backup${NC}"
    fi
    
    if [[ -n "$TEMP_DIR" ]] && [[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" == /tmp/* ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    advanced_restore_menu
}

# Compare backup with current system
compare_backup() {
    show_header
    echo -e "${GREEN}Compare Backup with Current System${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup to compare (number): " choice
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    
    echo ""
    echo -e "${BLUE}⏳ Comparing with current system...${NC}"
    echo -e "${YELLOW}This may take several minutes for large directories...${NC}"
    echo ""
    
    TEMP_DIR=$(mktemp -d) || {
        echo -e "${RED}Failed to create temp directory${NC}"
        read -p "Press Enter to continue..."
        return
    }
    
    echo -e "${BLUE}Extracting backup...${NC}"
    tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" 2>/dev/null
    
    if [ -d "$TEMP_DIR/home" ]; then
        echo -e "${BLUE}Analyzing files...${NC}"
        echo ""
        echo -e "${CYAN}Analysis Results:${NC}"
        echo -e "${CYAN}─────────────────────────────────────${NC}"
        
        local files_in_backup=$(find "$TEMP_DIR/home" -type f 2>/dev/null | wc -l)
        local files_current=$(find "$HOME" -type f 2>/dev/null | wc -l)
        
        echo -e "${BLUE}Files in backup: $files_in_backup${NC}"
        echo -e "${BLUE}Files in current home: $files_current${NC}"
        echo ""
        
        echo -e "${YELLOW}Files in backup but not in current system:${NC}"
        local missing_count=0
        
        find "$TEMP_DIR/home" -type f 2>/dev/null | while read backup_file; do
            relative_path="${backup_file#$TEMP_DIR/home/}"
            current_file="$HOME/$relative_path"
            
            if [ ! -f "$current_file" ]; then
                echo "  - $relative_path"
                ((missing_count++))
                
                if [ "$missing_count" -ge 20 ]; then
                    echo "  ... (showing first 20)"
                    break
                fi
            fi
        done
        
        echo ""
        echo -e "${YELLOW}New files in current system (not in backup):${NC}"
        local new_count=0
        
        find "$HOME" -type f 2>/dev/null | while read current_file; do
            relative_path="${current_file#$HOME/}"
            backup_file="$TEMP_DIR/home/$relative_path"
            
            if [ ! -f "$backup_file" ]; then
                echo "  + $relative_path"
                ((new_count++))
                
                if [ "$new_count" -ge 20 ]; then
                    echo "  ... (showing first 20)"
                    break
                fi
            fi
        done
        
        echo -e "${CYAN}─────────────────────────────────────${NC}"
    else
        echo -e "${RED}Cannot analyze backup structure${NC}"
    fi
    
    if [[ -n "$TEMP_DIR" ]] && [[ "$TEMP_DIR" != "/" ]] && [[ "$TEMP_DIR" == /tmp/* ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    advanced_restore_menu
}

# Delete backup
delete_backup() {
    show_header
    echo -e "${RED}Delete Backup${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup to delete (number) or 'all' to delete all: " choice
    
    if [ "$choice" = "all" ]; then
        echo ""
        echo -e "${RED}⚠️  WARNING: This will delete ALL backups!${NC}"
        read -p "Type 'DELETE ALL' to confirm: " confirm
        
        if [ "$confirm" = "DELETE ALL" ]; then
            echo -e "${BLUE}Deleting all backups...${NC}"
            shopt -s nullglob
            rm -f "$BACKUP_DIR"/*.tar.gz
            rm -f "$BACKUP_DIR"/installed_packages_*.txt
            shopt -u nullglob
            echo -e "${GREEN}✓ All backups deleted${NC}"
        else
            echo -e "${YELLOW}Deletion cancelled${NC}"
        fi
        
        read -p "Press Enter to continue..."
        return
    fi
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    
    echo ""
    echo -e "${RED}Delete: $BACKUP_NAME${NC}"
    read -p "Type 'DELETE' to confirm: " confirm
    
    if [ "$confirm" = "DELETE" ]; then
        echo -e "${BLUE}Deleting backup...${NC}"
        rm -f "$BACKUP_FILE"
        
        # Try to delete associated package list
        backup_ts=$(echo "$BACKUP_NAME" | grep -oE '[0-9]{8}_[0-9]{6}')
        if [ -n "$backup_ts" ]; then
            rm -f "$BACKUP_DIR/installed_packages_${backup_ts}.txt" 2>/dev/null
        fi
        
        echo -e "${GREEN}✓ Backup deleted${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Export backup to external location
export_backup() {
    show_header
    echo -e "${GREEN}Export Backup to External Location${NC}"
    echo ""
    
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    read -p "Select backup to export (number): " choice
    
    shopt -s nullglob
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    shopt -u nullglob
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    
    echo ""
    echo -e "${YELLOW}Enter destination path:${NC}"
    echo "Examples:"
    echo "  /sdcard/Documents"
    echo "  $HOME/storage/shared/Backups"
    echo ""
    read -p "Destination: " dest_path
    
    if [ -z "$dest_path" ]; then
        echo -e "${RED}No destination specified${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ ! -d "$dest_path" ]; then
        echo -e "${YELLOW}Directory doesn't exist. Create it? (y/n)${NC}"
        read -p "Choice: " create_dir
        
        if [ "$create_dir" = "y" ]; then
            echo -e "${BLUE}Creating directory...${NC}"
            mkdir -p "$dest_path"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to create directory${NC}"
                read -p "Press Enter to continue..."
                return
            fi
        else
            echo -e "${YELLOW}Export cancelled${NC}"
            read -p "Press Enter to continue..."
            return
        fi
    fi
    
    echo ""
    echo -e "${BLUE}⏳ Copying backup... This may take a few minutes...${NC}"
    
    if command -v pv &> /dev/null; then
        pv "$BACKUP_FILE" > "$dest_path/$BACKUP_NAME"
    else
        cp "$BACKUP_FILE" "$dest_path/$BACKUP_NAME"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup exported successfully${NC}"
        echo -e "${BLUE}Location: $dest_path/$BACKUP_NAME${NC}"
        
        # copy package list if it exists - bro what I'm doing 😮‍💨
        backup_ts=$(echo "$BACKUP_NAME" | grep -oE '[0-9]{8}_[0-9]{6}')
        pkg_list="$BACKUP_DIR/installed_packages_${backup_ts}.txt"
        
        if [ -f "$pkg_list" ]; then
            echo -e "${BLUE}Copying package list...${NC}"
            cp "$pkg_list" "$dest_path/" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${BLUE}Package list also exported${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ Export failed${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# System information
show_system_info() {
    show_header
    echo -e "${GREEN}System Information${NC}"
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    echo ""
    echo -e "${BLUE}⏳ Gathering system information...${NC}"
    echo ""
    
    echo -e "${BLUE}Termux Information:${NC}"
    termux-info 2>/dev/null || echo "  Termux info not available"
    echo ""
    
    echo -e "${BLUE}Storage Information:${NC}"
    df -h "$HOME" 2>/dev/null | tail -1 | awk '{print "  Used: "$3" / "$2" ("$5")"}'
    echo ""
    
    echo -e "${BLUE}Backup Directory:${NC}"
    echo "  Location: $BACKUP_DIR"
    
    if [ -d "$BACKUP_DIR" ]; then
        shopt -s nullglob
        local backup_files=("$BACKUP_DIR"/*.tar.gz)
        local backup_count=0
        
        if [ -f "${backup_files[0]}" ]; then
            backup_count=${#backup_files[@]}
        fi
        
        shopt -u nullglob
        
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo "  Backups: $backup_count"
        echo "  Total size: $backup_size"
    else
        echo "  Status: Not created yet"
    fi
    
    echo ""
    echo -e "${BLUE}Installed Packages:${NC}"
    local pkg_count=$(pkg list-installed 2>/dev/null | wc -l)
    echo "  Count: $pkg_count packages"
    echo ""
    
    echo -e "${BLUE}Home Directory:${NC}"
    echo -e "${YELLOW}Calculating size... This may take a moment...${NC}"
    local home_size=$(du -sh "$HOME" 2>/dev/null | cut -f1)
    local file_count=$(find "$HOME" -type f 2>/dev/null | wc -l)
    echo "  Size: $home_size"
    echo "  Files: $file_count"
    echo ""
    
    echo -e "${BLUE}Script Version:${NC}"
    echo "  Manager: v$VERSION"
    echo "  Location: $0"
    
    if [ -f "$INSTALLED_MARKER" ]; then
        echo "  Status: Installed permanently"
    else
        echo "  Status: Running standalone"
    fi
    
    echo ""
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_header
        echo -e "${WHITE}Main Menu:${NC}"
        echo ""
        echo -e "${GREEN}BACKUP OPTIONS:${NC}"
        echo "  1) Full Data Backup (Home + Package List)"
        echo "  2) Home Directory Backup Only"
        echo "  3) Custom Selection Backup"
        echo "  4) One-Click Quick Backup"
        echo ""
        echo -e "${YELLOW}RESTORE OPTIONS:${NC}"
        echo "  5) Restore from Backup"
        echo "  6) Advanced Restore Options"
        echo ""
        echo -e "${BLUE}MANAGEMENT:${NC}"
        echo "  7) List Available Backups"
        echo "  8) Delete Backup"
        echo "  9) Export Backup"
        echo ""
        echo -e "${CYAN}SYSTEM:${NC}"
        echo "  10) Install Permanently"
        echo "  11) System Information"
        echo "  12) Help"
        echo ""
        echo -e "${RED}  0) Exit${NC}"
        echo ""
        
        read -p "Choose [0-12]: " choice
        
        case $choice in
            1) backup_full_data ;;
            2) backup_home ;;
            3) backup_custom ;;
            4) quick_backup; read -p "Press Enter to continue..." ;;
            5) restore_backup ;;
            6) advanced_restore_menu ;;
            7) list_backups; read -p "Press Enter to continue..." ;;
            8) delete_backup ;;
            9) export_backup ;;
            10) install_manager ;;
            11) show_system_info ;;
            12) show_help ;;
            0) 
                clear
                echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║   Thank you for using                  ║${NC}"
                echo -e "${GREEN}║   Termux Environment Manager v${VERSION} ║${NC}"
                echo -e "${GREEN}║                                        ║${NC}"
                echo -e "${GREEN}║   Stay backed up, stay safe! 🛡️        ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
                echo ""
                exit 0 
                ;;
            *) 
                echo -e "${RED}Invalid option! Please choose 0-12${NC}"
                sleep 1 
                ;;
        esac
    done
}

# Initialize and start
echo -e "${GREEN}Initializing Termux Manager v${VERSION}...${NC}"
setup_storage
check_requirements
create_backup_dir

case "$1" in
    --quick|--fast) 
        quick_backup
        exit 0 
        ;;
    --help|-h) 
        show_help
        exit 0 
        ;;
    --install) 
        install_manager
        exit 0 
        ;;
    --version|-v) 
        echo "Termux Environment Manager v${VERSION}"
        echo "by $AUTHOR"
        echo "License: $LICENSE"
        exit 0 
        ;;
    --info)
        show_system_info
        exit 0
        ;;
    *) 
        main_menu 
        ;;
esac
