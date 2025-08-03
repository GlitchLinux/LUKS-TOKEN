#!/usr/bin/env python3
"""
LUKS Token Self-Destruct System
Downloads and mounts a LUKS volume to a self-destructing RAM disk
"""

import os
import sys
import subprocess
import urllib.request
import time
import getpass
import tempfile
from pathlib import Path

class LUKSTokenSystem:
    def __init__(self):
        self.ramdisk_path = "/tmp/luks_ramdisk"
        self.ramdisk_size = "5M"
        self.luks_url = "https://github.com/GlitchLinux/LUKS-TOKEN/raw/refs/heads/main/LUKS-TOKEN-2MB.img"
        self.luks_file = "/tmp/LUKS-TOKEN-2MB.img"
        self.mount_point = "/tmp/LUKS-TOKEN-2MB"
        self.loop_device = None
        
    def check_root(self):
        """Check if running as root (required for LUKS operations)"""
        if os.geteuid() != 0:
            print("❌ This script requires root privileges for LUKS operations!")
            print("Please run with: sudo python3 script.py")
            sys.exit(1)
    
    def create_ramdisk(self):
        """Create RAM disk in /tmp"""
        print(f"🚀 Creating {self.ramdisk_size} RAM disk at {self.ramdisk_path}...")
        
        try:
            # Create mount point
            os.makedirs(self.ramdisk_path, exist_ok=True)
            
            # Mount tmpfs RAM disk
            subprocess.run([
                "mount", "-t", "tmpfs", "-o", f"size={self.ramdisk_size}",
                "tmpfs", self.ramdisk_path
            ], check=True)
            
            print(f"✅ RAM disk created successfully at {self.ramdisk_path}")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to create RAM disk: {e}")
            return False
    
    def download_luks_volume(self):
        """Download LUKS volume to /tmp"""
        print(f"📥 Downloading LUKS volume from {self.luks_url}...")
        
        try:
            # Download with progress indication
            def progress_hook(block_num, block_size, total_size):
                downloaded = block_num * block_size
                if total_size > 0:
                    percent = (downloaded / total_size) * 100
                    print(f"\r📊 Download progress: {percent:.1f}%", end="", flush=True)
            
            urllib.request.urlretrieve(self.luks_url, self.luks_file, progress_hook)
            print(f"\n✅ Downloaded LUKS volume to {self.luks_file}")
            return True
            
        except Exception as e:
            print(f"\n❌ Failed to download LUKS volume: {e}")
            return False
    
    def get_timer_selection(self):
        """Prompt user to select token lifetime"""
        print("\n⏰ Select TOKEN LIFETIME:")
        print("1. 1 Minute")
        print("2. 5 Minutes") 
        print("3. 10 Minutes")
        
        while True:
            try:
                choice = input("\nEnter your choice (1-3): ").strip()
                timer_map = {
                    "1": (60, "1 minute"),
                    "2": (300, "5 minutes"), 
                    "3": (600, "10 minutes")
                }
                
                if choice in timer_map:
                    seconds, description = timer_map[choice]
                    print(f"⏱️ Selected: {description}")
                    return seconds
                else:
                    print("❌ Invalid choice. Please enter 1, 2, or 3.")
                    
            except KeyboardInterrupt:
                print("\n\n🛑 Operation cancelled by user")
                sys.exit(1)
    
    def create_destruct_script(self, timer_seconds):
        """Create self-destruct script on RAM disk"""
        destruct_script = f"{self.ramdisk_path}/dd-destruct.sh"
        failsafe_timer = timer_seconds + 180  # 3 minutes later
        
        script_content = f"""#!/bin/bash
# Self-destruct script for LUKS token RAM disk
# Primary destruction timer: {timer_seconds} seconds
# Failsafe timer: {failsafe_timer} seconds

RAMDISK="{self.ramdisk_path}"
LUKS_FILE="{self.luks_file}"
MOUNT_POINT="{self.mount_point}"

# Function to perform cleanup
cleanup_all() {{
    echo "🔥 Initiating self-destruct sequence..."
    
    # Unmount LUKS if mounted
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount "$MOUNT_POINT" 2>/dev/null
    fi
    
    # Close LUKS device if open
    if [ -e /dev/mapper/luks_token ]; then
        cryptsetup close luks_token 2>/dev/null
    fi
    
    # Shred LUKS file
    if [ -f "$LUKS_FILE" ]; then
        dd if=/dev/urandom of="$LUKS_FILE" bs=1M count=2 2>/dev/null
        rm -f "$LUKS_FILE" 2>/dev/null
    fi
    
    # Shred RAM disk contents
    find "$RAMDISK" -type f -exec dd if=/dev/urandom of={{}} bs=1024 count=1024 \\; 2>/dev/null
    
    # Unmount RAM disk
    umount "$RAMDISK" 2>/dev/null
    rmdir "$RAMDISK" 2>/dev/null
    
    echo "💥 Self-destruct completed"
}}

# Primary timer
(sleep {timer_seconds} && cleanup_all) &
echo "⏰ Primary self-destruct timer set for {timer_seconds} seconds"

# Failsafe timer (3 minutes later)
(sleep {failsafe_timer} && cleanup_all) &
echo "🛡️ Failsafe self-destruct timer set for {failsafe_timer} seconds"
"""
        
        try:
            with open(destruct_script, 'w') as f:
                f.write(script_content)
            
            os.chmod(destruct_script, 0o755)
            print(f"🔥 Self-destruct script created at {destruct_script}")
            return destruct_script
            
        except Exception as e:
            print(f"❌ Failed to create destruct script: {e}")
            return None
    
    def start_destruct_timer(self, script_path):
        """Start the self-destruct timer as background process"""
        try:
            # Start as nohup background process with misleading name
            cmd = f"nohup bash {script_path} > /dev/null 2>&1 &"
            subprocess.Popen(cmd, shell=True, preexec_fn=os.setsid)
            print("⏳ Self-destruct timers activated and running in background")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start destruct timer: {e}")
            return False
    
    def mount_luks_volume(self):
        """Mount LUKS volume after passphrase verification"""
        print(f"\n🔐 Mounting LUKS volume...")
        
        # Create mount point
        os.makedirs(self.mount_point, exist_ok=True)
        
        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                # Get passphrase
                passphrase = getpass.getpass(f"🔑 Enter LUKS passphrase (attempt {attempt + 1}/{max_attempts}): ")
                
                # Open LUKS device
                proc = subprocess.Popen([
                    "cryptsetup", "open", self.luks_file, "luks_token"
                ], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                
                stdout, stderr = proc.communicate(input=passphrase.encode())
                
                if proc.returncode == 0:
                    print("✅ LUKS device opened successfully")
                    
                    # Mount the filesystem
                    subprocess.run([
                        "mount", "/dev/mapper/luks_token", self.mount_point
                    ], check=True)
                    
                    print(f"✅ LUKS volume mounted at {self.mount_point}")
                    return True
                else:
                    print(f"❌ Failed to open LUKS device: {stderr.decode()}")
                    if attempt == max_attempts - 1:
                        print("🚫 Maximum attempts reached. Exiting.")
                        return False
                    
            except subprocess.CalledProcessError as e:
                print(f"❌ Mount failed: {e}")
                return False
            except KeyboardInterrupt:
                print("\n\n🛑 Operation cancelled by user")
                return False
    
    def display_file_menu(self):
        """Display file selection menu"""
        print("\n📁 Available files:")
        print("1. Notes.txt")
        print("2. GitHub Token")
        
        while True:
            try:
                choice = input("\nEnter your choice (1-2): ").strip()
                
                if choice == "1":
                    file_path = f"{self.mount_point}/Notes.txt"
                    file_name = "Notes.txt"
                elif choice == "2":
                    file_path = f"{self.mount_point}/GitHub Token"
                    file_name = "GitHub Token"
                else:
                    print("❌ Invalid choice. Please enter 1 or 2.")
                    continue
                
                # Display file content
                try:
                    if os.path.exists(file_path):
                        print(f"\n📄 Contents of {file_name}:")
                        print("=" * 50)
                        with open(file_path, 'r') as f:
                            content = f.read()
                            print(content)
                        print("=" * 50)
                    else:
                        print(f"❌ File {file_name} not found in LUKS volume")
                        
                except Exception as e:
                    print(f"❌ Error reading file: {e}")
                
                # Ask if user wants to view another file
                another = input("\nView another file? (y/n): ").strip().lower()
                if another != 'y':
                    break
                    
            except KeyboardInterrupt:
                print("\n\n🛑 Operation cancelled by user")
                break
    
    def cleanup_on_exit(self):
        """Manual cleanup if needed"""
        try:
            if os.path.ismount(self.mount_point):
                subprocess.run(["umount", self.mount_point], check=False)
            
            subprocess.run(["cryptsetup", "close", "luks_token"], check=False)
            
            if os.path.exists(self.luks_file):
                os.remove(self.luks_file)
                
        except Exception:
            pass  # Ignore errors during cleanup
    
    def run(self):
        """Main execution flow"""
        print("🔐 LUKS Token Self-Destruct System")
        print("=" * 40)
        
        try:
            # Check root privileges
            self.check_root()
            
            # Create RAM disk
            if not self.create_ramdisk():
                return False
            
            # Download LUKS volume
            if not self.download_luks_volume():
                return False
            
            # Get timer selection
            timer_seconds = self.get_timer_selection()
            
            # Create destruct script
            script_path = self.create_destruct_script(timer_seconds)
            if not script_path:
                return False
            
            # Mount LUKS volume
            if not self.mount_luks_volume():
                return False
            
            # Start destruct timer
            if not self.start_destruct_timer(script_path):
                return False
            
            print(f"\n🎯 LUKS token system ready! Timer: {timer_seconds//60} minute(s)")
            print("⚠️  RAM disk will self-destruct automatically!")
            
            # Display file menu
            self.display_file_menu()
            
            print("\n👋 Session ended. Self-destruct timers remain active.")
            return True
            
        except KeyboardInterrupt:
            print("\n\n🛑 Operation cancelled by user")
            return False
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            return False
        finally:
            # Note: We don't cleanup here since timers should handle it
            pass

def main():
    """Main entry point"""
    system = LUKSTokenSystem()
    success = system.run()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
