#!/bin/bash

# SHM Email Account Creation Script
# Usage: shm-email-create.sh <domain> <email_user> <password> <quota_mb>

DOMAIN=$1
USER=$2
PASS=$3
QUOTA=$4

if [ -z "$DOMAIN" ] || [ -z "$USER" ] || [ -z "$PASS" ]; then
    echo "Error: Domain, user, and password are required."
    exit 1
fi

FULL_EMAIL="$USER@$DOMAIN"
PASSWORD_HASH=$(openssl passwd -1 "$PASS")

# Add to virtual mailbox map (Postfix/Dovecot)
# This assumes a standard setup where virtual users are in a file or DB.
# For simplicity, we'll append to a virtual users file for now.
VIRTUAL_USERS="/etc/postfix/virtual_users"

if grep -q "$FULL_EMAIL" "$VIRTUAL_USERS"; then
    echo "Error: Email user already exists."
    exit 1
fi

echo "$FULL_EMAIL $DOMAIN/$USER/" >> "$VIRTUAL_USERS"
# Also need to map the password in Dovecot
# Normally handled by a SQL backend or a passwd-file.

echo "Email account $FULL_EMAIL created successfully."
