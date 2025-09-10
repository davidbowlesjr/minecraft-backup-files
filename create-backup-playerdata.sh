#!/bin/bash

# Load configuration from environment file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/backup-config.env" ]; then
    source "$SCRIPT_DIR/backup-config.env"
else
    echo "Error: backup-config.env file not found in $SCRIPT_DIR"
    exit 1
fi

# Player data specific settings
PLAYERDATA_DIR="/mnt/minestore/modded-server/world/playerdata"
TMP_PLAYERDATA_DIR="/mnt/minestore/autozip-minecraft-backups/tmp-playerdata"
PLAYERDATA_BACKUP_PREFIX="playerdata-backup"
PLAYERDATA_START_MESSAGE="Starting Player Data Backup"
PLAYERDATA_COMPLETE_MESSAGE="Finished Player Data Backup"
PLAYERDATA_ERROR_BACKUP="Player Data Backup Error - Check Console"
PLAYERDATA_ERROR_DISK_SPACE="Player Data Backup Error - Low Disk Space"

# Send start notification
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "say $PLAYERDATA_START_MESSAGE$(printf \\r)"

# Check available disk space (minimum disk space in GB converted to KB)
AVAILABLE_SPACE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
MIN_SPACE=$((MIN_DISK_SPACE_GB * 1024 * 1024))  # Convert GB to KB

if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE" ]; then
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "say $PLAYERDATA_ERROR_DISK_SPACE$(printf \\r)"
    curl -H "Content-Type: application/json" -X POST -d "{\"message\": \"$PLAYERDATA_ERROR_DISK_SPACE\"}" "localhost:8080"
    exit 1
fi

# Create playerdata backup
mkdir "$TMP_PLAYERDATA_DIR"
cp -r "$PLAYERDATA_DIR" "$TMP_PLAYERDATA_DIR" 

# Fix permissions on copied files to ensure we can delete them
chmod -R u+w "$TMP_PLAYERDATA_DIR/"

cd "$BACKUP_DIR" && zip -r "$PLAYERDATA_BACKUP_PREFIX-$(date "$DATE_FORMAT").zip" "$TMP_PLAYERDATA_DIR/"

# Clean up temporary directory
rm -rf "$TMP_PLAYERDATA_DIR/" 

# Check if backup succeeded
if [ $? -ne 0 ]; then
    screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "say $PLAYERDATA_ERROR_BACKUP$(printf \\r)"
    curl -H "Content-Type: application/json" -X POST -d "{\"message\": \"$PLAYERDATA_ERROR_BACKUP\"}" "localhost:8080"
    exit 1
fi

# Send completion notification
screen -S "$MINECRAFT_SCREEN_SESSION" -X stuff "say $PLAYERDATA_COMPLETE_MESSAGE$(printf \\r)"

exit 0
