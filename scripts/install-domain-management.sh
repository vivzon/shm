#!/bin/bash

################################################################################
# SHM PANEL - DOMAIN MANAGEMENT SETUP & INSTALLATION
# ============================================================================
# This script installs all domain management components for SHM Panel
#
# Usage: ./install-domain-management.sh
#
# This will:
#   1. Install required dependencies (inotify-tools)
#   2. Copy scripts to /usr/local/bin
#   3. Set proper permissions
#   4. Install systemd service
#   5. Create necessary directories
#   6. Start the htaccess watcher service
#
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log/shm-panel"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================================
# VALIDATION
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    # Check for required commands
    local missing_deps=()
    
    for cmd in nginx php-fpm8.2 systemctl; do
        if ! command -v $cmd &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing_deps[*]}"
        exit 1
    fi

    # Check for inotify-tools (optional but recommended)
    if ! command -v inotifywait &>/dev/null; then
        log_warn "inotify-tools not installed (auto-watcher will not work)"
        log_info "Install with: apt-get install inotify-tools"
    fi

    log_success "Dependency check passed"
}

# ============================================================================
# INSTALLATION
# ============================================================================

install_scripts() {
    log_info "Installing domain management scripts..."

    # Install add-domain script
    if [[ -f "$SCRIPT_DIR/add-domain.sh" ]]; then
        cp "$SCRIPT_DIR/add-domain.sh" "$INSTALL_PREFIX/add-domain"
        chmod 755 "$INSTALL_PREFIX/add-domain"
        log_success "Installed: /usr/local/bin/add-domain"
    else
        log_error "add-domain.sh not found in $SCRIPT_DIR"
        exit 1
    fi

    # Install htaccess-converter script
    if [[ -f "$SCRIPT_DIR/htaccess-converter.sh" ]]; then
        cp "$SCRIPT_DIR/htaccess-converter.sh" "$INSTALL_PREFIX/htaccess-converter"
        chmod 755 "$INSTALL_PREFIX/htaccess-converter"
        log_success "Installed: /usr/local/bin/htaccess-converter"
    else
        log_error "htaccess-converter.sh not found in $SCRIPT_DIR"
        exit 1
    fi

    # Install watcher script
    if [[ -f "$SCRIPT_DIR/shm-htaccess-watcher.sh" ]]; then
        cp "$SCRIPT_DIR/shm-htaccess-watcher.sh" "$INSTALL_PREFIX/shm-htaccess-watcher"
        chmod 755 "$INSTALL_PREFIX/shm-htaccess-watcher"
        log_success "Installed: /usr/local/bin/shm-htaccess-watcher"
    else
        log_error "shm-htaccess-watcher.sh not found in $SCRIPT_DIR"
        exit 1
    fi
}

install_systemd_service() {
    log_info "Installing systemd service..."

    # Check if service file exists in parent directory
    local service_file="../systemd/shm-htaccess-watcher.service"
    
    if [[ ! -f "$service_file" ]]; then
        log_warn "Service file not found at $service_file"
        log_info "Creating service file..."
        
        mkdir -p "$(dirname "$service_file")"
        
        cat > "$service_file" << 'SYSTEMD'
[Unit]
Description=SHM Panel - Htaccess to Nginx Auto-Converter Service
Documentation=https://shm-panel.com/docs
After=network.target nginx.service php8.2-fpm.service

[Service]
Type=simple
ExecStart=/usr/local/bin/shm-htaccess-watcher
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=shm-htaccess-watcher
User=root
Group=root

PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/www/clients /var/log/shm-panel /run/php

LimitNOFILE=65536
LimitNPROC=512

[Install]
WantedBy=multi-user.target
SYSTEMD
    fi

    cp "$service_file" "$SYSTEMD_DIR/shm-htaccess-watcher.service"
    chmod 644 "$SYSTEMD_DIR/shm-htaccess-watcher.service"
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    log_success "Installed: $SYSTEMD_DIR/shm-htaccess-watcher.service"
}

create_directories() {
    log_info "Creating necessary directories..."

    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    
    log_success "Created: $LOG_DIR"
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

enable_and_start_service() {
    log_info "Enabling and starting htaccess watcher service..."

    if systemctl enable shm-htaccess-watcher; then
        log_success "Service enabled"
    else
        log_error "Failed to enable service"
        return 1
    fi

    if systemctl start shm-htaccess-watcher; then
        log_success "Service started"
    else
        log_error "Failed to start service"
        return 1
    fi

    # Check service status
    if systemctl is-active --quiet shm-htaccess-watcher; then
        log_success "Service is running"
        return 0
    else
        log_error "Service failed to start"
        systemctl status shm-htaccess-watcher || true
        return 1
    fi
}

# ============================================================================
# INTEGRATION WITH SHM-MANAGE
# ============================================================================

integrate_with_shm_manage() {
    log_info "Integrating with shm-manage script..."

    local shm_manage="/usr/local/bin/shm-manage"
    
    if [[ ! -f "$shm_manage" ]]; then
        log_warn "shm-manage script not found at $shm_manage"
        log_info "Please manually add domain commands to shm-manage"
        return 0
    fi

    # Check if domain commands already integrated
    if grep -q "cmd_add_domain" "$shm_manage"; then
        log_info "Domain commands already integrated with shm-manage"
        return 0
    fi

    log_warn "Manual integration needed for shm-manage"
    log_info "See shm-domain-commands.sh for the functions to add"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    log_info "Verifying installation..."

    local checks_passed=0
    local checks_total=5

    # Check 1: Scripts installed
    if [[ -x "$INSTALL_PREFIX/add-domain" ]] && \
       [[ -x "$INSTALL_PREFIX/htaccess-converter" ]] && \
       [[ -x "$INSTALL_PREFIX/shm-htaccess-watcher" ]]; then
        log_success "✓ All scripts installed"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Some scripts not installed"
    fi
    checks_total=$((checks_total + 1))

    # Check 2: Systemd service installed
    if [[ -f "$SYSTEMD_DIR/shm-htaccess-watcher.service" ]]; then
        log_success "✓ Systemd service installed"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Systemd service not found"
    fi
    checks_total=$((checks_total + 1))

    # Check 3: Log directory created
    if [[ -d "$LOG_DIR" ]]; then
        log_success "✓ Log directory created"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Log directory not found"
    fi
    checks_total=$((checks_total + 1))

    # Check 4: Service enabled
    if systemctl is-enabled shm-htaccess-watcher &>/dev/null; then
        log_success "✓ Service enabled"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Service not enabled"
    fi
    checks_total=$((checks_total + 1))

    # Check 5: Service running
    if systemctl is-active --quiet shm-htaccess-watcher; then
        log_success "✓ Service running"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ Service not running"
    fi
    checks_total=$((checks_total + 1))

    echo ""
    log_info "Verification: $checks_passed/$checks_total checks passed"
    
    if [[ $checks_passed -eq $checks_total ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║    SHM PANEL - DOMAIN MANAGEMENT INSTALLATION                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    check_dependencies
    create_directories
    install_scripts
    install_systemd_service
    enable_and_start_service
    integrate_with_shm_manage

    echo ""
    if verify_installation; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                  INSTALLATION SUCCESSFUL                       ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Available Commands:"
        echo "  • add-domain <domain> <user> [php_version]"
        echo "  • htaccess-converter <domain_path>"
        echo "  • shm-htaccess-watcher (running as service)"
        echo ""
        echo "Service Status:"
        echo "  • systemctl status shm-htaccess-watcher"
        echo "  • systemctl restart shm-htaccess-watcher"
        echo "  • systemctl logs -u shm-htaccess-watcher -f"
        echo ""
        echo "Logs:"
        echo "  • /var/log/shm-panel/domain-creation.log"
        echo "  • /var/log/shm-panel/htaccess-watcher.log"
        echo ""
        exit 0
    else
        echo ""
        log_error "Installation verification failed"
        echo "Please check the errors above and try again"
        exit 1
    fi
}

# Execute
main "$@"
