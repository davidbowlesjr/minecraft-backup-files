#!/bin/bash

# Load configuration from environment file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/backup-config.env" ]; then
    source "$SCRIPT_DIR/backup-config.env"
else
    echo "Error: backup-config.env file not found in $SCRIPT_DIR"
    exit 1
fi

# Send start notification
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$START_MESSAGE$(printf \\r)"

# Check available disk space (minimum disk space in GB converted to KB)
AVAILABLE_SPACE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
MIN_SPACE=$((MIN_DISK_SPACE_GB * 1024 * 1024))  # Convert GB to KB

if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE" ]; then
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$ERROR_DISK_SPACE$(printf \\r)"
    exit 1
fi

# Create backup
mkdir "$TMP_WORLD_DIR"
cp -r "$WORLD_DIR" "$TMP_WORLD_DIR" 

# Fix permissions on copied files to ensure we can delete them
chmod -R u+w "$TMP_WORLD_DIR/"

cd "$BACKUP_DIR" && zip -r "$BACKUP_FILE_PREFIX-$(date "$DATE_FORMAT").zip" "$TMP_WORLD_DIR/"

# Clean up temporary directory
rm -rf "$TMP_WORLD_DIR/" 

# Check if backup succeeded
if [ $? -ne 0 ]; then
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$ERROR_BACKUP$(printf \\r)"
    exit 1
fi

# Send completion notification
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "$COMPLETE_MESSAGE$(printf \\r)"

exit 0
