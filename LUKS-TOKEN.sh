
#!/bin/bash
# LUKS Token Self-Destruct System - Bash Version
# Downloads and mounts a LUKS volume to a self-destructing RAM disk

set -euo pipefail

# Configuration
RAMDISK_PATH="/tmp/luks_ramdisk"
RAMDISK_SIZE="5M"
LUKS_URL="https://github.com/GlitchLinux/LUKS-TOKEN/raw/refs/heads/main/LUKS-TOKEN-2MB.img"
LUKS_FILE="/tmp/LUKS-TOKEN-2MB.img"
MOUNT_POINT="/tmp/LUKS-TOKEN-2MB"
LUKS_NAME="luks_token"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges for LUKS operations!"
        echo "Please run with: sudo bash $0"
        exit 1
    fi
}

# Clean up any pre-existing files and mounts
cleanup_existing() {
    print_info "Cleaning up any pre-existing files and mounts..."
    
    # Unmount existing LUKS mount point if it exists
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        print_warning "Unmounting existing LUKS mount at $MOUNT_POINT"
        umount "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Close existing LUKS device if it exists
    if [ -e "/dev/mapper/$LUKS_NAME" ]; then
        print_warning "Closing existing LUKS device $LUKS_NAME"
        cryptsetup close "$LUKS_NAME" 2>/dev/null || true
    fi
    
    # Remove existing LUKS file
    if [ -f "$LUKS_FILE" ]; then
        print_warning "Removing existing LUKS file $LUKS_FILE"
        rm -f "$LUKS_FILE" 2>/dev/null || true
    fi
    
    # Unmount existing RAM disk if it exists
    if mountpoint -q "$RAMDISK_PATH" 2>/dev/null; then
        print_warning "Unmounting existing RAM disk at $RAMDISK_PATH"
        umount "$RAMDISK_PATH" 2>/dev/null || true
    fi
    
    # Remove RAM disk directory if it exists
    if [ -d "$RAMDISK_PATH" ]; then
        rmdir "$RAMDISK_PATH" 2>/dev/null || true
    fi
    
    # Remove mount point directory if it exists
    if [ -d "$MOUNT_POINT" ]; then
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    print_status "Cleanup completed"
}

# Create RAM disk
create_ramdisk() {
    print_info "Creating ${RAMDISK_SIZE} RAM disk at ${RAMDISK_PATH}..."
    
    # Create mount point
    mkdir -p "$RAMDISK_PATH"
    
    # Mount tmpfs RAM disk
    if mount -t tmpfs -o size="$RAMDISK_SIZE" tmpfs "$RAMDISK_PATH"; then
        print_status "RAM disk created successfully at $RAMDISK_PATH"
        return 0
    else
        print_error "Failed to create RAM disk"
        return 1
    fi
}

# Download LUKS volume
download_luks_volume() {
    print_info "Downloading LUKS volume from $LUKS_URL..."
    
    if wget --progress=bar:force -O "$LUKS_FILE" "$LUKS_URL" 2>&1; then
        print_status "Downloaded LUKS volume to $LUKS_FILE"
        return 0
    else
        print_error "Failed to download LUKS volume"
        return 1
    fi
}

# Get timer selection from user
get_timer_selection() {
    echo
    print_info "Select TOKEN LIFETIME:"
    echo "1. 1 Minute"
    echo "2. 5 Minutes"
    echo "3. 10 Minutes"
    echo
    
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                TIMER_SECONDS=60
                print_info "Selected: 1 minute"
                return 0
                ;;
            2)
                TIMER_SECONDS=300
                print_info "Selected: 5 minutes"
                return 0
                ;;
            3)
                TIMER_SECONDS=600
                print_info "Selected: 10 minutes"
                return 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Create self-destruct script
create_destruct_script() {
    local timer_seconds=$1
    local failsafe_timer=$((timer_seconds + 180))  # 3 minutes later
    local destruct_script="$RAMDISK_PATH/dd-destruct.sh"
    
    cat > "$destruct_script" << EOF
#!/bin/bash
# Self-destruct script for LUKS token RAM disk
# Primary destruction timer: ${timer_seconds} seconds
# Failsafe timer: ${failsafe_timer} seconds

RAMDISK="$RAMDISK_PATH"
LUKS_FILE="$LUKS_FILE"
MOUNT_POINT="$MOUNT_POINT"
LUKS_NAME="$LUKS_NAME"

# Function to perform cleanup
cleanup_all() {
    echo "🔥 Initiating self-destruct sequence..."
    
    # Unmount LUKS if mounted
    if mountpoint -q "\$MOUNT_POINT" 2>/dev/null; then
        umount "\$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Close LUKS device if open
    if [ -e "/dev/mapper/\$LUKS_NAME" ]; then
        cryptsetup close "\$LUKS_NAME" 2>/dev/null || true
    fi
    
    # Shred LUKS file
    if [ -f "\$LUKS_FILE" ]; then
        dd if=/dev/urandom of="\$LUKS_FILE" bs=1M count=2 2>/dev/null || true
        rm -f "\$LUKS_FILE" 2>/dev/null || true
    fi
    
    # Shred RAM disk contents
    find "\$RAMDISK" -type f -exec dd if=/dev/urandom of={} bs=1024 count=1024 \\; 2>/dev/null || true
    
    # Unmount RAM disk
    umount "\$RAMDISK" 2>/dev/null || true
    rmdir "\$RAMDISK" 2>/dev/null || true
    
    echo "💥 Self-destruct completed"
}

# Set process name to something unsuspicious
exec -a "kworker/u4:0" bash -c "
# Primary timer
(sleep ${timer_seconds} && cleanup_all) &
echo '⏰ Primary self-destruct timer set for ${timer_seconds} seconds'

# Failsafe timer (3 minutes later)
(sleep ${failsafe_timer} && cleanup_all) &
echo '🛡️ Failsafe self-destruct timer set for ${failsafe_timer} seconds'

# Keep script running
wait
"
EOF
    
    chmod +x "$destruct_script"
    print_status "Self-destruct script created at $destruct_script"
    echo "$destruct_script"
}

# Start self-destruct timer
start_destruct_timer() {
    local script_path=$1
    
    # Start as nohup background process with misleading name
    nohup bash "$script_path" > /dev/null 2>&1 &
    disown
    
    print_status "Self-destruct timers activated and running in background"
}

# Mount LUKS volume
mount_luks_volume() {
    print_info "Mounting LUKS volume..."
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo
        print_info "Enter LUKS passphrase (attempt $attempt/$max_attempts):"
        
        if cryptsetup open "$LUKS_FILE" "$LUKS_NAME"; then
            print_status "LUKS device opened successfully"
            
            # Mount the filesystem
            if mount "/dev/mapper/$LUKS_NAME" "$MOUNT_POINT"; then
                print_status "LUKS volume mounted at $MOUNT_POINT"
                return 0
            else
                print_error "Failed to mount LUKS filesystem"
                cryptsetup close "$LUKS_NAME" 2>/dev/null || true
                return 1
            fi
        else
            print_error "Failed to open LUKS device"
            if [ $attempt -eq $max_attempts ]; then
                print_error "Maximum attempts reached. Exiting."
                return 1
            fi
        fi
        
        ((attempt++))
    done
}

# Display file menu
display_file_menu() {
    while true; do
        echo
        print_info "Available files:"
        echo "1. Notes.txt"
        echo "2. GitHub Token"
        echo
        
        read -p "Enter your choice (1-2): " choice
        
        case $choice in
            1)
                local file_path="$MOUNT_POINT/Notes.txt"
                local file_name="Notes.txt"
                ;;
            2)
                local file_path="$MOUNT_POINT/GITHUB-TOKEN"
                local file_name="GITHUB-TOKEN"
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                continue
                ;;
        esac
        
        # Display file content
        if [ -f "$file_path" ]; then
            echo
            print_info "Contents of $file_name:"
            echo "=================================================="
            cat "$file_path"
            echo "=================================================="
        else
            print_error "File $file_name not found in LUKS volume"
        fi
        
        echo
        read -p "View another file? (y/n): " another
        if [[ ! "$another" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

# Main execution
main() {
    echo "🔐 LUKS Token Self-Destruct System"
    echo "========================================"
    
    # Trap for cleanup on exit
    trap 'echo -e "\n\n🛑 Operation cancelled by user"' INT TERM
    
    # Check root privileges
    check_root
    
    # Clean up any pre-existing files and mounts
    cleanup_existing
    
    # Create RAM disk
    create_ramdisk || exit 1
    
    # Download LUKS volume
    download_luks_volume || exit 1
    
    # Get timer selection
    get_timer_selection
    timer_seconds=$TIMER_SECONDS
    
    # Create destruct script
    script_path=$(create_destruct_script "$timer_seconds")
    
    # Mount LUKS volume
    mount_luks_volume || exit 1
    
    # Start destruct timer
    start_destruct_timer "$script_path"
    
    echo
    print_status "LUKS token system ready! Timer: $((timer_seconds/60)) minute(s)"
    print_warning "RAM disk will self-destruct automatically!"
    
    # Display file menu
    display_file_menu
    
    echo
    print_info "Session ended. Self-destruct timers remain active."
}

# Run main function
main "$@"

