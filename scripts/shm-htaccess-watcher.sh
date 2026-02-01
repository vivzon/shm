#!/bin/bash

################################################################################
# SHM PANEL - HTACCESS INOTIFY WATCHER
# ============================================================================
# Purpose: Monitor .htaccess files across all domains and auto-convert
#          changes to Nginx rewrites.conf with safe reload
#
# This script:
#   - Uses inotify to watch for .htaccess changes
#   - Automatically triggers htaccess-converter
#   - Validates Nginx before reload
#   - Logs all operations
#   - Runs as a systemd service
#
# Author: SHM Panel Team
# Version: 1.0 Production
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

CLIENTS_BASE="/var/www/clients"
CONVERTER_SCRIPT="/usr/local/bin/htaccess-converter"
LOG_FILE="/var/log/shm-panel/htaccess-watcher.log"
PID_FILE="/run/shm-htaccess-watcher.pid"
BATCH_WAIT=2  # Seconds to wait before processing batch of changes

# Colors (for logging)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# LOGGING
# ============================================================================

log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}$msg${NC}" | tee -a "$LOG_FILE"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_requirements() {
    log_info "Validating system requirements..."

    # Check if inotifywait is installed
    if ! command -v inotifywait &>/dev/null; then
        log_error "inotify-tools not installed"
        echo "Install with: apt-get install inotify-tools"
        exit 1
    fi

    # Check if converter script exists
    if [[ ! -f "$CONVERTER_SCRIPT" ]]; then
        log_error "Converter script not found: $CONVERTER_SCRIPT"
        exit 1
    fi

    # Check if clients base directory exists
    if [[ ! -d "$CLIENTS_BASE" ]]; then
        log_error "Clients base directory not found: $CLIENTS_BASE"
        exit 1
    fi

    # Create log directory if needed
    mkdir -p "$(dirname "$LOG_FILE")"

    log_success "All requirements validated"
}

# ============================================================================
# CLEANUP & SIGNAL HANDLING
# ============================================================================

cleanup() {
    log_info "Shutting down gracefully..."
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# DOMAIN DISCOVERY
# ============================================================================

find_all_htaccess() {
    # Find all .htaccess files in clients directories
    find "$CLIENTS_BASE" -maxdepth 3 -name ".htaccess" -type f 2>/dev/null || true
}

get_htaccess_directories() {
    # Get unique directory paths containing .htaccess
    find_all_htaccess | while read -r htaccess; do
        dirname "$(dirname "$htaccess")"  # public_html parent
    done | sort -u
}

# ============================================================================
# HTACCESS PROCESSING
# ============================================================================

process_htaccess_change() {
    local domain_path="$1"
    local htaccess="$domain_path/public_html/.htaccess"

    if [[ ! -f "$htaccess" ]]; then
        log_warn "Skipping: .htaccess no longer exists: $htaccess"
        return 1
    fi

    log_info "Processing .htaccess change: $htaccess"

    # Call converter script
    if "$CONVERTER_SCRIPT" "$domain_path" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Successfully converted .htaccess: $htaccess"
        return 0
    else
        log_error "Failed to convert .htaccess: $htaccess"
        return 1
    fi
}

# ============================================================================
# BATCH PROCESSING
# ============================================================================

process_batch() {
    local -A processed_domains
    local file=""
    local domain_path=""

    log_info "Processing batch of .htaccess changes..."

    # Collect all changes for this batch
    while IFS= read -t 0.1 -r file 2>/dev/null || [[ -n "$file" ]]; do
        if [[ -z "$file" ]]; then
            break
        fi

        # Extract domain path from htaccess location
        # Example: /var/www/clients/example.com/public_html/.htaccess
        # Extract: /var/www/clients/example.com
        domain_path=$(echo "$file" | sed 's|/public_html/.*||')
        
        if [[ -n "$domain_path" && ! ${processed_domains[$domain_path]:-0} -eq 1 ]]; then
            processed_domains[$domain_path]=1
        fi
    done

    # Process each unique domain
    for domain_path in "${!processed_domains[@]}"; do
        process_htaccess_change "$domain_path"
    done

    # Validate Nginx after all changes
    log_info "Validating Nginx configuration after batch..."
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Nginx validation successful"
        systemctl reload nginx || log_error "Failed to reload Nginx"
    else
        log_error "Nginx validation failed, not reloading"
    fi
}

# ============================================================================
# INOTIFY WATCH
# ============================================================================

watch_htaccess_files() {
    log_info "Starting .htaccess file watcher..."

    # Build list of directories to watch
    local watch_dirs=()
    while IFS= read -r dir; do
        if [[ -n "$dir" ]]; then
            watch_dirs+=("$dir/public_html")
        fi
    done < <(get_htaccess_directories)

    if [[ ${#watch_dirs[@]} -eq 0 ]]; then
        log_warn "No .htaccess files found, watching base directory..."
        watch_dirs=("$CLIENTS_BASE")
    fi

    log_info "Watching ${#watch_dirs[@]} directories for .htaccess changes"

    # Watch for .htaccess modifications
    # Using 'modify' event to catch edits
    inotifywait -m \
        -e modify \
        -e create \
        --format '%w%f' \
        --exclude '(\.swp|\.tmp|\.bak)$' \
        "${watch_dirs[@]}" 2>/dev/null | \
    while read -r file; do
        # Only process .htaccess files
        if [[ "$file" == *".htaccess" ]]; then
            log_info "Detected change: $file"
            
            # Wait a moment for the file write to complete
            sleep "$BATCH_WAIT"
            
            # Process the change
            domain_path=$(dirname "$(dirname "$file")")
            process_htaccess_change "$domain_path"
        fi
    done
}

# ============================================================================
# INITIAL SETUP
# ============================================================================

initial_conversion() {
    log_info "Running initial .htaccess conversion for all domains..."

    local count=0
    while IFS= read -r htaccess; do
        if [[ -f "$htaccess" ]]; then
            domain_path=$(dirname "$(dirname "$htaccess")")
            if process_htaccess_change "$domain_path"; then
                count=$((count + 1))
            fi
        fi
    done < <(find_all_htaccess)

    log_success "Initial conversion complete ($count domains processed)"
}

# ============================================================================
# DAEMON MODE
# ============================================================================

daemonize() {
    log_info "Starting SHM htaccess watcher daemon..."

    # Write PID file
    echo $$ > "$PID_FILE"
    
    # Redirect output
    exec 1>> "$LOG_FILE"
    exec 2>&1

    # Run watcher
    watch_htaccess_files
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "╔════════════════════════════════════════════════════════════════╗"
    log_info "║        SHM PANEL - HTACCESS INOTIFY WATCHER v1.0              ║"
    log_info "╚════════════════════════════════════════════════════════════════╝"

    # Validate
    validate_requirements

    # Run initial conversion
    initial_conversion

    # Start daemon
    daemonize
}

# Execute
main "$@"
