<?php
// pages/domains.php

// 1. Debugging (Disable in production)
ini_set('display_errors', 1);
error_reporting(E_ALL);

// 2. Bootstrap & Auth
if (session_status() === PHP_SESSION_NONE) session_start();
check_permission('domain_management');
global $pdo;

// --- HELPER: SAFE REDIRECT (Prevents White Page) ---
function safe_redirect($url) {
    if (!headers_sent()) {
        header("Location: $url");
    } else {
        echo "<script>window.location.href='$url';</script>";
        echo "<meta http-equiv='refresh' content='0;url=$url'>";
    }
    exit;
}

// --- HELPER: GENERATE NGINX CONFIG ---
if (!function_exists('generate_nginx_config')) {
    function generate_nginx_config($domain_name, $document_root, $php_version) {
        // Validation
        if (!preg_match('/^[a-zA-Z0-9\.\-]+$/', $domain_name)) return "Invalid domain format.";

        // PHP Socket Path (Matches the shell script installation)
        $php_fpm_socket = "unix:/var/run/php/php{$php_version}-fpm.sock";
        
        // Verify PHP version exists on server
        if (!file_exists("/var/run/php/php{$php_version}-fpm.sock")) {
            return "ERROR: PHP {$php_version} FPM socket not found. Is PHP installed?";
        }

        return <<<EOD
server {
    listen 80;
    listen [::]:80;
    server_name {$domain_name} www.{$domain_name};
    root {$document_root};
    index index.html index.php;

    access_log /var/log/nginx/{$domain_name}.access.log;
    error_log /var/log/nginx/{$domain_name}.error.log;

    # Serve Files
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP Processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass {$php_fpm_socket};
    }

    # Security
    location ~ /\. {
        deny all;
    }
}
EOD;
    }
}

// --- HELPER: DELETE DIRECTORY (Via Sudo) ---
if (!function_exists('delete_directory')) {
    function delete_directory($dir) {
        // Security: Prevent deleting root or outside /var/www
        if (empty($dir) || $dir === '/') return false;
        $real_path = realpath($dir);
        
        if ($real_path === false || strpos($real_path, '/var/www/') !== 0) {
            return false;
        }
        
        // Use sudo rm -rf (Allowed by setup-server.sh)
        shell_exec("sudo rm -rf " . escapeshellarg($real_path));
        return !is_dir($dir);
    }
}

// ==============================================================================
// BACKEND CONTROLLER LOGIC
// ==============================================================================

if (empty($_SESSION['csrf_token'])) { $_SESSION['csrf_token'] = bin2hex(random_bytes(32)); }

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    
    // 1. CSRF Protection
    if (!isset($_POST['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
        die('Invalid CSRF token. Please refresh the page.');
    }

    // 2. HANDLE ADD DOMAIN / SUBDOMAIN
    if (isset($_POST['add_domain']) || isset($_POST['add_subdomain'])) {
        try {
            // Check PHP Shell Exec
            if (!function_exists('shell_exec')) throw new Exception("shell_exec is disabled in php.ini");

            $php_version = sanitize_input($_POST['php_version'] ?? '8.2'); // Default to 8.2
            $parent_id = null;
            
            // --- Logic: Primary Domain ---
            if (isset($_POST['add_domain'])) {
                $domain_name   = sanitize_input($_POST['domain_name']);
                $document_root = rtrim(sanitize_input($_POST['document_root']), '/');
            }
            // --- Logic: Subdomain ---
            elseif (isset($_POST['add_subdomain'])) {
                $prefix = sanitize_input($_POST['sub_prefix']);
                $parent_domain_name = sanitize_input($_POST['parent_domain_name']);
                
                // Fetch Parent ID
                $stmt = $pdo->prepare("SELECT id FROM domains WHERE domain_name = ?");
                $stmt->execute([$parent_domain_name]);
                $parent = $stmt->fetch();
                if (!$parent) throw new Exception('Parent domain not found.');
                
                $parent_id = $parent['id'];
                $domain_name = $prefix . '.' . $parent_domain_name;
                $document_root = rtrim(sanitize_input($_POST['sub_doc_root']), '/');
            }

            // --- Security: Path Traversal Check ---
            if (strpos($document_root, '..') !== false || strpos($document_root, '/var/www/') !== 0) {
                throw new Exception('Security Error: Document root must be within /var/www/');
            }

            // --- Database: Duplicate Check ---
            $stmt = $pdo->prepare("SELECT id FROM domains WHERE domain_name = ?");
            $stmt->execute([$domain_name]);
            if ($stmt->fetch()) throw new Exception('Domain already exists in database.');

            // --- System: Create Directory (Sudo) ---
            if (!is_dir($document_root)) {
                shell_exec("sudo mkdir -p " . escapeshellarg($document_root));
                
                if (!is_dir($document_root)) {
                     throw new Exception("Failed to create directory. Permission denied. Check /etc/sudoers.d/shm-panel");
                }

                // Create Default Index
                $index_content = "<h1>{$domain_name}</h1><p>Hosted by SHM Panel</p>";
                $tmp_index = tempnam(sys_get_temp_dir(), 'index_html');
                file_put_contents($tmp_index, $index_content);
                
                // Move and Set Permissions
                shell_exec("sudo mv " . escapeshellarg($tmp_index) . " " . escapeshellarg($document_root . '/index.html'));
                shell_exec("sudo chown -R www-data:www-data " . escapeshellarg($document_root));
                shell_exec("sudo chmod 755 " . escapeshellarg($document_root));
            }

            // --- System: Generate Nginx Config ---
            $config_content = generate_nginx_config($domain_name, $document_root, $php_version);
            
            if (strpos($config_content, 'ERROR:') === 0) {
                throw new Exception($config_content);
            }

            $config_path = "/etc/nginx/sites-available/{$domain_name}";
            $symlink_path = "/etc/nginx/sites-enabled/{$domain_name}";
            
            // Write Config via Temp File
            $tmp_conf = tempnam(sys_get_temp_dir(), 'nginx_conf');
            file_put_contents($tmp_conf, $config_content);
            
            shell_exec("sudo mv " . escapeshellarg($tmp_conf) . " " . escapeshellarg($config_path));
            shell_exec("sudo chmod 644 " . escapeshellarg($config_path)); // Important for Nginx read access

            // Create Symlink
            if (!file_exists($symlink_path)) {
                shell_exec("sudo ln -s " . escapeshellarg($config_path) . " " . escapeshellarg($symlink_path));
            }

            // --- System: Test & Reload Nginx ---
            $nginx_test = shell_exec("sudo nginx -t 2>&1");
            if (strpos($nginx_test, 'successful') === false) {
                // Rollback if config is bad
                shell_exec("sudo rm " . escapeshellarg($symlink_path));
                shell_exec("sudo rm " . escapeshellarg($config_path));
                throw new Exception("Nginx Config Error: " . $nginx_test);
            }

            shell_exec("sudo systemctl reload nginx");

            // --- Database: Insert Record ---
            $stmt = $pdo->prepare("INSERT INTO domains (user_id, parent_id, domain_name, document_root, php_version, created_at) VALUES (?, ?, ?, ?, ?, NOW())");
            $stmt->execute([$_SESSION['user_id'], $parent_id, $domain_name, $document_root, $php_version]);

            safe_redirect('domains?success=' . urlencode("Domain $domain_name created successfully!"));

        } catch (Exception $e) {
            safe_redirect('domains?error=' . urlencode($e->getMessage()));
        }
    }

    // 3. HANDLE DELETE DOMAIN
    if (isset($_POST['delete_domain'])) {
        $domain_id = intval($_POST['domain_id']);
        
        // Fetch domain securely
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();

        if ($domain) {
            $domain_name = $domain['domain_name'];
            $doc_root    = $domain['document_root'];
            
            // Paths
            $config_path  = "/etc/nginx/sites-available/{$domain_name}";
            $symlink_path = "/etc/nginx/sites-enabled/{$domain_name}";

            // Remove Nginx Files
            if (file_exists($symlink_path)) shell_exec("sudo rm " . escapeshellarg($symlink_path));
            if (file_exists($config_path)) shell_exec("sudo rm " . escapeshellarg($config_path));

            // Remove Directory (Optional: Comment out if you want to keep files)
            if (!empty($doc_root) && strpos($doc_root, '/var/www/') === 0) {
                delete_directory($doc_root);
            }

            // Remove from DB
            $pdo->prepare("DELETE FROM domains WHERE id = ?")->execute([$domain_id]);

            // Reload Nginx
            shell_exec("sudo systemctl reload nginx");

            safe_redirect('domains?success=' . urlencode('Domain deleted successfully.'));
        }
    }
}

// --- FETCH DATA FOR VIEW ---
$domains = get_user_domains($_SESSION['user_id']);
$flash_success = $_GET['success'] ?? null;
$flash_error = $_GET['error'] ?? null;
?>

<!-- ==============================================================================
     FRONTEND VIEW
=============================================================================== -->
<main class="main-content">
    <div class="page-container">
        <!-- Header -->
        <section class="header">
            <div class="header-left">
                <div class="page-title">Domain Management</div>
                <div class="page-subtitle">Manage your websites, subdomains, and configurations.</div>
            </div>
            <div class="header-right">
                <span class="chip chip-live"><i class="fas fa-check-circle"></i> System Active</span>
            </div>
        </section>

        <!-- Flash Messages -->
        <?php if ($flash_success): ?>
            <div class="alert alert-success" style="background: #dcfce7; color: #166534; padding: 1rem; border-radius: 6px; margin-bottom: 1.5rem; border: 1px solid #bbf7d0;">
                <i class="fas fa-check"></i> <?= htmlspecialchars($flash_success); ?>
            </div>
        <?php endif; ?>
        
        <?php if ($flash_error): ?>
            <div class="alert alert-danger" style="background: #fee2e2; color: #991b1b; padding: 1rem; border-radius: 6px; margin-bottom: 1.5rem; border: 1px solid #fecaca;">
                <i class="fas fa-exclamation-triangle"></i> <?= htmlspecialchars($flash_error); ?>
            </div>
        <?php endif; ?>

        <!-- Forms Card -->
        <div class="card">
            <div class="card-body">
                <!-- Tabs -->
                <div class="tab-nav">
                    <button class="tab-btn active" data-tab="add-domain">
                        <i class="fas fa-globe"></i> Add Domain
                    </button>
                    <button class="tab-btn" data-tab="add-subdomain">
                        <i class="fas fa-code-branch"></i> Add Subdomain
                    </button>
                </div>

                <div class="tab-content">
                    
                    <!-- TAB 1: ADD DOMAIN -->
                    <div id="add-domain-tab" class="tab-pane active">
                        <div class="card-title">Register New Domain</div>
                        <p class="text-muted" style="margin-bottom: 15px; font-size: 0.9rem;">
                            Creates a new Nginx configuration and document root.
                        </p>
                        
                        <form method="post">
                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']); ?>">
                            <div class="form-grid">
                                <div class="form-group">
                                    <label>Domain Name</label>
                                    <input type="text" id="domain_name_input" name="domain_name" placeholder="example.com" required>
                                </div>
                                <div class="form-group">
                                    <label>Document Root</label>
                                    <input type="text" id="doc_root_input" name="document_root" placeholder="/var/www/example.com" required>
                                </div>
                                <div class="form-group">
                                    <label>PHP Version</label>
                                    <select name="php_version">
                                        <option value="8.1">PHP 8.1</option>
                                        <option value="8.2" selected>PHP 8.2 (Recommended)</option>
                                        <option value="8.3">PHP 8.3</option>
                                    </select>
                                </div>
                            </div>
                            <div class="form-actions">
                                <button type="submit" name="add_domain" class="btn btn-primary">Create Domain</button>
                            </div>
                        </form>
                    </div>

                    <!-- TAB 2: ADD SUBDOMAIN -->
                    <div id="add-subdomain-tab" class="tab-pane">
                         <div class="card-title">Create Subdomain</div>
                         <p class="text-muted" style="margin-bottom: 15px; font-size: 0.9rem;">
                            Example: <b>blog</b>.yourdomain.com
                        </p>

                         <form method="post">
                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']); ?>">
                            <div class="form-grid">
                                <div class="form-group">
                                    <label>Prefix</label>
                                    <input type="text" id="sub_prefix_input" name="sub_prefix" placeholder="blog" required>
                                </div>
                                <div class="form-group">
                                    <label>Parent Domain</label>
                                    <select id="sub_domain_select" name="parent_domain_name" required>
                                        <option value="">-- Select Parent --</option>
                                        <?php foreach ($domains as $domain): 
                                            // Only list primary domains (don't nest subdomains)
                                            if(empty($domain['parent_id'])): ?>
                                            <option value="<?= htmlspecialchars($domain['domain_name']) ?>">
                                                .<?= htmlspecialchars($domain['domain_name']) ?>
                                            </option>
                                        <?php endif; endforeach; ?>
                                    </select>
                                </div>
                                <div class="form-group">
                                    <label>Document Root</label>
                                    <input type="text" id="sub_doc_root_input" name="sub_doc_root" placeholder="/var/www/..." required>
                                </div>
                                <div class="form-group">
                                    <label>PHP Version</label>
                                    <select name="php_version">
                                        <option value="8.1">PHP 8.1</option>
                                        <option value="8.2" selected>PHP 8.2</option>
                                        <option value="8.3">PHP 8.3</option>
                                    </select>
                                </div>
                            </div>
                            <div class="form-actions">
                                <button type="submit" name="add_subdomain" class="btn btn-primary">Create Subdomain</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>

        <!-- Domain List -->
        <section class="card">
            <div class="card-header">
                <div class="card-title">Existing Domains</div>
            </div>
            <div class="card-body">
                <?php if (empty($domains)): ?>
                    <p style="text-align:center; color: #6b7280; padding: 20px;">
                        No domains found. Add your first domain above.
                    </p>
                <?php else: ?>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Domain</th>
                                    <th>Root Path</th>
                                    <th>Type</th>
                                    <th>PHP</th>
                                    <th style="text-align:right">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($domains as $domain): ?>
                                    <tr>
                                        <td>
                                            <strong><?= htmlspecialchars($domain['domain_name']); ?></strong>
                                            <br>
                                            <a href="http://<?= htmlspecialchars($domain['domain_name']); ?>" target="_blank" style="font-size:0.8rem; color:#2563eb; text-decoration:none;">Visit Site &rarr;</a>
                                        </td>
                                        <td><code><?= htmlspecialchars($domain['document_root']); ?></code></td>
                                        <td>
                                            <?php if($domain['parent_id']): ?>
                                                <span class="badge badge-muted">Subdomain</span>
                                            <?php else: ?>
                                                <span class="badge badge-success">Primary</span>
                                            <?php endif; ?>
                                        </td>
                                        <td><span class="badge"><?= htmlspecialchars($domain['php_version']); ?></span></td>
                                        <td style="text-align:right">
                                            <form method="post" onsubmit="return confirm('⚠️ DANGER: This will delete the domain configuration AND files permanently.\n\nAre you sure?');">
                                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']); ?>">
                                                <input type="hidden" name="domain_id" value="<?= $domain['id']; ?>">
                                                <button type="submit" name="delete_domain" class="btn btn-danger btn-sm">
                                                    <i class="fas fa-trash"></i> Delete
                                                </button>
                                            </form>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </section>

    </div>
</main>

<!-- JAVASCRIPT FOR UX -->
<script>
    document.addEventListener('DOMContentLoaded', function() {
        
        // --- 1. Tab Switching Logic ---
        const tabButtons = document.querySelectorAll('.tab-btn');
        const tabPanes = document.querySelectorAll('.tab-pane');

        tabButtons.forEach(button => {
            button.addEventListener('click', function() {
                // Remove active class from all
                tabButtons.forEach(btn => btn.classList.remove('active'));
                tabPanes.forEach(pane => pane.classList.remove('active'));

                // Add to clicked
                this.classList.add('active');
                const tabId = this.getAttribute('data-tab');
                document.getElementById(tabId + '-tab').classList.add('active');
            });
        });

        // --- 2. Auto-Fill for Primary Domain ---
        const domainInput = document.getElementById('domain_name_input');
        const docRootInput = document.getElementById('doc_root_input');
        
        if (domainInput && docRootInput) {
            domainInput.addEventListener('input', function() {
                const val = this.value.trim().toLowerCase().replace(/\s+/g, '');
                // Standard: /var/www/domain.com
                docRootInput.value = val ? '/var/www/' + val : '';
            });
        }

        // --- 3. Auto-Fill for Subdomain ---
        const subPrefixInput = document.getElementById('sub_prefix_input');
        const subDomainSelect = document.getElementById('sub_domain_select');
        const subDocRootInput = document.getElementById('sub_doc_root_input');

        function updateSubdomain() {
            const prefix = subPrefixInput.value.trim().toLowerCase().replace(/\s+/g, '');
            const parent = subDomainSelect.value.trim(); // contains domain name
            
            if (prefix && parent) {
                // Standard: /var/www/blog.domain.com
                subDocRootInput.value = '/var/www/' + prefix + '.' + parent;
            } else {
                subDocRootInput.value = '';
            }
        }

        if (subPrefixInput && subDomainSelect) {
            subPrefixInput.addEventListener('input', updateSubdomain);
            subDomainSelect.addEventListener('change', updateSubdomain);
        }
    });
</script>
