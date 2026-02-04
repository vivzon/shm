#!/bin/bash

# SHM Cron Job Manager Script
# Usage: shm-cron-manager.sh <username> <action> [args]

USERNAME=$1
ACTION=$2

if [ -z "$USERNAME" ] || [ -z "$ACTION" ]; then
    echo "Usage: shm-cron-manager.sh <username> <list|add|remove> [args]"
    exit 1
fi

case "$ACTION" in
    list)
        crontab -u "$USERNAME" -l 2>/dev/null || echo ""
        ;;
    add)
        SCHEDULE=$3
        COMMAND=$4
        
        if [ -z "$SCHEDULE" ] || [ -z "$COMMAND" ]; then
            echo "Error: Schedule and command are required."
            exit 1
        fi
        
        # Add to current crontab
        (crontab -u "$USERNAME" -l 2>/dev/null; echo "$SCHEDULE $COMMAND") | crontab -u "$USERNAME" -
        echo "Cron job added for $USERNAME."
        ;;
    remove)
        LINE_NUM=$3
        if [ -z "$LINE_NUM" ]; then
            echo "Error: Line number is required for removal."
            exit 1
        fi
        # Remove specific line
        crontab -u "$USERNAME" -l | sed "${LINE_NUM}d" | crontab -u "$USERNAME" -
        echo "Cron job at line $LINE_NUM removed."
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac
