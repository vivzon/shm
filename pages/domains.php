<?php
check_permission('domain_management');

// --- Helper Functions (No changes in backend logic) ---
function generate_nginx_config($domain_name, $document_root, $php_version) {
    $php_fpm_socket = "unix:/var/run/php/php{$php_version}-fpm.sock";
    return <<<EOD
server {
    listen 80; listen [::]:80;
    server_name {$domain_name} www.{$domain_name};
    root {$document_root};
    index index.html index.php;
    access_log /var/log/nginx/{$domain_name}.access.log;
    error_log /var/log/nginx/{$domain_name}.error.log;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass {$php_fpm_socket}; }
    location ~ /\.ht { deny all; }
}
EOD;
}
function delete_directory($dir) {
    if (!is_dir($dir)) return false;
    $files = array_diff(scandir($dir), ['.', '..']);
    foreach ($files as $file) { (is_dir("$dir/$file")) ? delete_directory("$dir/$file") : unlink("$dir/$file"); }
    return rmdir($dir);
}

// --- CSRF & POST Handling (No changes in backend logic) ---
if (empty($_SESSION['csrf_token'])) { $_SESSION['csrf_token'] = bin2hex(random_bytes(32)); }
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!isset($_POST['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
        die('Invalid CSRF token. Please refresh and try again.');
    }
    if (isset($_POST['add_domain'])) {
        $domain_name   = sanitize_input($_POST['domain_name']);
        $document_root = rtrim(sanitize_input($_POST['document_root']), '/');
        $php_version   = sanitize_input($_POST['php_version']);
        if (!is_dir($document_root)) {
            if (!@mkdir($document_root, 0755, true)) {
                header('Location: domains.php?error=' . urlencode('Failed to create directory. Check permissions.')); exit;
            }
            file_put_contents($document_root . '/index.html', "<h1>{$domain_name}</h1><p>Hosted by SHM Panel</p>");
        }
        $stmt = $pdo->prepare("INSERT INTO domains (user_id, domain_name, document_root, php_version, created_at) VALUES (?, ?, ?, ?, NOW())");
        $stmt->execute([$_SESSION['user_id'], $domain_name, $document_root, $php_version]);
        $config_content = generate_nginx_config($domain_name, $document_root, $php_version);
        $config_path = "/etc/nginx/sites-available/{$domain_name}";
        @file_put_contents($config_path, $config_content);
        $symlink_path = "/etc/nginx/sites-enabled/{$domain_name}";
        if (!file_exists($symlink_path)) { shell_exec("sudo ln -s {$config_path} {$symlink_path}"); }
        shell_exec("sudo nginx -t && sudo systemctl reload nginx");
        header('Location: domains.php?success=' . urlencode('Domain added and configured successfully!'));
        exit;
    }
    if (isset($_POST['delete_domain'])) {
        $domain_id = intval($_POST['domain_id']);
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();
        if ($domain) {
            $domain_name = $domain['domain_name'];
            $config_path = "/etc/nginx/sites-available/{$domain_name}";
            $symlink_path = "/etc/nginx/sites-enabled/{$domain_name}";
            if (file_exists($symlink_path)) { shell_exec("sudo rm {$symlink_path}"); }
            if (file_exists($config_path)) { shell_exec("sudo rm {$config_path}"); }
            if (!empty($domain['document_root']) && is_dir($domain['document_root'])) { delete_directory($domain['document_root']); }
            $delete_stmt = $pdo->prepare("DELETE FROM domains WHERE id = ?");
            $delete_stmt->execute([$domain_id]);
            shell_exec("sudo nginx -t && sudo systemctl reload nginx");
            header('Location: domains.php?success=' . urlencode('Domain, files, and configuration deleted successfully.'));
            exit;
        }
    }
}

// --- Data Fetching for Page Display ---
$domains = get_user_domains($_SESSION['user_id']);
$flash_success = $_GET['success'] ?? null;
$flash_error = $_GET['error'] ?? null;
?>

    <main class="main-content">
        <div class="page-container">
            <section class="header">
                <div class="header-left">
                    <div class="page-title">Domain Management</div>
                    <div class="page-subtitle">Add and manage domains, subdomains, and redirects.</div>
                </div>
                <div class="header-right">
                    <span class="chip chip-live">
                        <i class="fas fa-circle"></i> Session Active
                    </span>
                    <div class="user-info">
                        <div class="user-avatar">
                            <?php
                            $initial = strtoupper(substr($_SESSION['username'] ?? 'U', 0, 1));
                            echo htmlspecialchars($initial);
                            ?>
                        </div>
                        <div class="user-meta">
                            <span class="user-name"><?php echo htmlspecialchars($_SESSION['username']); ?></span>
                            <span class="user-role"><?php echo is_admin() ? 'Administrator' : 'User'; ?></span>
                        </div>
                    </div>
                </div>
            </section>

            <?php if ($flash_success): ?><div class="alert alert-success"><?= htmlspecialchars($flash_success); ?></div><?php endif; ?>
            <?php if ($flash_error): ?><div class="alert alert-danger"><?= htmlspecialchars($flash_error); ?></div><?php endif; ?>

            <!-- === NEW TABBED INTERFACE === -->
            <div class="card">
                <div class="card-body">
                    <div class="tab-nav">
                        <button class="tab-btn active" data-tab="add-domain">Add Domain</button>
                        <button class="tab-btn" data-tab="add-subdomain">Subdomain</button>
                        <button class="tab-btn" data-tab="park-domain">Park Domain</button>
                        <button class="tab-btn" data-tab="redirect-domain">Redirect</button>
                    </div>

                    <div class="tab-content">
                        <!-- Add Primary Domain Tab -->
                        <div id="add-domain-tab" class="tab-pane active">
                            <div class="card-title">Add New Primary Domain</div>
                            <div class="card-subtitle">This will create the directory and Nginx configuration automatically.</div>
                            <form method="post" style="margin-top: 16px;">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']); ?>">
                                <div class="form-grid">
                                    <div class="form-group"><label for="domain_name_input">Domain Name</label><input type="text" id="domain_name_input" name="domain_name" placeholder="example.com" required><div class="field-hint">The main domain you own.</div></div>
                                    <div class="form-group"><label for="doc_root_input">Document Root</label><input type="text" id="doc_root_input" name="document_root" placeholder="/var/www/example.com" required><div class="field-hint">The folder for this domain's files.</div></div>
                                    <div class="form-group"><label for="php_version">PHP Version</label><select id="php_version" name="php_version"><option value="8.1">PHP 8.1</option><option value="8.2" selected>PHP 8.2</option><option value="8.3">PHP 8.3</option><option value="8.4">PHP 8.4</option></select><div class="field-hint">The PHP version for this site.</div></div>
                                </div>
                                <div class="form-actions"><button type="submit" name="add_domain" class="btn btn-primary">➕ Add Domain</button></div>
                            </form>
                        </div>

                        <!-- Add Subdomain Tab -->
                        <div id="add-subdomain-tab" class="tab-pane">
                            <div class="card-title">Create a Subdomain</div>
                            <div class="card-subtitle">e.g., blog.example.com</div>
                             <form method="post" action="#" style="margin-top: 16px;"> <!-- Placeholder action -->
                                <div class="form-grid">
                                    <div class="form-group"><label for="sub_prefix_input">Subdomain Prefix</label><input type="text" id="sub_prefix_input" name="sub_prefix" placeholder="blog" required></div>
                                    <div class="form-group"><label for="sub_domain_select">Parent Domain</label>
                                        <select id="sub_domain_select" name="sub_domain_id" required>
                                            <option value="">-- Select Domain --</option>
                                            <?php foreach ($domains as $domain): ?><option value="<?= htmlspecialchars($domain['domain_name']) ?>">.<?= htmlspecialchars($domain['domain_name']) ?></option><?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="form-group"><label for="sub_doc_root_input">Document Root</label><input type="text" id="sub_doc_root_input" name="sub_doc_root" placeholder="/var/www/blog.example.com" required></div>
                                </div>
                                <div class="form-actions"><button type="submit" class="btn btn-primary">➕ Create Subdomain</button></div>
                            </form>
                        </div>

                        <!-- Park Domain Tab -->
                        <div id="park-domain-tab" class="tab-pane">
                            <div class="card-title">Park a Domain (Alias)</div>
                            <div class="card-subtitle">Make another domain show the same website as an existing domain.</div>
                             <form method="post" action="#" style="margin-top: 16px;"> <!-- Placeholder action -->
                                <div class="form-grid">
                                    <div class="form-group"><label for="park_alias">Domain to Park</label><input type="text" id="park_alias" name="park_alias" placeholder="my-other-domain.net" required><div class="field-hint">The new domain you want to park.</div></div>
                                    <div class="form-group"><label for="park_target_id">Park on top of</label>
                                        <select id="park_target_id" name="park_target_id" required>
                                            <option value="">-- Select Existing Domain --</option>
                                            <?php foreach ($domains as $domain): ?><option value="<?= (int)$domain['id'] ?>"><?= htmlspecialchars($domain['domain_name']) ?></option><?php endforeach; ?>
                                        </select>
                                        <div class="field-hint">The website content to show.</div>
                                    </div>
                                </div>
                                <div class="form-actions"><button type="submit" class="btn btn-primary">➕ Park Domain</button></div>
                            </form>
                        </div>
                        
                        <!-- Redirect Domain Tab -->
                        <div id="redirect-domain-tab" class="tab-pane">
                             <div class="card-title">Setup a Redirect</div>
                             <div class="card-subtitle">Permanently forward a domain to another URL.</div>
                             <form method="post" action="#" style="margin-top: 16px;"> <!-- Placeholder action -->
                                <div class="form-grid">
                                    <div class="form-group"><label for="redirect_source_id">Domain to Redirect</label>
                                        <select id="redirect_source_id" name="redirect_source_id" required>
                                            <option value="">-- Select Domain to Forward --</option>
                                            <?php foreach ($domains as $domain): ?><option value="<?= (int)$domain['id'] ?>"><?= htmlspecialchars($domain['domain_name']) ?></option><?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="form-group"><label for="redirect_dest">Destination URL</label><input type="text" id="redirect_dest" name="redirect_dest" placeholder="https://www.google.com" required><div class="field-hint">Include http:// or https://</div></div>
                                </div>
                                <div class="form-actions"><button type="submit" class="btn btn-primary">➕ Add Redirect</button></div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>


            <section class="card">
                <div class="card-header"><div><div class="card-title">Your Domains</div></div></div>
                <div class="card-body">
                    <?php if (empty($domains)): ?>
                        <p style="font-size: 13px; color: var(--text-muted);">No domains added yet. Use the form above to get started.</p>
                    <?php else: ?>
                        <div class="table-wrapper">
                            <table>
                                <thead><tr><th>Domain Name</th><th>Document Root</th><th>PHP</th><th>SSL</th><th>Actions</th></tr></thead>
                                <tbody>
                                    <?php foreach ($domains as $domain): ?>
                                        <tr>
                                            <td><strong><?= htmlspecialchars($domain['domain_name']); ?></strong></td>
                                            <td><?= htmlspecialchars($domain['document_root']); ?></td>
                                            <td><?= htmlspecialchars($domain['php_version']); ?></td>
                                            <td><span class="badge <?= !empty($domain['ssl_enabled']) ? 'badge-success' : 'badge-muted' ?>"><?= !empty($domain['ssl_enabled']) ? 'Enabled' : 'Disabled' ?></span></td>
                                            <td>
                                                <form method="post" style="display: inline;" onsubmit="return confirm('Are you sure you want to delete this domain and all its files? This cannot be undone.');">
                                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']); ?>">
                                                    <input type="hidden" name="domain_id" value="<?= (int)$domain['id']; ?>">
                                                    <button type="submit" name="delete_domain" class="btn btn-danger btn-sm">🗑️ Delete</button>
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

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            
            // --- Collapsible Sidebar Logic ---
            /*const submenuToggles = document.querySelectorAll('.sidebar .has-submenu > a');
            submenuToggles.forEach(toggle => {
                toggle.addEventListener('click', function(event) {
                    event.preventDefault();
                    this.parentElement.classList.toggle('open');
                });
            });*/

            // --- Tab Switching Logic ---
            const tabButtons = document.querySelectorAll('.tab-btn');
            const tabPanes = document.querySelectorAll('.tab-pane');

            tabButtons.forEach(button => {
                button.addEventListener('click', function() {
                    // Deactivate all
                    tabButtons.forEach(btn => btn.classList.remove('active'));
                    tabPanes.forEach(pane => pane.classList.remove('active'));

                    // Activate clicked
                    this.classList.add('active');
                    const tabId = this.getAttribute('data-tab');
                    document.getElementById(tabId + '-tab').classList.add('active');
                });
            });

            // --- Document Root Auto-Suggestion Logic ---
            const domainInput = document.getElementById('domain_name_input');
            const docRootInput = document.getElementById('doc_root_input');
            
            if (domainInput && docRootInput) {
                domainInput.addEventListener('input', function() {
                    const domainValue = this.value.trim().toLowerCase().replace(/\s+/g, '');
                    if (domainValue) {
                        docRootInput.value = '/var/www/' + domainValue;
                    } else {
                        docRootInput.value = '';
                    }
                });
            }

            // --- Subdomain Document Root Auto-Suggestion Logic ---
            const subPrefixInput = document.getElementById('sub_prefix_input');
            const subDomainSelect = document.getElementById('sub_domain_select');
            const subDocRootInput = document.getElementById('sub_doc_root_input');

            function updateSubdomainRootSuggestion() {
                const prefix = subPrefixInput.value.trim().toLowerCase().replace(/\s+/g, '');
                const parentDomain = subDomainSelect.value;
                
                if (prefix && parentDomain) {
                    subDocRootInput.value = '/var/www/' + prefix + '.' + parentDomain;
                } else {
                    subDocRootInput.value = '';
                }
            }

            if (subPrefixInput && subDomainSelect && subDocRootInput) {
                subPrefixInput.addEventListener('input', updateSubdomainRootSuggestion);
                subDomainSelect.addEventListener('change', updateSubdomainRootSuggestion);
            }
        });
    </script>
