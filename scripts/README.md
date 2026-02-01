# SHM Panel - System Scripts

This directory contains utility scripts for managing and maintaining the SHM Panel.

## Maintenance Scripts
*(Run these from the project root)*

| Script | Purpose | Usage |
| :--- | :--- | :--- |
| `enable-ssl.sh` | Install/Renew SSL certificates | `sudo ./scripts/enable-ssl.sh` |
| `fix_webmail.sh` | Repair Webmail/Roundcube issues | `sudo ./scripts/fix_webmail.sh` |
| `update.sh` | Update SHM Panel to latest version | `sudo ./scripts/update.sh` |

## Core System Scripts
*(These are typically installed to `/usr/local/bin` by the installer)*

| Script | Purpose |
| :--- | :--- |
| `add-domain.sh` | Backend logic for creating domains |
| `shm-domain-commands.sh` | CLI integration for domain management |
| `shm-htaccess-watcher.sh` | Service to monitor .htaccess changes |
| `htaccess-converter.sh` | Converts Apache rules to Nginx |
| `install-domain-management.sh` | Standalone installer for domain tools |
