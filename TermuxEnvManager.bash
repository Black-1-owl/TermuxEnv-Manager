#!/data/data/com.termux/files/usr/bin/bash

# ================================================
# TermuxEnv Manager v2.2
# Professional Termux Environment Backup & Restore
# Author: @Black-1-owl
# GitHub: https://github.com/Black-1-owl/TermuxEnv-Manager
# Created: January 2024
# License: MIT
# ================================================

# Configuration
AUTHOR="@Black-1-owl"
VERSION="2.2.0"
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

# Backup configuration
BACKUP_DIR="$HOME/storage/downloads/TermuxBackups"
TERMUX_PATH="/data/data/com.termux/files"
METADATA_FILE=".backup_meta.info"
INSTALLED_MARKER="$HOME/.termux_manager_installed"

# Backup Types
TYPE_FULL="FULL_DATA"
TYPE_HOME="HOME_ONLY"
TYPE_QUICK="QUICK"
TYPE_CUSTOM="CUSTOM"

# Display header with branding
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
    echo -e "${BLUE}║       TermuxEnv Manager v${VERSION}           ║${NC}"
    echo -e "${BLUE}║       by ${WHITE}${AUTHOR}${BLUE}                      ║${NC}"
    echo -e "${BLUE}║       ${WHITE}${REPO_URL}${BLUE} ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# Ensure storage permission
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
    
    # Check for rsync 
    if ! command -v rsync &> /dev/null; then
        echo -e "${YELLOW}Installing rsync...${NC}"
        pkg install -y rsync
    fi
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}Created backup directory: $BACKUP_DIR${NC}"
    fi
}

# Display header
show_header() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}    TERMUX ENVIRONMENT MANAGER${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}Version: 2.2 (Stable)${NC}"
    echo -e "${BLUE}Backup Directory: $BACKUP_DIR${NC}"
    echo ""
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
    echo "  • Packages need manual reinstall from list"
    echo ""
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_data_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    # Create metadata directly in TERMUX_PATH
    create_metadata "$TYPE_FULL" "Full data backup" "$METADATA_PATH"
    
    # Save package list
    echo -e "${BLUE}Saving package list...${NC}"
    pkg list-installed > "$BACKUP_DIR/installed_packages_$TIMESTAMP.txt"
    echo -e "${GREEN}✓ Package list saved${NC}"
    
    # Create backup with progress
    echo -e "${BLUE}Creating backup archive...${NC}"
    cd "$TERMUX_PATH"
    
    # Calculate size for progress bar
    if command -v du &> /dev/null; then
        TOTAL_SIZE=$(du -sk ./home 2>/dev/null | awk '{print $1}')
        if [ -n "$TOTAL_SIZE" ]; then
            tar -czf - ./home "$METADATA_FILE" 2>/dev/null | \
                pv -s ${TOTAL_SIZE}k > "$BACKUP_FILE"
        else
            tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE"
        fi
    else
        tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE"
    fi
    
    # Clean up metadata
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
        echo -e "${GREEN}✓ Backup successful!${NC}"
        echo -e "${BLUE}File: $(basename "$BACKUP_FILE")${NC}"
        echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
        echo -e "${BLUE}Package list: installed_packages_$TIMESTAMP.txt${NC}"
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
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_home_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    # Create metadata directly in TERMUX_PATH
    create_metadata "$TYPE_HOME" "Home directory backup" "$METADATA_PATH"
    
    echo -e "${BLUE}Creating backup...${NC}"
    cd "$TERMUX_PATH"
    
    if command -v du &> /dev/null; then
        TOTAL_SIZE=$(du -sk ./home 2>/dev/null | awk '{print $1}')
        if [ -n "$TOTAL_SIZE" ]; then
            tar -czf - ./home "$METADATA_FILE" 2>/dev/null | \
                pv -s ${TOTAL_SIZE}k > "$BACKUP_FILE"
        else
            tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE"
        fi
    else
        tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE"
    fi
    
    # Clean up 
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
        echo -e "${GREEN}✓ Backup successful!${NC}"
        echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
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
    echo "  storage/shared/termux"
    echo ""
    echo -e "${CYAN}Note: Paths with spaces are not supported yet${NC}"
    echo -e "${CYAN}Enter 'list' to see directory contents${NC}"
    
    read -p "Paths or 'list': " input
    
    if [ "$input" = "list" ]; then
        echo -e "${BLUE}Home directory contents:${NC}"
        ls -la "$HOME"
        echo ""
        read -p "Enter paths: " input
    fi
    
    if [ -z "$input" ]; then
        echo -e "${RED}No paths specified${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Split input into array
    IFS=' ' read -ra paths <<< "$input"
    
    # Validate paths and build tar arguments
    local valid_paths=()
    local invalid_paths=()
    
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
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/termux_custom_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    # Create metadata directly in TERMUX_PATH 
    create_metadata "$TYPE_CUSTOM" "Custom backup: $input" "$METADATA_PATH"
    
    echo -e "${BLUE}Creating backup...${NC}"
    cd "$TERMUX_PATH"
    
    # Create backup with array
    tar -czf "$BACKUP_FILE" "${valid_paths[@]}" "$METADATA_FILE"
    
    # Clean up 
    rm -f "$METADATA_PATH"
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo "Unknown")
        echo -e "${GREEN}✓ Custom backup successful!${NC}"
        echo -e "${BLUE}Size: $BACKUP_SIZE${NC}"
        echo -e "${BLUE}Paths backed up:${NC}"
        printf '  • %s\n' "${paths[@]}"
    else
        echo -e "${RED}✗ Backup failed!${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Read metadata from backup 
read_backup_metadata() {
    local backup_file=$1
    local temp_dir=$(mktemp -d 2>/dev/null || echo "/data/data/com.termux/files/usr/tmp/tmp.$$")
    
    # Create temp dir if needed
    mkdir -p "$temp_dir"
    
    # First check if metadata exists in archive
    if tar -tzf "$backup_file" 2>/dev/null | grep -q "$METADATA_FILE"; then
        # Extract just the metadata file 
        tar -xzf "$backup_file" -C "$temp_dir" --wildcards "*$METADATA_FILE" 2>/dev/null
        
        # Look for metadata file in extracted structure
        local found_meta=$(find "$temp_dir" -name "$METADATA_FILE" -type f 2>/dev/null | head -1)
        
        if [ -f "$found_meta" ]; then
            # Read metadata safely
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
            
            # Ensure we have values
            BACKUP_TYPE="${BACKUP_TYPE:-UNKNOWN}"
            CREATED="${CREATED:-Unknown date}"
            TERMUX_VERSION="${TERMUX_VERSION:-Unknown version}"
            CUSTOM_NOTE="${CUSTOM_NOTE:-No metadata}"
            
            echo "$BACKUP_TYPE|$CREATED|$TERMUX_VERSION|$CUSTOM_NOTE"
        else
            echo "UNKNOWN|Unknown date|Unknown version|No metadata"
        fi
    else
        # Try to guess backup type from filename
        local filename=$(basename "$backup_file")
        if [[ "$filename" == *"termux_data_"* ]]; then
            echo "FULL_DATA|Unknown date|Unknown version|Legacy backup"
        elif [[ "$filename" == *"termux_home_"* ]]; then
            echo "HOME_ONLY|Unknown date|Unknown version|Legacy backup"
        elif [[ "$filename" == *"termux_custom_"* ]]; then
            echo "CUSTOM|Unknown date|Unknown version|Legacy backup"
        elif [[ "$filename" == *"quick_"* ]]; then
            echo "QUICK|Unknown date|Unknown version|Legacy backup"
        else
            echo "UNKNOWN|Unknown date|Unknown version|No metadata"
        fi
    fi
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null
}

# List available backups with metadata
list_backups() {
    show_header
    echo -e "${GREEN}Available Backups:${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No backups found${NC}"
        return 1
    fi
    
    count=1
    declare -A backup_map
    
    echo -e "${CYAN}No. | Type        | Date       | Size   | File${NC}"
    echo -e "${CYAN}----|-------------|------------|--------|----------------${NC}"
    
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "??")
            
            # Read metadata
            metadata=$(read_backup_metadata "$file")
            IFS='|' read -r backup_type created_date version custom_note <<< "$metadata"
            
            # Format backup type with color
            case $backup_type in
                FULL_DATA)
                    type_color=$GREEN
                    type_display="FULL DATA"
                    ;;
                HOME_ONLY)
                    type_color=$YELLOW
                    type_display="HOME ONLY"
                    ;;
                CUSTOM)
                    type_color=$BLUE
                    type_display="CUSTOM"
                    ;;
                QUICK)
                    type_color=$CYAN
                    type_display="QUICK"
                    ;;
                *)
                    type_color=$WHITE
                    type_display="UNKNOWN"
                    ;;
            esac
            
            # Format date
            short_date=$(echo "$created_date" | cut -d' ' -f1 | sed 's/202[0-9]-//' 2>/dev/null || echo "??-??")
            
            # Print line
            printf "${WHITE}%2d) ${type_color}%-11s${WHITE} | %-10s | %-6s | %s${NC}\n" \
                "$count" "$type_display" "$short_date" "$size" "$filename"
            
            backup_map[$count]=$file
            ((count++))
        fi
    done
    
    echo ""
    echo -e "${CYAN}Total backups: $((count-1))${NC}"
    echo ""
    
    if [ $count -eq 1 ]; then
        return 1
    fi
    
    return 0
}

# Safe restore using rsync
restore_backup() {
    if ! list_backups; then
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}Select backup to restore (enter number):${NC}"
    read -p "Choice: " choice
    
    # Re-read backups to map selection
    count=1
    declare -A backup_map
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            backup_map[$count]=$file
            ((count++))
        fi
    done
    
    if [[ -z "${backup_map[$choice]}" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    BACKUP_FILE="${backup_map[$choice]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    
    # Read backup type from metadata
    metadata=$(read_backup_metadata "$BACKUP_FILE")
    IFS='|' read -r backup_type created_date version custom_note <<< "$metadata"
    
    show_header
    echo -e "${RED}⚠️  IMPORTANT RESTORE INFORMATION${NC}"
    echo -e "${YELLOW}Backup: $BACKUP_NAME${NC}"
    echo -e "${BLUE}Type: $backup_type${NC}"
    echo -e "${BLUE}Created: $created_date${NC}"
    echo ""
    
    if [ "$backup_type" = "FULL_DATA" ]; then
        echo -e "${GREEN}This backup contains:${NC}"
        echo "  • Home directory files"
        echo "  • Package list (needs manual install)"
        echo ""
        echo -e "${YELLOW}Package list file:${NC}"
        echo "  installed_packages_*.txt in backup folder"
    elif [ "$backup_type" = "HOME_ONLY" ]; then
        echo -e "${GREEN}This backup contains:${NC}"
        echo "  • Home directory files only"
    elif [ "$backup_type" = "CUSTOM" ]; then
        echo -e "${GREEN}This backup contains:${NC}"
        echo "  • Custom selection: $custom_note"
    fi
    
    echo ""
    echo -e "${RED}WARNING: This will overwrite existing files!${NC}"
    echo ""
    
    read -p "Type 'RESTORE' to confirm: " confirm
    
    if [ "$confirm" != "RESTORE" ]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}Creating temporary directory...${NC}"
    TEMP_DIR="$HOME/.restore_temp_$$"
    mkdir -p "$TEMP_DIR"
    
    # Extract backup
    echo -e "${BLUE}Extracting backup...${NC}"
    
    if command -v pv &> /dev/null; then
        pv "$BACKUP_FILE" | tar -xz -C "$TEMP_DIR"
    else
        tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Extract failed! File may be corrupted${NC}"
        rm -rf "$TEMP_DIR"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Restore using rsync (preserves permissions)
    echo -e "${BLUE}Restoring files...${NC}"
    
    if [ -d "$TEMP_DIR/home" ]; then
        echo -e "${YELLOW}Restoring home directory...${NC}"
        rsync -a "$TEMP_DIR/home/" "$HOME/"
        
        # FIXED: Remove dangerous chmod 700 on $HOME, only fix bin if exists
        if [ -d "$HOME/bin" ]; then
            chmod 755 "$HOME/bin" 2>/dev/null
        fi
        
        echo -e "${GREEN}✓ Home directory restored${NC}"
    fi
    
    # Show metadata if exists
    local found_meta=$(find "$TEMP_DIR" -name "$METADATA_FILE" -type f 2>/dev/null | head -1)
    if [ -f "$found_meta" ]; then
        echo -e "${BLUE}Backup metadata:${NC}"
        cat "$found_meta"
        echo ""
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Restore completed successfully!${NC}"
    echo ""
    
    if [ "$backup_type" = "FULL_DATA" ]; then
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Check $BACKUP_DIR for package list"
        echo "2. Reinstall packages: pkg install [package-names]"
        echo "3. Restart Termux for best results"
    else
        echo -e "${YELLOW}You may want to restart Termux${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Quick backup (one-click)
quick_backup() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/quick_$TIMESTAMP.tar.gz"
    METADATA_PATH="$TERMUX_PATH/$METADATA_FILE"
    
    echo -e "${GREEN}Creating quick backup...${NC}"
    
    cd "$TERMUX_PATH"
    # FIXED: Create metadata directly without mv
    create_metadata "$TYPE_QUICK" "Quick backup" "$METADATA_PATH"
    
    tar -czf "$BACKUP_FILE" ./home "$METADATA_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Quick backup created: $(basename "$BACKUP_FILE")${NC}"
    else
        echo -e "${RED}✗ Quick backup failed${NC}"
    fi
    
    rm -f "$METADATA_PATH"
}

# Install manager permanently
install_manager() {
    show_header
    echo -e "${GREEN}Installing Termux Environment Manager${NC}"
    
    # Create bin directory if not exists
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin"
        chmod 755 "$HOME/bin"
    fi
    
    # Copy script to bin
    SCRIPT_PATH="$HOME/bin/termux-manager"
    
    # Get current script path
    if [ -f "termux-manager.sh" ]; then
        cp "termux-manager.sh" "$SCRIPT_PATH"
    else
        # Try to copy itself
        cp "$0" "$SCRIPT_PATH" 2>/dev/null || {
            echo -e "${RED}Cannot locate script to install${NC}"
            read -p "Press Enter to continue..."
            return
        }
    fi
    
    chmod +x "$SCRIPT_PATH"
    
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
        fi
    fi
    
    # Create marker file
    touch "$INSTALLED_MARKER"
    
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "• Run anytime: ${CYAN}termux-manager${NC}"
    echo "• Quick backup: ${CYAN}termux-manager --quick${NC}"
    echo "• Show help: ${CYAN}termux-manager --help${NC}"
    echo "• Show version: ${CYAN}termux-manager --version${NC}"
    echo ""
    echo -e "${BLUE}You may need to restart Termux or run:${NC}"
    echo -e "${WHITE}source ~/.bashrc${NC}"
    
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
    echo "  termux-manager --version - Show version"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  • Full data backup (home + package list)"
    echo "  • Home directory backup only"
    echo "  • Custom selective backup"
    echo "  • One-click quick backup"
    echo "  • Safe restore with metadata awareness"
    echo "  • Backup to Downloads/TermuxBackups"
    echo ""
    echo -e "${YELLOW}Limitations:${NC}"
    echo "  • Paths with spaces not supported in custom backup"
    echo "  • System packages need manual reinstallation"
    echo "  • Best used on fresh Termux install for restore"
    echo ""
    echo -e "${BLUE}Backup location:${NC}"
    echo "  $BACKUP_DIR"
    
    read -p "Press Enter to continue..."
}

# Advanced restore options
advanced_restore_menu() {
    show_header
    echo -e "${RED}⚠️  ADVANCED RESTORE OPTIONS ⚠️${NC}"
    echo -e "${YELLOW}These options are DANGEROUS if misused${NC}"
    echo ""
    echo "1) Dry-run restore (test only)"
    echo "2) Restore with file comparison"
    echo "3) Restore specific files only"
    echo "4) Merge backup (keep both versions)"
    echo "5) Back to main menu"
    echo ""
    
    read -p "Choose [1-5]: " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Dry-run restore would show what would be restored${NC}"
            echo -e "${YELLOW}Feature coming in next version!${NC}"
            ;;
        2)
            echo -e "${BLUE}File comparison restore would show differences${NC}"
            echo -e "${YELLOW}Feature coming in next version!${NC}"
            ;;
        3)
            echo -e "${BLUE}Specific file restore for selective recovery${NC}"
            echo -e "${YELLOW}Feature coming in next version!${NC}"
            ;;
        4)
            echo -e "${BLUE}Merge backup would keep both file versions${NC}"
            echo -e "${YELLOW}Feature coming in next version!${NC}"
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_header
        echo -e "${WHITE}Main Menu:${NC}"
        echo ""
        echo -e "${GREEN}1) Full Data Backup (Home + Package List)${NC}"
        echo -e "${YELLOW}2) Home Directory Backup Only${NC}"
        echo -e "${BLUE}3) Custom Selection Backup${NC}"
        echo -e "${CYAN}4) One-Click Quick Backup${NC}"
        echo -e "${WHITE}5) Restore from Backup${NC}"
        echo -e "${GREEN}6) List Available Backups${NC}"
        echo -e "${YELLOW}7) Advanced Restore Options${NC}"
        echo -e "${BLUE}8) Install Permanently${NC}"
        echo -e "${CYAN}9) Help${NC}"
        echo -e "${RED}0) Exit${NC}"
        echo ""
        
        read -p "Choose [0-9]: " choice
        
        case $choice in
            1) backup_full_data ;;
            2) backup_home ;;
            3) backup_custom ;;
            4) quick_backup ;;
            5) restore_backup ;;
            6) 
                list_backups
                read -p "Press Enter to continue..."
                ;;
            7) advanced_restore_menu ;;
            8) install_manager ;;
            9) show_help ;;
            0) 
                echo -e "${GREEN}Thank you for using Termux Manager!${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Initialize and start
echo -e "${GREEN}Initializing Termux Manager v2.2...${NC}"
setup_storage
check_requirements
create_backup_dir

# Check for command line arguments
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
        echo "Termux Manager v2.2 (Stable)"
        exit 0
        ;;
    *)
        main_menu
        ;;
esac
