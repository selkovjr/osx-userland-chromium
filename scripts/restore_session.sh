#!/bin/bash

# Session Recovery Script for Custom Chromium
# Helps recover and restore browser sessions after crashes or data loss

set -e

# Configuration
CHROMIUM_PROFILE_DIR="$HOME/Library/Application Support/Chromium"
BACKUP_DIR="$HOME/.chromium_session_backups"
DEFAULT_PROFILE="Default"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {backup|restore|list|clean|auto-backup}"
    echo
    echo "Commands:"
    echo "  backup           Create backup of current session"
    echo "  restore <file>   Restore session from backup file"
    echo "  list             List available session backups"
    echo "  clean            Remove old backup files"
    echo "  auto-backup      Set up automatic session backups"
    echo
    echo "Examples:"
    echo "  $0 backup"
    echo "  $0 restore session_20240101_120000"
    echo "  $0 list"
    echo
}

# Function to create session backup
backup_session() {
    echo_header "Creating Session Backup"
    
    PROFILE_DIR="$CHROMIUM_PROFILE_DIR/$DEFAULT_PROFILE"
    
    if [ ! -d "$PROFILE_DIR" ]; then
        echo_error "Chromium profile directory not found: $PROFILE_DIR"
        echo_error "Make sure Chromium has been run at least once"
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Generate timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="session_$TIMESTAMP"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    echo_info "Creating backup: $BACKUP_NAME"
    
    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    
    # Files to backup
    SESSION_FILES=(
        "Current Session"
        "Current Tabs"
        "Last Session"
        "Last Tabs"
        "Preferences"
        "Local State"
        "History"
        "Bookmarks"
        "Login Data"
        "Web Data"
    )
    
    # Copy session files
    for file in "${SESSION_FILES[@]}"; do
        if [ -f "$PROFILE_DIR/$file" ]; then
            cp "$PROFILE_DIR/$file" "$BACKUP_PATH/"
            echo_info "✅ Backed up: $file"
        else
            echo_warn "⚠️ File not found: $file"
        fi
    done
    
    # Copy Extensions directory if it exists
    if [ -d "$PROFILE_DIR/Extensions" ]; then
        cp -R "$PROFILE_DIR/Extensions" "$BACKUP_PATH/"
        echo_info "✅ Backed up: Extensions"
    fi
    
    # Create metadata file
    cat > "$BACKUP_PATH/backup_info.txt" << EOF
Backup created: $(date)
Chromium profile: $PROFILE_DIR
Backup script: $0
System: $(uname -a)
User: $(whoami)
EOF
    
    # Create a summary
    TAB_COUNT=$(grep -c "tab {" "$BACKUP_PATH/Current Session" 2>/dev/null || echo "unknown")
    BOOKMARK_COUNT=$(grep -c '"name":' "$BACKUP_PATH/Bookmarks" 2>/dev/null || echo "unknown")
    
    echo_info "✅ Session backup complete"
    echo_info "   Backup location: $BACKUP_PATH"
    echo_info "   Estimated tabs: $TAB_COUNT"
    echo_info "   Estimated bookmarks: $BOOKMARK_COUNT"
    echo_info "   Size: $(du -sh "$BACKUP_PATH" | cut -f1)"
}

# Function to restore session
restore_session() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        echo_error "Please specify a backup name"
        echo_info "Available backups:"
        list_backups
        exit 1
    fi
    
    echo_header "Restoring Session: $backup_name"
    
    BACKUP_PATH="$BACKUP_DIR/$backup_name"
    PROFILE_DIR="$CHROMIUM_PROFILE_DIR/$DEFAULT_PROFILE"
    
    if [ ! -d "$BACKUP_PATH" ]; then
        echo_error "Backup not found: $BACKUP_PATH"
        echo_info "Available backups:"
        list_backups
        exit 1
    fi
    
    if [ ! -d "$PROFILE_DIR" ]; then
        echo_warn "Profile directory doesn't exist, creating: $PROFILE_DIR"
        mkdir -p "$PROFILE_DIR"
    fi
    
    # Warn about overwriting current session
    if [ -f "$PROFILE_DIR/Current Session" ]; then
        echo_warn "This will overwrite your current session!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Restore cancelled"
            exit 0
        fi
        
        # Create automatic backup of current session
        echo_info "Creating backup of current session first..."
        backup_session
    fi
    
    # Stop Chromium if running
    if pgrep -f "Chromium" >/dev/null; then
        echo_warn "Chromium is currently running"
        read -p "Close Chromium and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Please close Chromium and press Enter to continue..."
            read
        else
            echo_info "Restore cancelled"
            exit 0
        fi
    fi
    
    # Restore files
    echo_info "Restoring session files..."
    
    for file in "$BACKUP_PATH"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            if [ "$filename" != "backup_info.txt" ]; then
                cp "$file" "$PROFILE_DIR/"
                echo_info "✅ Restored: $filename"
            fi
        elif [ -d "$file" ]; then
            dirname=$(basename "$file")
            cp -R "$file" "$PROFILE_DIR/"
            echo_info "✅ Restored: $dirname/"
        fi
    done
    
    echo_info "✅ Session restore complete"
    echo_info "You can now start Chromium to see your restored session"
    
    # Show backup info if available
    if [ -f "$BACKUP_PATH/backup_info.txt" ]; then
        echo_info "Backup information:"
        cat "$BACKUP_PATH/backup_info.txt" | sed 's/^/  /'
    fi
}

# Function to list backups
list_backups() {
    echo_header "Available Session Backups"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo_info "No backups found in $BACKUP_DIR"
        echo_info "Create a backup with: $0 backup"
        return
    fi
    
    echo_info "Backup location: $BACKUP_DIR"
    echo
    
    # List backups with details
    for backup in "$BACKUP_DIR"/session_*; do
        if [ -d "$backup" ]; then
            backup_name=$(basename "$backup")
            backup_date=$(echo "$backup_name" | sed 's/session_\([0-9]\{8\}\)_\([0-9]\{6\}\)/\1 \2/' | \
                         sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
            backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
            
            # Get tab count if available
            tab_count="unknown"
            if [ -f "$backup/Current Session" ]; then
                tab_count=$(grep -c "tab {" "$backup/Current Session" 2>/dev/null || echo "unknown")
            fi
            
            echo -e "  ${GREEN}$backup_name${NC}"
            echo "    Date: $backup_date"
            echo "    Size: $backup_size"
            echo "    Tabs: $tab_count"
            echo
        fi
    done
    
    echo_info "To restore a session: $0 restore <backup_name>"
}

# Function to clean old backups
clean_backups() {
    echo_header "Cleaning Old Backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo_info "No backup directory found"
        return
    fi
    
    # Find backups older than 30 days
    OLD_BACKUPS=$(find "$BACKUP_DIR" -name "session_*" -type d -mtime +30 2>/dev/null || true)
    
    if [ -z "$OLD_BACKUPS" ]; then
        echo_info "No old backups found (keeping backups newer than 30 days)"
        return
    fi
    
    echo_info "Found old backups (older than 30 days):"
    echo "$OLD_BACKUPS" | while read -r backup; do
        backup_name=$(basename "$backup")
        backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
        echo "  $backup_name ($backup_size)"
    done
    
    read -p "Delete these old backups? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$OLD_BACKUPS" | while read -r backup; do
            rm -rf "$backup"
            echo_info "✅ Deleted: $(basename "$backup")"
        done
        echo_info "✅ Old backups cleaned up"
    else
        echo_info "Cleanup cancelled"
    fi
}

# Function to set up automatic backups
setup_auto_backup() {
    echo_header "Setting Up Automatic Session Backups"
    
    CRON_COMMAND="0 */6 * * * $0 backup >/dev/null 2>&1"
    LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.chromium.session.backup.plist"
    
    echo_info "This will create automatic session backups every 6 hours"
    echo_info "Backups will be stored in: $BACKUP_DIR"
    echo
    
    read -p "Set up automatic backups? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Automatic backup setup cancelled"
        return
    fi
    
    # Create LaunchAgent plist for macOS
    echo_info "Creating LaunchAgent for automatic backups..."
    
    mkdir -p "$(dirname "$LAUNCHD_PLIST")"
    
    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.chromium.session.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>$0</string>
        <string>backup</string>
    </array>
    <key>StartInterval</key>
    <integer>21600</integer>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
    
    # Load the LaunchAgent
    launchctl load "$LAUNCHD_PLIST" 2>/dev/null || true
    
    echo_info "✅ Automatic backup configured"
    echo_info "   Frequency: Every 6 hours"
    echo_info "   Plist: $LAUNCHD_PLIST"
    echo_info "   To disable: launchctl unload \"$LAUNCHD_PLIST\""
    echo
    echo_info "Manual commands:"
    echo "  Create backup: $0 backup"
    echo "  List backups: $0 list"
    echo "  Restore: $0 restore <backup_name>"
}

# Main function
main() {
    case "${1:-}" in
        backup)
            backup_session
            ;;
        restore)
            restore_session "$2"
            ;;
        list)
            list_backups
            ;;
        clean)
            clean_backups
            ;;
        auto-backup)
            setup_auto_backup
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"