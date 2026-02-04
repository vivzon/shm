#!/bin/bash

# SHM Database Creation Script
# Usage: shm-db-create.sh <username> <dbname> <dbuser> <dbpass>

DB_NAME=$1
DB_USER=$2
DB_PASS=$3

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "Error: Database name, user, and password are required."
    exit 1
fi

# Create Database and User
# Using root credentials from /root/.my.cnf if available
mysql -e "CREATE DATABASE $DB_NAME;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "Database $DB_NAME and user $DB_USER created successfully."
