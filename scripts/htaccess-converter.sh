#!/bin/bash

################################################################################
# SHM PANEL - HTACCESS TO NGINX CONVERTER
# ============================================================================
# Purpose: Automatically convert Apache .htaccess rules to Nginx syntax
#
# Usage: htaccess-converter <domain_path>
#        htaccess-converter /var/www/clients/example.com
#
# Features:
#   - Parses .htaccess RewriteRule directives
#   - Converts to Nginx rewrite syntax
#   - Handles RewriteCond conditions
#   - Safe Nginx reload with validation
#   - Atomic file writes
#
# Author: SHM Panel Team
# Version: 1.0 Production
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DOMAIN_PATH="${1:-}"
HTACCESS_FILE="$DOMAIN_PATH/public_html/.htaccess"
REWRITES_CONF="$DOMAIN_PATH/nginx/rewrites.conf"
NGINX_BACKUP="$REWRITES_CONF.backup.$(date +%s)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_inputs() {
    if [[ -z "$DOMAIN_PATH" ]] || [[ ! -d "$DOMAIN_PATH" ]]; then
        log_error "Invalid domain path: $DOMAIN_PATH"
        exit 1
    fi

    if [[ ! -f "$HTACCESS_FILE" ]]; then
        log_warn ".htaccess not found: $HTACCESS_FILE"
        return 1
    fi

    if [[ ! -f "$REWRITES_CONF" ]]; then
        log_warn "rewrites.conf not found, will create: $REWRITES_CONF"
        return 1
    fi

    return 0
}

# ============================================================================
# HTACCESS PARSING & CONVERSION
# ============================================================================

convert_htaccess_to_nginx() {
    local htaccess="$1"
    local temp_output="/tmp/nginx-rewrites.$$.tmp"

    log_info "Reading .htaccess: $htaccess"

    # Create output file with header
    cat > "$temp_output" << 'NGINX_HEADER'
# ============================================================================
# SHM Panel - Auto-Generated Nginx Rewrites from .htaccess
# ============================================================================
# This file is auto-generated from .htaccess
# Last Updated: 
# Do NOT edit manually - changes will be overwritten
# ============================================================================

NGINX_HEADER

    # Add timestamp
    sed -i "s/Last Updated: /Last Updated: $(date '+%Y-%m-%d %H:%M:%S')/" "$temp_output"

    local in_rewrite_engine=0
    local current_cond=""
    local line_num=0

    # Read .htaccess line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Trim whitespace
        line=$(echo "$line" | xargs)

        # ====================================================================
        # REWRITE ENGINE ON/OFF
        # ====================================================================
        if [[ "$line" =~ ^RewriteEngine[[:space:]]+On ]]; then
            in_rewrite_engine=1
            echo "" >> "$temp_output"
            echo "# Rewrite Engine Enabled" >> "$temp_output"
            continue
        fi

        if [[ "$line" =~ ^RewriteEngine[[:space:]]+Off ]]; then
            in_rewrite_engine=0
            continue
        fi

        [[ $in_rewrite_engine -eq 0 ]] && continue

        # ====================================================================
        # REWRITE CONDITIONS
        # ====================================================================
        if [[ "$line" =~ ^RewriteCond[[:space:]]+(.*) ]]; then
            local cond="${BASH_REMATCH[1]}"
            
            # Parse condition format: %{REQUEST_FILENAME} !-f
            # Common patterns: !-f (not file), !-d (not dir), -f (is file), -d (is dir)
            
            if [[ "$cond" =~ ^%\{REQUEST_FILENAME\}[[:space:]]+!-f ]]; then
                current_cond="# Condition: File does not exist"
                echo "$current_cond" >> "$temp_output"
            elif [[ "$cond" =~ ^%\{REQUEST_FILENAME\}[[:space:]]+!-d ]]; then
                current_cond="# Condition: Directory does not exist"
                echo "$current_cond" >> "$temp_output"
            elif [[ "$cond" =~ ^%\{REQUEST_FILENAME\}[[:space:]]+-f ]]; then
                current_cond="# Condition: File exists"
                echo "$current_cond" >> "$temp_output"
            elif [[ "$cond" =~ ^%\{REQUEST_FILENAME\}[[:space:]]+-d ]]; then
                current_cond="# Condition: Directory exists"
                echo "$current_cond" >> "$temp_output"
            else
                log_warn "Unsupported RewriteCond at line $line_num: $line"
            fi
            continue
        fi

        # ====================================================================
        # REWRITE RULES
        # ====================================================================
        if [[ "$line" =~ ^RewriteRule[[:space:]]+(.*) ]]; then
            local rule="${BASH_REMATCH[1]}"
            
            # Extract pattern, target, and flags
            # Format: RewriteRule ^pattern/?$ target [flags]
            # Example: RewriteRule ^([a-zA-Z0-9_-]+)/?$ $1.php [QSA,L]
            
            if [[ "$rule" =~ ^\"?([^\"]+)\"?[[:space:]]+\"?([^\"]+)\"?[[:space:]]*\[?([^\]]*)\]? ]]; then
                local pattern="${BASH_REMATCH[1]}"
                local target="${BASH_REMATCH[2]}"
                local flags="${BASH_REMATCH[3]}"
                
                # Parse pattern and convert to Nginx syntax
                convert_rewrite_rule "$pattern" "$target" "$flags" "$temp_output"
            else
                log_warn "Could not parse RewriteRule at line $line_num: $line"
            fi
            continue
        fi

        # ====================================================================
        # FORCE HTTPS
        # ====================================================================
        if [[ "$line" =~ RewriteCond[[:space:]]+%\{HTTPS\}[[:space:]]+!=on ]] || \
           [[ "$line" =~ RewriteCond[[:space:]]+%\{SERVER_PORT\}[[:space:]]+!=443 ]]; then
            current_cond="# Force HTTPS detected"
            echo "$current_cond" >> "$temp_output"
            continue
        fi

    done < "$htaccess"

    # Add fallback rule to prevent admin panel exposure
    cat >> "$temp_output" << 'FALLBACK'

# ============================================================================
# SECURITY: Prevent admin panel exposure
# ============================================================================
location ~ ^/(admin|client|whm|landing)/ {
    return 444;
}

FALLBACK

    log_success "Conversion complete"
    echo "$temp_output"
}

# ============================================================================
# REWRITE RULE CONVERTER
# ============================================================================

convert_rewrite_rule() {
    local pattern="$1"
    local target="$2"
    local flags="$3"
    local output_file="$4"

    # Extract flags
    local last_flag=0
    local query_string=0
    [[ "$flags" =~ L ]] && last_flag=1
    [[ "$flags" =~ QSA ]] && query_string=1

    # Clean up pattern
    pattern=$(echo "$pattern" | sed 's/^\^//' | sed 's/\$$//')
    pattern=$(echo "$pattern" | sed 's/\/\?$//')  # Remove optional trailing slash

    # ====================================================================
    # PATTERN TYPE: File hiding (.php extension)
    # Pattern: ^([a-zA-Z0-9_-]+)/?$ -> $1.php
    # ====================================================================
    if [[ "$pattern" =~ ^\(\[a-zA-Z0-9_-\]\+\) ]] && [[ "$target" == '$1.php' ]]; then
        cat >> "$output_file" << 'RULE'

# Clean URL: Hide .php extension
# Example: /login -> login.php
rewrite ^/([a-zA-Z0-9_-]+)/?$ /$1.php last;
RULE
        return
    fi

    # ====================================================================
    # PATTERN TYPE: Deny specific files/extensions
    # Pattern: ^\.htaccess$ or \.env$
    # ====================================================================
    if [[ "$pattern" =~ ^\\\. ]]; then
        local filename=$(echo "$pattern" | sed 's/\\//g' | sed 's/\$//g')
        cat >> "$output_file" << RULE

# Block access to: $filename
location ~ $pattern {
    deny all;
    access_log off;
    log_not_found off;
}
RULE
        return
    fi

    # ====================================================================
    # PATTERN TYPE: Redirect HTTP to HTTPS
    # Target: https://%{HTTP_HOST}%{REQUEST_URI}
    # ====================================================================
    if [[ "$target" =~ ^https:// ]]; then
        cat >> "$output_file" << 'RULE'

# Force HTTPS
if ($scheme != "https") {
    return 301 https://$server_name$request_uri;
}
RULE
        return
    fi

    # ====================================================================
    # PATTERN TYPE: SEO-friendly URLs with query parameters
    # Pattern: ^products/([0-9]+)/(.*)$ -> products.php?id=$1&name=$2
    # ====================================================================
    if [[ "$target" =~ \$[0-9] ]]; then
        # Complex rewrite with capture groups
        local nginx_pattern=$(convert_regex_to_nginx "$pattern")
        local nginx_target=$(convert_target_to_nginx "$target")
        
        if [[ $query_string -eq 1 ]]; then
            cat >> "$output_file" << RULE

# SEO-friendly URL rewrite
rewrite $nginx_pattern $nginx_target last;
RULE
        else
            cat >> "$output_file" << RULE

# URL rewrite
rewrite $nginx_pattern $nginx_target;
RULE
        fi
        return
    fi

    # ====================================================================
    # PATTERN TYPE: Generic rewrite
    # ====================================================================
    if [[ -n "$pattern" && -n "$target" ]]; then
        cat >> "$output_file" << RULE

# Rewrite: $pattern -> $target
rewrite ^$pattern$ $target last;
RULE
        return
    fi

    log_warn "Could not convert rewrite rule: $pattern -> $target [$flags]"
}

# ============================================================================
# REGEX CONVERSION HELPERS
# ============================================================================

convert_regex_to_nginx() {
    local regex="$1"
    
    # Basic conversion: Apache regex -> Nginx regex
    # Remove trailing $ and ^ if present (already handled)
    regex=$(echo "$regex" | sed 's/\$$//')
    regex=$(echo "$regex" | sed 's/^\^//')
    
    # Convert character classes
    # [0-9]+ -> [0-9]+
    # [a-zA-Z0-9_-] -> [a-zA-Z0-9_-]
    # (These are the same in Nginx, so minimal conversion needed)
    
    echo "$regex"
}

convert_target_to_nginx() {
    local target="$1"
    
    # Convert Apache backreferences to Nginx
    # $1 -> $1 (same)
    # %{HTTP_HOST} -> $host
    # %{REQUEST_URI} -> $request_uri
    # %{QUERY_STRING} -> $query_string
    
    target=$(echo "$target" | sed 's/%{HTTP_HOST}/$host/g')
    target=$(echo "$target" | sed 's/%{REQUEST_URI}/$request_uri/g')
    target=$(echo "$target" | sed 's/%{QUERY_STRING}/$query_string/g')
    target=$(echo "$target" | sed 's/%{SERVER_NAME}/$server_name/g')
    
    echo "$target"
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

write_rewrites_safely() {
    local temp_file="$1"
    local target="$2"

    log_info "Writing rewrites configuration to: $target"

    # Backup existing config
    if [[ -f "$target" ]]; then
        cp "$target" "$NGINX_BACKUP"
        log_info "Backed up existing config: $NGINX_BACKUP"
    fi

    # Atomic write
    if mv "$temp_file" "$target"; then
        log_success "Rewrites configuration updated"
        return 0
    else
        log_error "Failed to write rewrites configuration"
        return 1
    fi
}

reload_nginx_safely() {
    log_info "Testing Nginx configuration..."

    # Test Nginx syntax
    if ! nginx -t 2>&1 | grep -q "successful"; then
        log_error "Nginx configuration test failed!"
        log_warn "Restoring backup..."
        
        if [[ -f "$NGINX_BACKUP" ]]; then
            cp "$NGINX_BACKUP" "$REWRITES_CONF"
            log_warn "Restored from backup: $NGINX_BACKUP"
        fi
        
        return 1
    fi

    log_success "Nginx configuration is valid"
    log_info "Reloading Nginx..."

    if systemctl reload nginx; then
        log_success "Nginx reloaded successfully"
        return 0
    else
        log_error "Failed to reload Nginx"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "Starting .htaccess conversion for: $DOMAIN_PATH"

    # Validate
    if ! validate_inputs; then
        log_info "Creating default rewrites.conf..."
        cat > "$REWRITES_CONF" << 'DEFAULT'
# ============================================================================
# SHM Panel - Nginx Rewrites (Default)
# ============================================================================
# Default rewrite rules for clean PHP URLs
# ============================================================================

# Prevent direct access to hidden files
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

# Prevent direct access to sensitive files
location ~ ~$ {
    deny all;
    access_log off;
    log_not_found off;
}

# Clean URLs: Remove .php extension
# Example: /login -> login.php (if login.php exists)
location / {
    try_files $uri $uri/ /index.php?$query_string;
}
DEFAULT
        log_success "Created default rewrites.conf"
        return 0
    fi

    # Convert .htaccess to Nginx syntax
    local temp_nginx
    temp_nginx=$(convert_htaccess_to_nginx "$HTACCESS_FILE")
    
    if [[ -z "$temp_nginx" ]] || [[ ! -f "$temp_nginx" ]]; then
        log_error "Conversion failed"
        exit 1
    fi

    # Write safely with atomic operation
    if ! write_rewrites_safely "$temp_nginx" "$REWRITES_CONF"; then
        rm -f "$temp_nginx"
        exit 1
    fi

    # Reload Nginx
    if ! reload_nginx_safely; then
        exit 1
    fi

    log_success ".htaccess conversion completed successfully!"
}

# Run main
main "$@"
