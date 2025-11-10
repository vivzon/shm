#!/bin/bash

# ===================================================
# SHM Control Panel Installer
# Author: Vivek Raj
# Version: 2.0
# ===================================================

echo "=============================================="
echo "        SHM (Server Hosting Manager)"
echo "         Complete Installer Starting..."
echo "=============================================="

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
LOG_FILE="/var/log/shm-install.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

# Functions
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "ℹ️ $1"; }

# Generate random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 16
}

# Detect OS and set variables
detect_os() {
    if [ -f /etc/redhat-release ] || [ -f /etc/almalinux-release ] || [ -f /etc/rocky-release ]; then
        OS="centos"
        PKG_MANAGER="dnf"
        PHP_FPM_SERVICE="php-fpm"
        WEB_USER="nginx"
    elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        OS="ubuntu"
        PKG_MANAGER="apt"
        PHP_FPM_SERVICE="php8.4-fpm"
        WEB_USER="www-data"
    else
        log_error "Unsupported OS. Please use AlmaLinux, Rocky, or Ubuntu."
        exit 1
    fi
}

# Update system
update_system() {
    log_info "🔄 Updating system packages..."
    if [ "$OS" == "centos" ]; then
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
    else
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y software-properties-common
        add-apt-repository -y ppa:ondrej/php
        $PKG_MANAGER update -y
    fi
}

# Install dependencies
install_dependencies() {
    log_info "📦 Installing dependencies..."
    
    if [ "$OS" == "centos" ]; then
        $PKG_MANAGER install -y \
            nginx \
            mariadb-server \
            mariadb \
            php8.4 \
            php8.4-fpm \
            php8.4-mysqlnd \
            php8.4-curl \
            php8.4-gd \
            php8.4-mbstring \
            php8.4-xml \
            php8.4-zip \
            php8.4-json \
            php8.4-bcmath \
            git \
            curl \
            wget \
            unzip \
            htop \
            nano
    else
        $PKG_MANAGER install -y \
            nginx \
            mariadb-server \
            mariadb-client \
            php8.4 \
            php8.4-fpm \
            php8.4-mysql \
            php8.4-curl \
            php8.4-gd \
            php8.4-mbstring \
            php8.4-xml \
            php8.4-zip \
            php8.4-json \
            php8.4-bcmath \
            git \
            curl \
            wget \
            unzip \
            htop \
            nano
    fi
}

# Configure services
configure_services() {
    log_info "⚙️ Configuring services..."
    
    # Start and enable services
    systemctl enable nginx mariadb $PHP_FPM_SERVICE
    systemctl start nginx mariadb $PHP_FPM_SERVICE
    
    # Secure MySQL installation
    log_info "🔒 Securing MySQL installation..."
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -e "FLUSH PRIVILEGES;"
}

# Create project structure
create_structure() {
    log_info "📁 Creating project structure..."
    
    mkdir -p /var/www/shm-panel/{config,includes,modules,public/assets/{css,js,images},templates,sql,logs,backups}
    mkdir -p /var/www/shm-panel/modules/{domains,email,databases,ftp,ssh,system}
    mkdir -p /var/www/shm-panel/public/uploads
}

# Create configuration files
create_config_files() {
    log_info "📄 Creating configuration files..."
    
    # Generate secure keys
    DB_PASSWORD=$(generate_password)
    ADMIN_PASSWORD=$(generate_password)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    
    # Create database configuration
    cat > /var/www/shm-panel/config/database.php << EOF
<?php
define('DB_HOST', 'localhost');
define('DB_NAME', 'shm_panel');
define('DB_USER', 'shm_user');
define('DB_PASS', '${DB_PASSWORD}');
define('DB_CHARSET', 'utf8mb4');
?>
EOF

    # Create main configuration
    cat > /var/www/shm-panel/config/config.php << EOF
<?php
define('SITE_NAME', 'SHM Control Panel');
define('SITE_URL', 'http://\$_SERVER[HTTP_HOST]');
define('ENCRYPTION_KEY', '${ENCRYPTION_KEY}');
define('UPLOAD_PATH', '/var/www/shm-panel/public/uploads/');
define('BACKUP_PATH', '/var/www/shm-panel/backups/');
define('LOG_PATH', '/var/www/shm-panel/logs/');
define('DEFAULT_TIMEZONE', 'UTC');

// Security settings
define('MAX_LOGIN_ATTEMPTS', 5);
define('SESSION_TIMEOUT', 3600);
?>
EOF

    # Create .htaccess for security
    cat > /var/www/shm-panel/public/.htaccess << EOF
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.php?route=\$1 [QSA,L]

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

# Prevent access to sensitive files
<Files "*.php">
    Order Allow,Deny
    Deny from all
</Files>

<Files "index.php">
    Order Allow,Deny
    Allow from all
</Files>
EOF
}

# Create core application files
create_application_files() {
    log_info "💻 Creating application files..."
    
    # Create main index.php
    cat > /var/www/shm-panel/public/index.php << 'EOF'
<?php
session_start();
require_once '../config/config.php';
require_once '../config/database.php';
require_once '../includes/functions.php';
require_once '../includes/auth.php';

// Set timezone
date_default_timezone_set(DEFAULT_TIMEZONE);

// Security headers
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');

// Route handling
$route = isset($_GET['route']) ? $_GET['route'] : 'dashboard';
$route = rtrim($route, '/');
$route_parts = explode('/', $route);

// Main routing
$module = $route_parts[0] ?? 'dashboard';
$action = $route_parts[1] ?? 'index';

// Check authentication for protected routes
$public_routes = ['login', 'logout', 'api'];
if (!in_array($module, $public_routes) && !is_authenticated()) {
    header('Location: /login');
    exit;
}

// Load appropriate module
$module_file = "../modules/$module/$action.php";
if (file_exists($module_file)) {
    require_once $module_file;
} else {
    // Show 404
    http_response_code(404);
    include '../templates/404.php';
}
?>
EOF

    # Create functions.php
    cat > /var/www/shm-panel/includes/functions.php << 'EOF'
<?php
// Database connection
function get_db_connection() {
    static $connection = null;
    
    if ($connection === null) {
        $connection = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        
        if ($connection->connect_error) {
            die("Database connection failed: " . $connection->connect_error);
        }
        
        $connection->set_charset(DB_CHARSET);
    }
    
    return $connection;
}

// Secure input filtering
function sanitize_input($data) {
    if (is_array($data)) {
        return array_map('sanitize_input', $data);
    }
    
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    return $data;
}

// Password hashing
function hash_password($password) {
    return password_hash($password, PASSWORD_DEFAULT);
}

// Verify password
function verify_password($password, $hash) {
    return password_verify($password, $hash);
}

// Generate CSRF token
function generate_csrf_token() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

// Validate CSRF token
function validate_csrf_token($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

// Log activity
function log_activity($user_id, $action, $details = '') {
    $db = get_db_connection();
    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
    $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
    
    $stmt = $db->prepare("INSERT INTO activity_logs (user_id, action, details, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("issss", $user_id, $action, $details, $ip_address, $user_agent);
    $stmt->execute();
}

// Get server stats
function get_server_stats() {
    $stats = [];
    
    // CPU usage
    $load = sys_getloadavg();
    $stats['cpu_load'] = $load[0];
    
    // Memory usage
    $meminfo = file_get_contents('/proc/meminfo');
    preg_match_all('/^(\w+):\s+(\d+)/m', $meminfo, $matches);
    $meminfo = array_combine($matches[1], $matches[2]);
    
    $stats['memory_total'] = $meminfo['MemTotal'] ?? 0;
    $stats['memory_free'] = $meminfo['MemFree'] ?? 0;
    $stats['memory_used'] = $stats['memory_total'] - $stats['memory_free'];
    $stats['memory_usage_percent'] = $stats['memory_total'] > 0 ? 
        round(($stats['memory_used'] / $stats['memory_total']) * 100, 2) : 0;
    
    // Disk usage
    $disk_total = disk_total_space('/');
    $disk_free = disk_free_space('/');
    $stats['disk_used'] = $disk_total - $disk_free;
    $stats['disk_usage_percent'] = round(($stats['disk_used'] / $disk_total) * 100, 2);
    
    return $stats;
}

// Execute shell command safely
function execute_command($command, $allowed_commands = []) {
    // Basic command validation
    $dangerous_patterns = ['&&', '||', ';', '`', '$', '>', '<', '|'];
    
    foreach ($dangerous_patterns as $pattern) {
        if (strpos($command, $pattern) !== false) {
            return ['success' => false, 'output' => 'Dangerous command pattern detected'];
        }
    }
    
    // Check if command is in allowed list
    $command_base = explode(' ', $command)[0];
    if (!empty($allowed_commands) && !in_array($command_base, $allowed_commands)) {
        return ['success' => false, 'output' => 'Command not allowed'];
    }
    
    // Execute command
    exec($command . ' 2>&1', $output, $return_code);
    
    return [
        'success' => $return_code === 0,
        'output' => implode("\n", $output),
        'return_code' => $return_code
    ];
}
?>
EOF

    # Create auth.php
    cat > /var/www/shm-panel/includes/auth.php << 'EOF'
<?php
function is_authenticated() {
    return isset($_SESSION['user_id']) && !empty($_SESSION['user_id']);
}

function login_user($username, $password) {
    $db = get_db_connection();
    
    // Check login attempts
    $ip = $_SERVER['REMOTE_ADDR'];
    $stmt = $db->prepare("SELECT COUNT(*) FROM login_attempts WHERE ip_address = ? AND attempt_time > DATE_SUB(NOW(), INTERVAL 1 HOUR)");
    $stmt->bind_param("s", $ip);
    $stmt->execute();
    $stmt->bind_result($attempts);
    $stmt->fetch();
    $stmt->close();
    
    if ($attempts >= MAX_LOGIN_ATTEMPTS) {
        return ['success' => false, 'message' => 'Too many login attempts. Please try again later.'];
    }
    
    // Get user
    $stmt = $db->prepare("SELECT id, username, password, email, role, status FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $stmt->bind_result($id, $db_username, $db_password, $email, $role, $status);
    $stmt->fetch();
    $stmt->close();
    
    if ($id && $status === 'active' && verify_password($password, $db_password)) {
        // Login successful
        $_SESSION['user_id'] = $id;
        $_SESSION['username'] = $db_username;
        $_SESSION['email'] = $email;
        $_SESSION['role'] = $role;
        
        // Clear login attempts
        $stmt = $db->prepare("DELETE FROM login_attempts WHERE ip_address = ?");
        $stmt->bind_param("s", $ip);
        $stmt->execute();
        $stmt->close();
        
        log_activity($id, 'login', 'User logged in successfully');
        
        return ['success' => true, 'message' => 'Login successful'];
    } else {
        // Record failed attempt
        $stmt = $db->prepare("INSERT INTO login_attempts (ip_address, username) VALUES (?, ?)");
        $stmt->bind_param("ss", $ip, $username);
        $stmt->execute();
        $stmt->close();
        
        return ['success' => false, 'message' => 'Invalid username or password'];
    }
}

function logout_user() {
    if (isset($_SESSION['user_id'])) {
        log_activity($_SESSION['user_id'], 'logout', 'User logged out');
    }
    
    session_destroy();
    session_start();
    session_regenerate_id(true);
}

function has_permission($required_role) {
    $user_role = $_SESSION['role'] ?? 'user';
    $roles = ['user' => 1, 'admin' => 2, 'superadmin' => 3];
    
    return ($roles[$user_role] ?? 0) >= ($roles[$required_role] ?? 0);
}
?>
EOF
}

# Create database schema
create_database_schema() {
    log_info "🗃️ Creating database schema..."
    
    # Generate passwords
    DB_PASSWORD=$(grep -oP "define\('DB_PASS', '\K[^']+" /var/www/shm-panel/config/database.php)
    ADMIN_PASSWORD=$(generate_password)
    HASHED_ADMIN_PASSWORD=$(php -r "echo password_hash('$ADMIN_PASSWORD', PASSWORD_DEFAULT);")
    
    # Create SQL file
    cat > /var/www/shm-panel/sql/install.sql << EOF
-- Create database
CREATE DATABASE IF NOT EXISTS shm_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use database
USE shm_panel;

-- Users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('user', 'admin', 'superadmin') DEFAULT 'user',
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Domains table
CREATE TABLE domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    domain_name VARCHAR(255) UNIQUE NOT NULL,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Email accounts table
CREATE TABLE email_accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    quota_mb INT DEFAULT 1024,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
);

-- Databases table
CREATE TABLE databases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    db_name VARCHAR(64) UNIQUE NOT NULL,
    db_user VARCHAR(32) NOT NULL,
    db_password VARCHAR(255) NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- FTP accounts table
CREATE TABLE ftp_accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    home_directory VARCHAR(255) NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- SSH keys table
CREATE TABLE ssh_keys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    key_name VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Activity logs table
CREATE TABLE activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Login attempts table
CREATE TABLE login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45) NOT NULL,
    username VARCHAR(100),
    attempt_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System settings table
CREATE TABLE system_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert default admin user
INSERT INTO users (username, email, password, role, status) VALUES 
('admin', 'admin@localhost', '$HASHED_ADMIN_PASSWORD', 'superadmin', 'active');

-- Insert default settings
INSERT INTO system_settings (setting_key, setting_value) VALUES 
('site_name', 'SHM Control Panel'),
('site_url', 'http://localhost'),
('smtp_host', ''),
('smtp_port', '587'),
('smtp_username', ''),
('smtp_password', ''),
('backup_retention_days', '30'),
('max_user_domains', '10'),
('max_user_databases', '5'),
('max_user_emails', '10');
EOF

    # Execute SQL
    mysql -e "SOURCE /var/www/shm-panel/sql/install.sql"
}

# Create module files
create_module_files() {
    log_info "🔧 Creating module files..."
    
    # Dashboard module
    cat > /var/www/shm-panel/modules/dashboard/index.php << 'EOF'
<?php
require_once '../../includes/header.php';

$stats = get_server_stats();
$db = get_db_connection();

// Get user counts
$user_count = $db->query("SELECT COUNT(*) FROM users")->fetch_row()[0];
$domain_count = $db->query("SELECT COUNT(*) FROM domains")->fetch_row()[0];
$email_count = $db->query("SELECT COUNT(*) FROM email_accounts")->fetch_row()[0];
$db_count = $db->query("SELECT COUNT(*) FROM databases")->fetch_row()[0];
?>

<div class="container-fluid">
    <h1 class="h3 mb-4">Dashboard</h1>
    
    <!-- Statistics Cards -->
    <div class="row">
        <div class="col-xl-3 col-md-6 mb-4">
            <div class="card border-left-primary shadow h-100 py-2">
                <div class="card-body">
                    <div class="row no-gutters align-items-center">
                        <div class="col mr-2">
                            <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">
                                Users</div>
                            <div class="h5 mb-0 font-weight-bold text-gray-800"><?php echo $user_count; ?></div>
                        </div>
                        <div class="col-auto">
                            <i class="fas fa-users fa-2x text-gray-300"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-xl-3 col-md-6 mb-4">
            <div class="card border-left-success shadow h-100 py-2">
                <div class="card-body">
                    <div class="row no-gutters align-items-center">
                        <div class="col mr-2">
                            <div class="text-xs font-weight-bold text-success text-uppercase mb-1">
                                Domains</div>
                            <div class="h5 mb-0 font-weight-bold text-gray-800"><?php echo $domain_count; ?></div>
                        </div>
                        <div class="col-auto">
                            <i class="fas fa-globe fa-2x text-gray-300"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-xl-3 col-md-6 mb-4">
            <div class="card border-left-info shadow h-100 py-2">
                <div class="card-body">
                    <div class="row no-gutters align-items-center">
                        <div class="col mr-2">
                            <div class="text-xs font-weight-bold text-info text-uppercase mb-1">
                                Email Accounts</div>
                            <div class="h5 mb-0 font-weight-bold text-gray-800"><?php echo $email_count; ?></div>
                        </div>
                        <div class="col-auto">
                            <i class="fas fa-envelope fa-2x text-gray-300"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-xl-3 col-md-6 mb-4">
            <div class="card border-left-warning shadow h-100 py-2">
                <div class="card-body">
                    <div class="row no-gutters align-items-center">
                        <div class="col mr-2">
                            <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">
                                Databases</div>
                            <div class="h5 mb-0 font-weight-bold text-gray-800"><?php echo $db_count; ?></div>
                        </div>
                        <div class="col-auto">
                            <i class="fas fa-database fa-2x text-gray-300"></i>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Server Stats -->
    <div class="row">
        <div class="col-lg-6">
            <div class="card shadow mb-4">
                <div class="card-header py-3">
                    <h6 class="m-0 font-weight-bold text-primary">Server Resources</h6>
                </div>
                <div class="card-body">
                    <div class="mb-3">
                        <strong>CPU Load:</strong> <?php echo $stats['cpu_load']; ?>
                    </div>
                    <div class="mb-3">
                        <strong>Memory Usage:</strong> 
                        <div class="progress">
                            <div class="progress-bar" role="progressbar" 
                                 style="width: <?php echo $stats['memory_usage_percent']; ?>%" 
                                 aria-valuenow="<?php echo $stats['memory_usage_percent']; ?>" 
                                 aria-valuemin="0" aria-valuemax="100">
                                <?php echo $stats['memory_usage_percent']; ?>%
                            </div>
                        </div>
                    </div>
                    <div class="mb-3">
                        <strong>Disk Usage:</strong>
                        <div class="progress">
                            <div class="progress-bar" role="progressbar" 
                                 style="width: <?php echo $stats['disk_usage_percent']; ?>%" 
                                 aria-valuenow="<?php echo $stats['disk_usage_percent']; ?>" 
                                 aria-valuemin="0" aria-valuemax="100">
                                <?php echo $stats['disk_usage_percent']; ?>%
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-lg-6">
            <div class="card shadow mb-4">
                <div class="card-header py-3">
                    <h6 class="m-0 font-weight-bold text-primary">Quick Actions</h6>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <a href="/domains/add" class="btn btn-primary btn-block">
                                <i class="fas fa-plus"></i> Add Domain
                            </a>
                        </div>
                        <div class="col-md-6 mb-3">
                            <a href="/email/add" class="btn btn-success btn-block">
                                <i class="fas fa-envelope"></i> Create Email
                            </a>
                        </div>
                        <div class="col-md-6 mb-3">
                            <a href="/databases/add" class="btn btn-info btn-block">
                                <i class="fas fa-database"></i> Add Database
                            </a>
                        </div>
                        <div class="col-md-6 mb-3">
                            <a href="/system/backup" class="btn btn-warning btn-block">
                                <i class="fas fa-download"></i> Backup
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<?php require_once '../../includes/footer.php'; ?>
EOF

    # Create login module
    cat > /var/www/shm-panel/modules/login/index.php << 'EOF'
<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = sanitize_input($_POST['username']);
    $password = sanitize_input($_POST['password']);
    $csrf_token = sanitize_input($_POST['csrf_token']);
    
    if (validate_csrf_token($csrf_token)) {
        $result = login_user($username, $password);
        
        if ($result['success']) {
            header('Location: /dashboard');
            exit;
        } else {
            $error_message = $result['message'];
        }
    } else {
        $error_message = 'Invalid CSRF token';
    }
}

require_once '../../templates/login.php';
?>
EOF

    # Create domains module
    cat > /var/www/shm-panel/modules/domains/index.php << 'EOF'
<?php
require_once '../../includes/header.php';

$db = get_db_connection();
$user_id = $_SESSION['user_id'];

// Get user domains
$stmt = $db->prepare("SELECT d.* FROM domains d WHERE d.user_id = ? ORDER BY d.created_at DESC");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();
$domains = $result->fetch_all(MYSQLI_ASSOC);
$stmt->close();
?>

<div class="container-fluid">
    <h1 class="h3 mb-4">Domains</h1>
    
    <div class="card shadow mb-4">
        <div class="card-header py-3">
            <h6 class="m-0 font-weight-bold text-primary">Your Domains</h6>
        </div>
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-bordered" id="domainsTable" width="100%" cellspacing="0">
                    <thead>
                        <tr>
                            <th>Domain Name</th>
                            <th>Status</th>
                            <th>Created Date</th>
                            <th>Expiry Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($domains as $domain): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($domain['domain_name']); ?></td>
                            <td>
                                <span class="badge badge-<?php echo $domain['status'] === 'active' ? 'success' : 'warning'; ?>">
                                    <?php echo ucfirst($domain['status']); ?>
                                </span>
                            </td>
                            <td><?php echo date('Y-m-d', strtotime($domain['created_at'])); ?></td>
                            <td><?php echo $domain['expiry_date'] ?: 'N/A'; ?></td>
                            <td>
                                <a href="/domains/manage/<?php echo $domain['id']; ?>" class="btn btn-sm btn-primary">Manage</a>
                                <a href="/domains/delete/<?php echo $domain['id']; ?>" class="btn btn-sm btn-danger" onclick="return confirm('Are you sure?')">Delete</a>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    
    <a href="/domains/add" class="btn btn-primary">Add New Domain</a>
</div>

<?php require_once '../../includes/footer.php'; ?>
EOF

    # Create more modules similarly...
    # [Additional module files would be created here for email, databases, ftp, ssh, system]
}

# Configure Nginx
configure_nginx() {
    log_info "🌐 Configuring Nginx..."
    
    # Create Nginx configuration
    cat > /etc/nginx/conf.d/shm.conf << EOF
server {
    listen 80;
    server_name _;
    root /var/www/shm-panel/public;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Main location
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP handling
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_param HTTP_PROXY "";
        fastcgi_hide_header X-Powered-By;
    }

    # Deny access to sensitive files
    location ~ /\.(ht|git|svn) {
        deny all;
    }

    location ~ /(config|includes|modules|sql|logs|backups) {
        deny all;
    }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # File upload size
    client_max_body_size 100M;
}
EOF

    # Test and reload Nginx
    nginx -t && systemctl reload nginx
}

# Set permissions
set_permissions() {
    log_info "🔐 Setting permissions..."
    
    chown -R $WEB_USER:$WEB_USER /var/www/shm-panel
    chmod -R 755 /var/www/shm-panel
    chmod -R 644 /var/www/shm-panel/config/
    chmod 600 /var/www/shm-panel/config/database.php
    chmod 600 /var/www/shm-panel/config/config.php
    
    # Set SELinux context if applicable
    if command -v semanage &> /dev/null; then
        semanage fcontext -a -t httpd_sys_content_t "/var/www/shm-panel(/.*)?"
        restorecon -R /var/www/shm-panel
    fi
}

# Create systemd services
create_services() {
    log_info "🔧 Creating system services..."
    
    # Create backup service
    cat > /etc/systemd/system/shm-backup.service << EOF
[Unit]
Description=SHM Panel Backup Service
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/php /var/www/shm-panel/modules/system/backup.php
EOF

    # Create backup timer
    cat > /etc/systemd/system/shm-backup.timer << EOF
[Unit]
Description=Daily backup for SHM Panel
Requires=shm-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable shm-backup.timer
    systemctl start shm-backup.timer
}

# Create templates
create_templates() {
    log_info "🎨 Creating templates..."
    
    # Create login template
    cat > /var/www/shm-panel/templates/login.php << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - SHM Control Panel</title>
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            padding: 2rem;
            width: 100%;
            max-width: 400px;
        }
        .form-control:focus {
            border-color: #667eea;
            box-shadow: 0 0 0 0.2rem rgba(102, 126, 234, 0.25);
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
        }
    </style>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="login-card">
        <div class="text-center mb-4">
            <h2><i class="fas fa-server me-2"></i>SHM Panel</h2>
            <p class="text-muted">Sign in to your account</p>
        </div>
        
        <?php if (isset($error_message)): ?>
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <?php echo $error_message; ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        <?php endif; ?>
        
        <form method="POST" action="/login">
            <input type="hidden" name="csrf_token" value="<?php echo generate_csrf_token(); ?>">
            
            <div class="mb-3">
                <label for="username" class="form-label">Username</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-user"></i></span>
                    <input type="text" class="form-control" id="username" name="username" required autofocus>
                </div>
            </div>
            
            <div class="mb-3">
                <label for="password" class="form-label">Password</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-lock"></i></span>
                    <input type="password" class="form-control" id="password" name="password" required>
                </div>
            </div>
            
            <button type="submit" class="btn btn-primary w-100 py-2">
                <i class="fas fa-sign-in-alt me-2"></i>Sign In
            </button>
        </form>
        
        <div class="text-center mt-3">
            <small class="text-muted">SHM Control Panel v2.0</small>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF

    # Create header template
    cat > /var/www/shm-panel/includes/header.php << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo SITE_NAME; ?></title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.datatables.net/1.11.5/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    <style>
        .sidebar {
            min-height: 100vh;
            background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
        }
        .sidebar .nav-link {
            color: white;
            margin: 5px 0;
            border-radius: 5px;
        }
        .sidebar .nav-link:hover {
            background: rgba(255,255,255,0.1);
        }
        .sidebar .nav-link.active {
            background: rgba(255,255,255,0.2);
        }
    </style>
</head>
<body>
    <div class="d-flex">
        <!-- Sidebar -->
        <div class="sidebar col-md-3 col-lg-2 p-3">
            <div class="text-center mb-4">
                <h4 class="text-white"><i class="fas fa-server me-2"></i>SHM Panel</h4>
            </div>
            
            <ul class="nav flex-column">
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'dashboard') !== false ? 'active' : ''; ?>" href="/dashboard">
                        <i class="fas fa-tachometer-alt me-2"></i>Dashboard
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'domains') !== false ? 'active' : ''; ?>" href="/domains">
                        <i class="fas fa-globe me-2"></i>Domains
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'email') !== false ? 'active' : ''; ?>" href="/email">
                        <i class="fas fa-envelope me-2"></i>Email Accounts
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'databases') !== false ? 'active' : ''; ?>" href="/databases">
                        <i class="fas fa-database me-2"></i>Databases
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'ftp') !== false ? 'active' : ''; ?>" href="/ftp">
                        <i class="fas fa-folder me-2"></i>FTP Accounts
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'ssh') !== false ? 'active' : ''; ?>" href="/ssh">
                        <i class="fas fa-key me-2"></i>SSH Keys
                    </a>
                </li>
                <?php if (has_permission('admin')): ?>
                <li class="nav-item">
                    <a class="nav-link <?php echo strpos($_SERVER['REQUEST_URI'], 'system') !== false ? 'active' : ''; ?>" href="/system">
                        <i class="fas fa-cog me-2"></i>System
                    </a>
                </li>
                <?php endif; ?>
                <li class="nav-item">
                    <a class="nav-link text-warning" href="/logout">
                        <i class="fas fa-sign-out-alt me-2"></i>Logout
                    </a>
                </li>
            </ul>
        </div>

        <!-- Main content -->
        <div class="col-md-9 col-lg-10 ml-sm-auto">
            <!-- Topbar -->
            <nav class="navbar navbar-expand navbar-light bg-white topbar mb-4 shadow">
                <div class="container-fluid">
                    <span class="navbar-text">
                        Welcome, <strong><?php echo $_SESSION['username']; ?></strong> 
                        <span class="badge bg-secondary"><?php echo $_SESSION['role']; ?></span>
                    </span>
                    <ul class="navbar-nav">
                        <li class="nav-item">
                            <span class="nav-link">
                                <i class="fas fa-clock"></i> 
                                <?php echo date('Y-m-d H:i:s'); ?>
                            </span>
                        </li>
                    </ul>
                </div>
            </nav>

            <!-- Page content -->
            <main>
EOF

    # Create footer template
    cat > /var/www/shm-panel/includes/footer.php << 'EOF'
            </main>
        </div>
    </div>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/dataTables.bootstrap5.min.js"></script>
    
    <script>
        $(document).ready(function() {
            // Initialize DataTables
            $('table').DataTable({
                pageLength: 25,
                responsive: true
            });
            
            // Auto-refresh server stats every 30 seconds
            setInterval(function() {
                // Could implement AJAX refresh here
            }, 30000);
        });
    </script>
</body>
</html>
EOF
}

# Final setup and cleanup
final_setup() {
    log_info "🎯 Finalizing installation..."
    
    # Create cron jobs
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/bin/php /var/www/shm-panel/modules/system/cleanup.php") | crontab -
    
    # Set firewall rules
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    elif command -v ufw &> /dev/null; then
        ufw allow 'Nginx Full'
    fi
    
    # Clean up installation files
    rm -f /var/www/shm-panel/sql/install.sql
    
    # Display completion message
    SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
    
    log_success "=============================================="
    log_success "✅ SHM Panel Installation Complete!"
    log_success "=============================================="
    log_info "🌐 Access your panel: http://$SERVER_IP"
    log_info "👤 Default admin login:"
    log_info "   Username: admin"
    log_info "   Password: $ADMIN_PASSWORD"
    log_info ""
    log_info "📁 Installation directory: /var/www/shm-panel"
    log_info "📋 Installation log: $LOG_FILE"
    log_info ""
    log_warning "⚠️  Please change the default admin password immediately!"
    log_warning "⚠️  Configure SSL/TLS for production use!"
    log_success "=============================================="
}

# Main installation process
main() {
    detect_os
    update_system
    install_dependencies
    configure_services
    create_structure
    create_config_files
    create_application_files
    create_database_schema
    create_module_files
    create_templates
    configure_nginx
    set_permissions
    create_services
    final_setup
}

# Run installation
main "$@"
