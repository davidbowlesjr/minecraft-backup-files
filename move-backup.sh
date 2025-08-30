#!/bin/bash

# Load configuration from environment file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/backup-config.env" ]; then
    source "$SCRIPT_DIR/backup-config.env"
else
    echo "Error: backup-config.env file not found in $SCRIPT_DIR"
    exit 1
fi

# Function to check if NAS is mounted
is_nas_mounted() {
    mount | grep -q "$NAS_DESTINATION_DIR"
    return $?
}

# Check if NAS is already mounted
NAS_MOUNTED_BY_SCRIPT=false
if ! is_nas_mounted; then
    echo "NAS share not mounted. Attempting to mount..."
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$NAS_MOUNT_ATTEMPT_MESSAGE$(printf \\r)"
    sudo mount -t cifs "$NAS_SHARE" "$NAS_DESTINATION_DIR" -o credentials="$NAS_CREDENTIALS_FILE"
    
    if [ $? -ne 0 ]; then
        echo "Failed to mount NAS share"
        screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$NAS_MOUNT_FAILED_MESSAGE$(printf \\r)"
        exit 1
    fi
    echo "NAS share mounted successfully"
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$NAS_MOUNT_SUCCESS_MESSAGE$(printf \\r)"
    NAS_MOUNTED_BY_SCRIPT=true
else
    echo "NAS share is already mounted"
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$NAS_ALREADY_MOUNTED_MESSAGE$(printf \\r)"
fi

# Find the latest file in the backup directory
echo "Finding latest backup file..."
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$FINDING_BACKUP_MESSAGE$(printf \\r)"
LATEST_FILE=$(find "$SOURCE_BACKUP_DIR" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

if [ -z "$LATEST_FILE" ]; then
    echo "No files found in backup directory"
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$NO_BACKUPS_FOUND_MESSAGE$(printf \\r)"
    if [ "$NAS_MOUNTED_BY_SCRIPT" = true ]; then
        sudo umount "$NAS_DESTINATION_DIR"
    fi
    exit 1
fi

# Get just the filename without path for cleaner output
FILENAME=$(basename "$LATEST_FILE")

# Move the latest file
echo "Moving latest backup file: $FILENAME"
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$MOVING_BACKUP_MESSAGE: $FILENAME$(printf \\r)"
sudo mv "$LATEST_FILE" "$NAS_DESTINATION_DIR"

if [ $? -eq 0 ]; then
    echo "Successfully moved $FILENAME to $NAS_DESTINATION_DIR"
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$MOVE_SUCCESS_MESSAGE$(printf \\r)"

    # Remove all files from source directory after successful move
    echo "Cleaning up source directory..."
    sudo rm -f "$SOURCE_BACKUP_DIR"/*
    CLEANUP_COUNT=$(find "$SOURCE_BACKUP_DIR" -maxdepth 1 -type f | wc -l)
    
    if [ "$CLEANUP_COUNT" -eq 0 ]; then
        echo "Successfully removed all other backups from source directory"
        screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$CLEANUP_SUCCESS_MESSAGE$(printf \\r)"
    else
        echo "Warning: Failed to remove some files from source directory"
        screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$CLEANUP_WARNING_MESSAGE$(printf \\r)"
    fi
else
    echo "Failed to move backup file"
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$MOVE_FAILED_MESSAGE$(printf \\r)"
    if [ "$NAS_MOUNTED_BY_SCRIPT" = true ]; then
        sudo umount "$NAS_DESTINATION_DIR"
    fi
    exit 1
fi
 
exit 0

