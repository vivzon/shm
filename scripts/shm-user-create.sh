#!/bin/bash

# SHM User Creation Script
# Usage: shm-user-create.sh <username> <password> <email>

USERNAME=$1
PASSWORD=$2
EMAIL=$3

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Username and password are required."
    exit 1
fi

# Create system user
if id "$USERNAME" &>/dev/null; then
    echo "Error: User $USERNAME already exists."
    exit 1
fi

useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Create website directory structure
ADMIN_DIR="/home/$USERNAME/public_html"
LOGS_DIR="/home/$USERNAME/logs"

mkdir -p "$ADMIN_DIR"
mkdir -p "$LOGS_DIR"

# Set permissions
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
chmod 755 "/home/$USERNAME"
chmod 750 "$ADMIN_DIR"

# Create a default index.html
cat <<EOF > "$ADMIN_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $USERNAME's site</title>
</head>
<body>
    <h1>Success! SHM has successfully setup this account.</h1>
</body>
</html>
EOF

chown "$USERNAME:$USERNAME" "$ADMIN_DIR/index.html"

echo "User $USERNAME created successfully."
