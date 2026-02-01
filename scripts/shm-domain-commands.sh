#!/bin/bash

################################################################################
# SHM PANEL - DOMAIN MANAGEMENT IN shm-manage CLI
# ============================================================================
# This file should be added to the shm-manage script
# It handles all domain-related operations
#
# Usage:
#   shm-manage add-domain <domain> <username> [php_version]
#   shm-manage remove-domain <domain>
#   shm-manage list-domains [username]
#   shm-manage convert-htaccess <domain_path>
#
################################################################################

# ============================================================================
# ADD DOMAIN COMMAND
# ============================================================================

cmd_add_domain() {
    local domain="$1"
    local username="$2"
    local php_version="${3:-8.2}"

    if [[ -z "$domain" || -z "$username" ]]; then
        echo "Usage: shm-manage add-domain <domain> <username> [php_version]"
        return 1
    fi

    # Call the domain creation script
    if [[ -x "/usr/local/bin/add-domain" ]]; then
        /usr/local/bin/add-domain "$domain" "$username" "$php_version"
        return $?
    else
        echo "Error: add-domain script not found"
        return 1
    fi
}

# ============================================================================
# REMOVE DOMAIN COMMAND
# ============================================================================

cmd_remove_domain() {
    local domain="$1"
    local force="${2:-no}"

    if [[ -z "$domain" ]]; then
        echo "Usage: shm-manage remove-domain <domain> [--force]"
        return 1
    fi

    local clients_base="/var/www/clients"
    local domain_path="$clients_base/$domain"
    local nginx_sites_available="/etc/nginx/sites-available"
    local nginx_sites_enabled="/etc/nginx/sites-enabled"
    local php_fpm_pool_dir="/etc/php"

    echo "[INFO] Removing domain: $domain"

    # Safety check
    if [[ ! -d "$domain_path" ]]; then
        echo "[ERROR] Domain directory not found: $domain_path"
        return 1
    fi

    # Confirm deletion (unless --force)
    if [[ "$force" != "--force" ]]; then
        read -p "Are you sure you want to delete $domain? (type 'yes' to confirm): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            return 1
        fi
    fi

    # Remove Nginx configuration
    echo "[INFO] Removing Nginx configuration..."
    rm -f "$nginx_sites_enabled/$domain.conf"
    rm -f "$nginx_sites_available/$domain.conf"

    # Remove PHP-FPM pool (all versions)
    echo "[INFO] Removing PHP-FPM pools..."
    find "$php_fpm_pool_dir" -name "$domain.conf" -delete 2>/dev/null || true

    # Remove domain directory
    echo "[INFO] Removing domain files..."
    if [[ -d "$domain_path" ]]; then
        # Create backup before deletion
        local backup_file="/var/backups/shm-panel-$domain-$(date +%s).tar.gz"
        tar -czf "$backup_file" "$domain_path" 2>/dev/null && \
            echo "[INFO] Backup created: $backup_file"
        
        # Remove domain directory
        rm -rf "$domain_path"
    fi

    # Reload Nginx
    echo "[INFO] Reloading Nginx..."
    if nginx -t && systemctl reload nginx; then
        echo "[SUCCESS] Domain removed successfully"
        echo "[INFO] Backup saved to: $backup_file"
        return 0
    else
        echo "[ERROR] Failed to reload Nginx"
        return 1
    fi
}

# ============================================================================
# LIST DOMAINS COMMAND
# ============================================================================

cmd_list_domains() {
    local username="${1:-}"
    local clients_base="/var/www/clients"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                      HOSTED DOMAINS                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ -z "$username" ]]; then
        # List all domains
        if [[ ! -d "$clients_base" ]]; then
            echo "No domains found."
            return 0
        fi

        local count=0
        find "$clients_base" -maxdepth 2 -name "nginx" -type d | while read -r dir; do
            local domain_path=$(dirname "$dir")
            local domain=$(basename "$domain_path")
            local owner=$(stat -c '%U' "$domain_path" 2>/dev/null || echo "unknown")
            
            echo "Domain:     $domain"
            echo "Owner:      $owner"
            echo "Path:       $domain_path"
            echo "Status:     $(test -L /etc/nginx/sites-enabled/$domain.conf && echo "Enabled" || echo "Disabled")"
            echo ""
            
            count=$((count + 1))
        done

        echo "Total: $count domain(s)"
    else
        # List domains for specific user
        if [[ ! -d "$clients_base" ]]; then
            echo "No domains found for user: $username"
            return 0
        fi

        local count=0
        find "$clients_base" -maxdepth 2 -name "nginx" -type d | while read -r dir; do
            local domain_path=$(dirname "$dir")
            local owner=$(stat -c '%U' "$domain_path" 2>/dev/null || echo "")
            
            if [[ "$owner" == "$username" ]]; then
                local domain=$(basename "$domain_path")
                echo "Domain:     $domain"
                echo "Path:       $domain_path"
                echo "Status:     $(test -L /etc/nginx/sites-enabled/$domain.conf && echo "Enabled" || echo "Disabled")"
                echo ""
                
                count=$((count + 1))
            fi
        done

        echo "Total: $count domain(s) for user '$username'"
    fi
}

# ============================================================================
# CONVERT HTACCESS COMMAND
# ============================================================================

cmd_convert_htaccess() {
    local domain_path="$1"

    if [[ -z "$domain_path" ]]; then
        echo "Usage: shm-manage convert-htaccess <domain_path>"
        return 1
    fi

    if [[ ! -d "$domain_path" ]]; then
        echo "[ERROR] Domain path not found: $domain_path"
        return 1
    fi

    # Call the converter script
    if [[ -x "/usr/local/bin/htaccess-converter" ]]; then
        /usr/local/bin/htaccess-converter "$domain_path"
        return $?
    else
        echo "[ERROR] htaccess-converter script not found"
        return 1
    fi
}

# ============================================================================
# ENABLE/DISABLE DOMAIN
# ============================================================================

cmd_enable_domain() {
    local domain="$1"
    local nginx_sites_available="/etc/nginx/sites-available"
    local nginx_sites_enabled="/etc/nginx/sites-enabled"

    if [[ -z "$domain" ]]; then
        echo "Usage: shm-manage enable-domain <domain>"
        return 1
    fi

    if [[ ! -f "$nginx_sites_available/$domain.conf" ]]; then
        echo "[ERROR] Domain configuration not found: $nginx_sites_available/$domain.conf"
        return 1
    fi

    echo "[INFO] Enabling domain: $domain"
    
    # Create symlink
    ln -sf "$nginx_sites_available/$domain.conf" "$nginx_sites_enabled/$domain.conf"

    # Reload Nginx
    if nginx -t && systemctl reload nginx; then
        echo "[SUCCESS] Domain enabled: $domain"
        return 0
    else
        echo "[ERROR] Failed to enable domain"
        rm -f "$nginx_sites_enabled/$domain.conf"
        return 1
    fi
}

cmd_disable_domain() {
    local domain="$1"
    local nginx_sites_enabled="/etc/nginx/sites-enabled"

    if [[ -z "$domain" ]]; then
        echo "Usage: shm-manage disable-domain <domain>"
        return 1
    fi

    if [[ ! -L "$nginx_sites_enabled/$domain.conf" ]]; then
        echo "[WARN] Domain symlink not found: $nginx_sites_enabled/$domain.conf"
        return 1
    fi

    echo "[INFO] Disabling domain: $domain"
    
    # Remove symlink
    rm -f "$nginx_sites_enabled/$domain.conf"

    # Reload Nginx
    if nginx -t && systemctl reload nginx; then
        echo "[SUCCESS] Domain disabled: $domain"
        return 0
    else
        echo "[ERROR] Failed to disable domain"
        return 1
    fi
}

# ============================================================================
# DOMAIN INFO COMMAND
# ============================================================================

cmd_domain_info() {
    local domain="$1"
    local clients_base="/var/www/clients"
    local domain_path="$clients_base/$domain"

    if [[ -z "$domain" ]]; then
        echo "Usage: shm-manage domain-info <domain>"
        return 1
    fi

    if [[ ! -d "$domain_path" ]]; then
        echo "[ERROR] Domain not found: $domain"
        return 1
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    DOMAIN INFORMATION                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    echo "Domain:           $domain"
    echo "Path:             $domain_path"
    echo "Owner:            $(stat -c '%U:%G' "$domain_path")"
    echo "Created:          $(stat -c '%y' "$domain_path" | cut -d' ' -f1)"
    echo ""

    echo "Web Root:         $domain_path/public_html"
    echo "  Size:           $(du -sh "$domain_path/public_html" 2>/dev/null | cut -f1)"
    echo "  Files:          $(find "$domain_path/public_html" -type f | wc -l)"
    echo ""

    echo "Logs:             $domain_path/logs"
    echo "  Access Log:     $(wc -l < "$domain_path/logs/access.log" 2>/dev/null || echo "0") lines"
    echo "  Error Log:      $(wc -l < "$domain_path/logs/error.log" 2>/dev/null || echo "0") lines"
    echo ""

    echo "Nginx:            /etc/nginx/sites-available/$domain.conf"
    echo "  Status:         $(test -L /etc/nginx/sites-enabled/$domain.conf && echo "Enabled" || echo "Disabled")"
    echo ""

    echo ".htaccess:        $domain_path/public_html/.htaccess"
    echo "  Size:           $(stat -c '%s' "$domain_path/public_html/.htaccess" 2>/dev/null || echo "0") bytes"
    echo ""

    echo "Rewrites:         $domain_path/nginx/rewrites.conf"
    echo "  Size:           $(stat -c '%s' "$domain_path/nginx/rewrites.conf" 2>/dev/null || echo "0") bytes"
    echo ""
}

# ============================================================================
# COMMAND DISPATCHER (add to main shm-manage)
# ============================================================================

# In the main shm-manage script, add these cases to the command handler:
#
# "add-domain")
#     cmd_add_domain "$@"
#     ;;
# "remove-domain")
#     cmd_remove_domain "${2:-}" "${3:-}"
#     ;;
# "list-domains")
#     cmd_list_domains "${2:-}"
#     ;;
# "convert-htaccess")
#     cmd_convert_htaccess "${2:-}"
#     ;;
# "enable-domain")
#     cmd_enable_domain "${2:-}"
#     ;;
# "disable-domain")
#     cmd_disable_domain "${2:-}"
#     ;;
# "domain-info")
#     cmd_domain_info "${2:-}"
#     ;;
