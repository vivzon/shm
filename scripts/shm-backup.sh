#!/bin/bash

# SHM Backup Script
# Usage: shm-backup.sh <username> <backup_dir>

USERNAME=$1
BACKUP_DIR=$2

if [ -z "$USERNAME" ] || [ -z "$BACKUP_DIR" ]; then
    echo "Usage: shm-backup.sh <username> <backup_dir>"
    exit 1
fi

DATE=$(date +%Y%m%d_%H%M%S)
USER_HOME="/home/$USERNAME"
BACKUP_FILE="$BACKUP_DIR/${USERNAME}_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting backup for $USERNAME..."

# 1. Backup public_html
tar -czf "$BACKUP_FILE" -C "$USER_HOME" public_html

# 2. Backup Databases
# We need to find all databases belonging to this user.
# For simplicity, we assume we have a list or we backup all DBS starting with username_
mysql -N -e "SHOW DATABASES LIKE '${USERNAME}_%';" | while read db; do
    echo "Backing up database: $db"
    mysqldump "$db" >> "$BACKUP_DIR/${USERNAME}_dbs_$DATE.sql"
done

# 3. Compress everything
if [ -f "$BACKUP_DIR/${USERNAME}_dbs_$DATE.sql" ]; then
    tar -rvf "$BACKUP_FILE" -C "$BACKUP_DIR" "${USERNAME}_dbs_$DATE.sql"
    rm "$BACKUP_DIR/${USERNAME}_dbs_$DATE.sql"
fi

echo "Backup completed: $BACKUP_FILE"
