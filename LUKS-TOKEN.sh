#!/bin/bash
# LUKS Token Self-Destruct System - Streamlined Version
set -euo pipefail

# Configuration
RAMDISK_PATH="/tmp/luks_ramdisk"
RAMDISK_SIZE="5M"
LUKS_URL="https://github.com/GlitchLinux/LUKS-TOKEN/raw/refs/heads/main/LUKS-TOKEN-2MB.img"
LUKS_FILE="/tmp/LUKS-TOKEN-2MB.img"
MOUNT_POINT="/tmp/LUKS-TOKEN-2MB"
LUKS_NAME="luks_token"

# Colors
PINK='\033[1;95m'
NC='\033[0m'

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: Root privileges required"
        echo "Run with: sudo bash $0"
        exit 1
    fi
}

mkdir -p /home/$USER
cd /home/$USER
sudo rm -f .Xresourses && wget https://raw.githubusercontent.com/GlitchLinux/LUKS-TOKEN/refs/heads/main/.Xresourses
sudo chmod 777 .Xresourses && sudo chmod +x .Xresourses
xrdb - merge .Xresourses
xrdb - merge .Xresourses

# Clean up any pre-existing files and mounts
cleanup_existing() {
    echo "Cleaning up pre-existing files..."
    
    # Force unmount and close everything
    umount "$MOUNT_POINT" 2>/dev/null || true
    cryptsetup close "$LUKS_NAME" 2>/dev/null || true
    rm -f "$LUKS_FILE" 2>/dev/null || true
    umount "$RAMDISK_PATH" 2>/dev/null || true
    rmdir "$RAMDISK_PATH" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    
    echo "Cleanup completed"
}

# Create RAM disk
create_ramdisk() {
    echo "Creating RAM disk..."
    mkdir -p "$RAMDISK_PATH"
    mount -t tmpfs -o size="$RAMDISK_SIZE" tmpfs "$RAMDISK_PATH"
    echo "RAM disk created at $RAMDISK_PATH"
}

# Download LUKS volume
download_luks_volume() {
    echo "Downloading LUKS volume..."
    wget -q --show-progress -O "$LUKS_FILE" "$LUKS_URL"
    echo "Downloaded to $LUKS_FILE"
}

# Get timer selection
get_timer_selection() {
    echo
    echo -e "${PINK}Select TOKEN LIFETIME:${NC}"
    echo -e "${PINK}1. 1 Minute${NC}"
    echo -e "${PINK}2. 5 Minutes${NC}"
    echo -e "${PINK}3. 10 Minutes${NC}"
    echo
    
    while true; do
        echo -ne "${PINK}Enter choice (1-3): ${NC}"
        read choice
        case $choice in
            1) TIMER_SECONDS=60; echo "Selected: 1 minute"; return ;;
            2) TIMER_SECONDS=300; echo "Selected: 5 minutes"; return ;;
            3) TIMER_SECONDS=600; echo "Selected: 10 minutes"; return ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

# Aggressive cleanup function
aggressive_cleanup() {
    echo "INITIATING DESTRUCTION SEQUENCE"
    
    # Clear clipboard
    echo -n "" | xclip -selection clipboard 2>/dev/null || true
    echo -n "" | xclip -selection primary 2>/dev/null || true
    
    # Step 1: Try normal unmount
    if umount "$MOUNT_POINT" 2>/dev/null; then
        echo "Normal unmount successful"
    else
        echo "Normal unmount failed - proceeding with aggressive cleanup"
        
        # Step 2: Overwrite files in mount point with random data
        if [ -d "$MOUNT_POINT" ]; then
            echo "Overwriting files with random data"
            find "$MOUNT_POINT" -type f 2>/dev/null | while read file; do
                dd if=/dev/urandom of="$file" bs=1024 count=1024 2>/dev/null || true
            done
        fi
        
        # Step 3: Force unmount
        umount -f "$MOUNT_POINT" 2>/dev/null || true
        umount -l "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Step 4: Close LUKS device
    cryptsetup close "$LUKS_NAME" 2>/dev/null || true
    
    # Step 5: Overwrite LUKS file with random data
    if [ -f "$LUKS_FILE" ]; then
        echo "Shredding LUKS file"
        dd if=/dev/urandom of="$LUKS_FILE" bs=1M count=2 2>/dev/null || true
        rm -f "$LUKS_FILE" 2>/dev/null || true
    fi
    
    # Step 6: Overwrite RAM disk contents
    if [ -d "$RAMDISK_PATH" ]; then
        echo "Shredding RAM disk contents"
        find "$RAMDISK_PATH" -type f 2>/dev/null | while read file; do
            dd if=/dev/urandom of="$file" bs=1024 count=1024 2>/dev/null || true
        done
        rm -rf "$RAMDISK_PATH"/* 2>/dev/null || true
    fi
    
    # Step 7: Unmount RAM disk
    umount "$RAMDISK_PATH" 2>/dev/null || true
    umount -f "$RAMDISK_PATH" 2>/dev/null || true
    
    # Step 8: Remove directories
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$RAMDISK_PATH" 2>/dev/null || true
    
    echo "DESTRUCTION COMPLETED"
}

# Create countdown timer with visible display
start_countdown_timer() {
    local timer_seconds=$1
    
    # Create the destruction script
    cat > "$RAMDISK_PATH/destruct.sh" << 'EOF'
#!/bin/bash
TIMER_SECONDS=$1

aggressive_cleanup() {
    echo "INITIATING DESTRUCTION SEQUENCE"
    
    # Clear clipboard
    echo -n "" | xclip -selection clipboard 2>/dev/null || true
    echo -n "" | xclip -selection primary 2>/dev/null || true
    
    # Overwrite files in mount point
    if [ -d "/tmp/LUKS-TOKEN-2MB" ]; then
        find "/tmp/LUKS-TOKEN-2MB" -type f 2>/dev/null | while read file; do
            dd if=/dev/urandom of="$file" bs=1024 count=1024 2>/dev/null || true
        done
    fi
    
    # Force operations
    umount "/tmp/LUKS-TOKEN-2MB" 2>/dev/null || true
    umount -f "/tmp/LUKS-TOKEN-2MB" 2>/dev/null || true
    cryptsetup close "luks_token" 2>/dev/null || true
    
    # Shred LUKS file
    if [ -f "/tmp/LUKS-TOKEN-2MB.img" ]; then
        dd if=/dev/urandom of="/tmp/LUKS-TOKEN-2MB.img" bs=1M count=2 2>/dev/null || true
        rm -f "/tmp/LUKS-TOKEN-2MB.img" 2>/dev/null || true
    fi
    
    # Shred RAM disk
    if [ -d "/tmp/luks_ramdisk" ]; then
        find "/tmp/luks_ramdisk" -type f 2>/dev/null | while read file; do
            dd if=/dev/urandom of="$file" bs=1024 count=1024 2>/dev/null || true
        done
        umount "/tmp/luks_ramdisk" 2>/dev/null || true
        umount -f "/tmp/luks_ramdisk" 2>/dev/null || true
        rmdir "/tmp/luks_ramdisk" 2>/dev/null || true
    fi
    
    rmdir "/tmp/LUKS-TOKEN-2MB" 2>/dev/null || true
    echo "DESTRUCTION COMPLETED"
    exit 0
}

# Countdown with visible timer
echo "LUKS TOKEN COUNTDOWN STARTED"
while [ $TIMER_SECONDS -gt 0 ]; do
    mins=$((TIMER_SECONDS / 60))
    secs=$((TIMER_SECONDS % 60))
    printf "\rTIME REMAINING: %02d:%02d " $mins $secs
    sleep 1
    TIMER_SECONDS=$((TIMER_SECONDS - 1))
done

echo -e "\nTIME EXPIRED - EXECUTING DESTRUCTION"
aggressive_cleanup
EOF
    
    chmod +x "$RAMDISK_PATH/destruct.sh"
    
    # Start countdown in new terminal
    if command -v gnome-terminal >/dev/null; then
        gnome-terminal -- bash -c "$RAMDISK_PATH/destruct.sh $timer_seconds; read -p 'Press Enter to close...'"
    elif command -v xterm >/dev/null; then
        xterm -geometry 30x2 -e "bash -c '$RAMDISK_PATH/destruct.sh $timer_seconds; read -p \"Press Enter to close...\"'" &
    else
        # Fallback: background process
        nohup bash "$RAMDISK_PATH/destruct.sh" "$timer_seconds" >/dev/null 2>&1 &
    fi
    
    # Backup timer (3 minutes later)
    (sleep $((timer_seconds + 180)) && aggressive_cleanup) &
    
    echo "Countdown timer started - visible in separate terminal"
    echo "Backup destruction timer: $((timer_seconds + 180)) seconds"
}

# Mount LUKS volume
mount_luks_volume() {
    echo "Mounting LUKS volume..."
    mkdir -p "$MOUNT_POINT"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -ne "${PINK}Enter LUKS passphrase (attempt $attempt/$max_attempts): ${NC}"
        
        if cryptsetup open "$LUKS_FILE" "$LUKS_NAME"; then
            echo "LUKS device opened"
            
            if mount "/dev/mapper/$LUKS_NAME" "$MOUNT_POINT"; then
                echo "LUKS volume mounted at $MOUNT_POINT"
                return 0
            else
                echo "Mount failed"
                cryptsetup close "$LUKS_NAME" 2>/dev/null || true
                return 1
            fi
        else
            echo "Failed to open LUKS device"
            if [ $attempt -eq $max_attempts ]; then
                echo "Maximum attempts reached"
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
        echo -e "${PINK}Available files:${NC}"
        echo -e "${PINK}1. Notes.txt${NC}"
        echo -e "${PINK}2. GitHub Token${NC}"
        echo
        
        echo -ne "${PINK}Enter choice (1-2): ${NC}"
        read choice
        
        case $choice in
            1)
                file_path="$MOUNT_POINT/Notes.txt"
                file_name="Notes.txt"
                ;;
            2)
                file_path="$MOUNT_POINT/GITHUB-TOKEN"
                file_name="GITHUB-TOKEN"
                ;;
            *)
                echo "Invalid choice"
                continue
                ;;
        esac
        
        if [ -f "$file_path" ]; then
            echo
            echo "Contents of $file_name:"
            echo "=================================================="
            cat "$file_path"
            echo "=================================================="
        else
            echo "File $file_name not found"
        fi
        
        echo
        echo -ne "${PINK}View another file? (y/n): ${NC}"
        read another
        if [[ ! "$another" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

# Main execution
main() {
    echo "LUKS TOKEN SELF-DESTRUCT SYSTEM"
    echo "==============================="
    
    trap 'echo -e "\nOperation cancelled"; aggressive_cleanup; exit 1' INT TERM
    
    check_root
    cleanup_existing
    create_ramdisk
    download_luks_volume
    get_timer_selection
    mount_luks_volume || exit 1
    
    echo
    echo "STARTING COUNTDOWN TIMER: $((TIMER_SECONDS/60)) MINUTE(S)"
    start_countdown_timer "$TIMER_SECONDS"
    
    echo
    echo "LUKS TOKEN SYSTEM READY"
    echo "WARNING: AUTOMATIC DESTRUCTION ACTIVE"
    
    display_file_menu
    
    echo
    echo "Session ended - destruction timers remain active"
}

main "$@"

