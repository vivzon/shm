<?php
// pages/ssl.php: SSL Certificate Management page
// Assumes includes/config.php is already loaded by index.php
// and require_login() has already been called there.

global $pdo;

// Check permission for this page
check_permission('ssl_management');

// ---------------------------
// Configuration & Security Helpers
// ---------------------------
if (!defined('SSL_ENC_KEY')) {
    // IMPORTANT: change this to a strong, random secret in production
    define('SSL_ENC_KEY', hash('sha256', 'change-this-to-a-very-strong-random-secret-key!', true));
}

function csrf_token() {
    if (empty($_SESSION['ssl_csrf_token'])) {
        $_SESSION['ssl_csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['ssl_csrf_token'];
}

function validate_csrf($token) {
    return isset($_SESSION['ssl_csrf_token']) && hash_equals($_SESSION['ssl_csrf_token'], $token);
}

function encrypt_data($plaintext) {
    $key       = SSL_ENC_KEY;
    $iv_length = openssl_cipher_iv_length('AES-256-CBC');
    $iv        = random_bytes($iv_length);
    $cipher    = openssl_encrypt($plaintext, 'AES-256-CBC', $key, OPENSSL_RAW_DATA, $iv);
    return base64_encode($iv . '::' . $cipher);
}

function decrypt_data($blob) {
    if (!$blob) return '';
    $key  = SSL_ENC_KEY;
    $data = base64_decode($blob);
    if ($data === false || strpos($data, '::') === false) return '';

    $parts = explode('::', $data, 2);
    if (count($parts) !== 2) return '';

    $iv_length = openssl_cipher_iv_length('AES-256-CBC');
    $iv        = substr($parts[0], 0, $iv_length);
    $cipher    = $parts[1];

    $plain = openssl_decrypt($cipher, 'AES-256-CBC', $key, OPENSSL_RAW_DATA, $iv);
    return $plain === false ? '' : $plain;
}

function validate_ssl_certificate($certificate, $private_key) {
    if (!@openssl_x509_read($certificate)) {
        return "Invalid SSL Certificate format.";
    }
    if (!@openssl_pkey_get_private($private_key)) {
        return "Invalid Private Key format.";
    }
    if (!@openssl_x509_check_private_key($certificate, $private_key)) {
        return "Certificate does not match the Private Key.";
    }
    return true;
}

function get_certificate_expiry_from_pem($certificate) {
    $parsed = @openssl_x509_parse($certificate);
    return ($parsed && isset($parsed['validTo_time_t']))
        ? date('Y-m-d H:i:s', $parsed['validTo_time_t'])
        : null;
}

// ---------------------------
// Database Functions
// ---------------------------
function save_ssl_certificate_db($pdo, $domain_id, $certificate, $private_key, $ca_bundle, $expires_at, $auto_renew) {
    $enc_cert = encrypt_data($certificate);
    $enc_pkey = encrypt_data($private_key);
    $enc_ca   = $ca_bundle ? encrypt_data($ca_bundle) : null;

    $sql = "INSERT INTO ssl_certificates (domain_id, certificate, private_key, ca_bundle, expires_at, auto_renew, created_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE
                certificate = VALUES(certificate),
                private_key = VALUES(private_key),
                ca_bundle   = VALUES(ca_bundle),
                expires_at  = VALUES(expires_at),
                auto_renew  = VALUES(auto_renew)";
    $stmt = $pdo->prepare($sql);
    return $stmt->execute([
        $domain_id,
        $enc_cert,
        $enc_pkey,
        $enc_ca,
        $expires_at,
        $auto_renew ? 1 : 0,
    ]);
}

function get_user_certificates($pdo, $user_id) {
    $sql = "SELECT sc.id,
                   sc.domain_id,
                   sc.expires_at,
                   sc.auto_renew,
                   d.domain_name
            FROM ssl_certificates sc
            JOIN domains d ON sc.domain_id = d.id
            WHERE d.user_id = ?
            ORDER BY d.domain_name, sc.expires_at ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$user_id]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function renew_certificate_db($pdo, $cert_id, $user_id) {
    $stmt = $pdo->prepare("SELECT sc.id
                           FROM ssl_certificates sc
                           JOIN domains d ON sc.domain_id = d.id
                           WHERE sc.id = ? AND d.user_id = ?");
    $stmt->execute([$cert_id, $user_id]);

    if (!$stmt->fetch()) {
        return ["error" => "Unauthorized or certificate not found."];
    }

    $new_expiry   = date('Y-m-d H:i:s', strtotime('+90 days'));
    $update_stmt  = $pdo->prepare("UPDATE ssl_certificates SET expires_at = ? WHERE id = ?");
    $update_stmt->execute([$new_expiry, $cert_id]);

    return ["success" => "Certificate renewed successfully. New expiry: $new_expiry"];
}

function delete_certificate_db($pdo, $cert_id, $user_id) {
    $stmt = $pdo->prepare("DELETE sc
                           FROM ssl_certificates sc
                           JOIN domains d ON sc.domain_id = d.id
                           WHERE sc.id = ? AND d.user_id = ?");
    $stmt->execute([$cert_id, $user_id]);
    return $stmt->rowCount() > 0;
}

// ---------------------------
// Handle POST Actions
// ---------------------------
$user_id = $_SESSION['user_id'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? null;

    // CSRF check
    if (!isset($_POST['csrf_token']) || !validate_csrf($_POST['csrf_token'])) {
        if (!empty($_POST['ajax'])) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Invalid security token. Please refresh the page.']);
            exit;
        }
        die('Invalid CSRF token.');
    }

    // Regular form actions (non-AJAX)
    if ($action === 'upload') {
        $domain_id   = filter_input(INPUT_POST, 'domain_id', FILTER_VALIDATE_INT);
        $certificate = trim($_POST['certificate'] ?? '');
        $private_key = trim($_POST['private_key'] ?? '');
        $ca_bundle   = trim($_POST['ca_bundle'] ?? '');
        $auto_renew  = isset($_POST['auto_renew']);

        // Verify domain ownership
        $stmt = $pdo->prepare("SELECT id FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $user_id]);
        if (!$stmt->fetch()) {
            header('Location: ' . basename(__FILE__) . '?error=' . urlencode('Domain not found or unauthorized.'));
            exit;
        }

        // Validate cert + key
        $validation_result = validate_ssl_certificate($certificate, $private_key);
        if ($validation_result !== true) {
            header('Location: ' . basename(__FILE__) . '?error=' . urlencode($validation_result));
            exit;
        }

        $expires_at = get_certificate_expiry_from_pem($certificate) ?? date('Y-m-d H:i:s', strtotime('+90 days'));

        if (save_ssl_certificate_db($pdo, $domain_id, $certificate, $private_key, $ca_bundle, $expires_at, $auto_renew)) {
            header('Location: ' . basename(__FILE__) . '?success=' . urlencode('SSL certificate uploaded successfully.'));
        } else {
            header('Location: ' . basename(__FILE__) . '?error=' . urlencode('Failed to save certificate.'));
        }
        exit;
    }

    if ($action === 'auto_ssl') {
        $domain_id = filter_input(INPUT_POST, 'domain_id', FILTER_VALIDATE_INT);

        $stmt = $pdo->prepare("SELECT id FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $user_id]);
        if (!$stmt->fetch()) {
            header('Location: ' . basename(__FILE__) . '?error=' . urlencode('Domain not found or unauthorized.'));
            exit;
        }

        // Demo placeholder values
        $certificate = "-----BEGIN CERTIFICATE-----\n(Placeholder for Auto-Generated Certificate)\n-----END CERTIFICATE-----";
        $private_key = "-----BEGIN PRIVATE KEY-----\n(Placeholder for Auto-Generated Private Key)\n-----END PRIVATE KEY-----";
        $expires_at  = date('Y-m-d H:i:s', strtotime('+90 days'));

        if (save_ssl_certificate_db($pdo, $domain_id, $certificate, $private_key, '', $expires_at, true)) {
            header('Location: ' . basename(__FILE__) . '?success=' . urlencode('AutoSSL placeholder generated successfully.'));
        } else {
            header('Location: ' . basename(__FILE__) . '?error=' . urlencode('Failed to generate placeholder.'));
        }
        exit;
    }

    // AJAX actions
    if (!empty($_POST['ajax'])) {
        header('Content-Type: application/json');
        $response = ['error' => 'Invalid AJAX action.'];

        if ($action === 'renew') {
            $cert_id  = filter_input(INPUT_POST, 'cert_id', FILTER_VALIDATE_INT);
            $response = renew_certificate_db($pdo, $cert_id, $user_id);

        } elseif ($action === 'delete') {
            $cert_id  = filter_input(INPUT_POST, 'cert_id', FILTER_VALIDATE_INT);
            $response = delete_certificate_db($pdo, $cert_id, $user_id)
                ? ['success' => 'Certificate deleted successfully.']
                : ['error'   => 'Delete failed or unauthorized.'];

        } elseif ($action === 'view') {
            $cert_id = filter_input(INPUT_POST, 'cert_id', FILTER_VALIDATE_INT);

            $stmt = $pdo->prepare("SELECT sc.*, d.domain_name
                                   FROM ssl_certificates sc
                                   JOIN domains d ON sc.domain_id = d.id
                                   WHERE sc.id = ? AND d.user_id = ?");
            $stmt->execute([$cert_id, $user_id]);
            $cert_data = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($cert_data) {
                $response = [
                    'domain'      => htmlspecialchars($cert_data['domain_name']),
                    'certificate' => decrypt_data($cert_data['certificate']),
                    'private_key' => decrypt_data($cert_data['private_key']),
                    'ca_bundle'   => decrypt_data($cert_data['ca_bundle']),
                    'expires_at'  => date('Y-m-d H:i', strtotime($cert_data['expires_at'])),
                ];
            } else {
                $response = ['error' => 'Certificate not found or unauthorized.'];
            }
        }

        echo json_encode($response);
        exit;
    }
}

// ---------------------------
// Prepare Data for Page Render
// ---------------------------

// Domains for dropdowns
$domains      = get_user_domains($user_id);
$certificates = get_user_certificates($pdo, $user_id);

// Flash messages (no deprecated FILTER_SANITIZE_STRING)
$flash_success = $_GET['success'] ?? null;
$flash_error   = $_GET['error']   ?? null;

$token = csrf_token();

function get_cert_status_badge($expires_at) {
    $expires_ts = strtotime($expires_at);
    $days_left  = floor(($expires_ts - time()) / (60 * 60 * 24));

    if ($days_left > 30) {
        return '<span class="badge badge-success">Valid (' . $days_left . ' days)</span>';
    } elseif ($days_left >= 0) {
        return '<span class="badge badge-warning">Expiring Soon (' . $days_left . ' days)</span>';
    }
    return '<span class="badge badge-danger">Expired</span>';
}
?>

<style>
    .card { background: var(--bg-card); border-radius: var(--radius-lg); box-shadow: var(--shadow-soft); border: 1px solid var(--border-soft); margin-bottom: 18px; }
    .card-header { padding: 12px 16px; border-bottom: 1px solid var(--border-soft); display: flex; justify-content: space-between; align-items: center; }
    .card-title { font-size: 15px; font-weight: 500; }
    .card-subtitle { font-size: 12px; color: var(--text-muted); }
    .card-body { padding: 16px 16px 18px; }
    .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px 18px; }
    .form-group { display: flex; flex-direction: column; gap: 4px; }
    label { font-size: 13px; font-weight: 500; }
    .field-hint { font-size: 11px; color: var(--text-muted); }
    input[type="text"], select, textarea { width: 100%; padding: 8px 9px; border-radius: 8px; border: 1px solid #d1d5db; font-size: 13px; outline: none; transition: all 0.12s ease; background: #ffffff; }
    input[type="text"]:focus, select:focus, textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 1px var(--primary-soft); }
    textarea { font-family: monospace; resize: vertical; }
    .form-actions { margin-top: 14px; display: flex; justify-content: flex-end; }
    .btn { padding: 8px 16px; border-radius: 999px; border: none; cursor: pointer; font-size: 13px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; transition: background-color 0.15s ease; }
    .btn-primary { background: var(--primary); color: #ffffff; }
    .btn-primary:hover { background: var(--primary-dark); }
    .btn-danger { background: var(--danger); color: #ffffff; }
    .btn-danger:hover { background: #b91c1c; }
    .btn-secondary { background: #e5e7eb; color: #374151; }
    .btn-secondary:hover { background: #d1d5db; }
    .btn-sm { padding: 6px 12px; font-size: 12px; }
    .table-wrapper { width: 100%; overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 10px 10px; text-align: left; border-bottom: 1px solid var(--border-soft); white-space: nowrap; }
    th { font-weight: 500; color: var(--text-muted); background: #f9fafb; }
    tr:hover td { background: #f9fafb; }
    .badge { display: inline-block; padding: 3px 8px; font-size: 11px; border-radius: 999px; font-weight:500; }
    .badge-success { background: #ecfdf3; color: #166534; border: 1px solid #bbf7d0; }
    .badge-warning { background: var(--warning-soft); color: #9a3412; border: 1px solid #fdba74; }
    .badge-danger { background: var(--danger-soft); color: #991b1b; border: 1px solid #fecaca; }
    .badge-muted { background: #f3f4f6; color: var(--text-muted); border: 1px solid #e5e7eb; }
    .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; overflow: auto; background-color: rgba(17, 24, 39, 0.5); align-items: center; justify-content: center; backdrop-filter: blur(4px); }
    .modal-content { background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-soft); width: 90%; max-width: 800px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: var(--shadow-soft); }
    .modal-header { padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-soft); }
    .modal-title { font-size: 15px; font-weight: 500; }
    .modal-body { padding: 16px; overflow-y: auto; }
    .modal-body pre { background: #f3f4f6; padding: 10px; border-radius: 8px; white-space: pre-wrap; word-break: break-all; font-size: 12px; border: 1px solid var(--border-soft); }
    @media (max-width: 840px) {
        .sidebar { display: none; }
        .main-content { margin-left: 0; padding: 14px; }
        .header { flex-direction: column; align-items: flex-start; }
        .header-right { justify-content: space-between; width: 100%; }
    }
</style>

<main class="main-content">
    <div class="page-container">
        <!-- PAGE HEADER -->
        <section class="header">
            <div class="header-left">
                <div class="page-title">SSL Certificate Management</div>
                <div class="page-subtitle">Upload, generate, and manage SSL certificates for your domains.</div>
            </div>
            <div class="header-right">
                <span class="chip chip-live">● Session Active</span>
                <div class="user-info">
                    <div class="user-avatar">
                        <?= htmlspecialchars(strtoupper(substr($_SESSION['username'] ?? 'U', 0, 1))); ?>
                    </div>
                    <div class="user-meta">
                        <span class="user-name"><?= htmlspecialchars($_SESSION['username'] ?? 'User'); ?></span>
                        <span class="user-role"><?= is_admin() ? 'Administrator' : 'User'; ?></span>
                    </div>
                </div>
            </div>
        </section>

        <!-- ALERTS -->
        <?php if ($flash_success): ?>
            <div class="alert alert-success"><?= htmlspecialchars($flash_success); ?></div>
        <?php endif; ?>

        <?php if ($flash_error): ?>
            <div class="alert alert-danger"><?= htmlspecialchars($flash_error); ?></div>
        <?php endif; ?>

        <!-- AutoSSL demo card -->
        <section class="card">
            <div class="card-header">
                <div>
                    <div class="card-title">AutoSSL (Let's Encrypt - Placeholder)</div>
                    <div class="card-subtitle">This is a demo for future ACME client integration.</div>
                </div>
            </div>
            <div class="card-body">
                <form method="post">
                    <input type="hidden" name="action" value="auto_ssl">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($token) ?>">
                    <div class="form-group">
                        <label for="domain_id_auto">Domain</label>
                        <select name="domain_id" id="domain_id_auto" required>
                            <option value="">-- Select a Domain --</option>
                            <?php foreach ($domains as $d): ?>
                                <option value="<?= (int)$d['id'] ?>"><?= htmlspecialchars($d['domain_name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="form-actions">
                        <button type="submit" class="btn btn-secondary">
                            ⚡ Generate Certificate (Demo)
                        </button>
                    </div>
                </form>
            </div>
        </section>

        <!-- Installed certificates list -->
        <section class="card">
            <div class="card-header">
                <div>
                    <div class="card-title">Installed Certificates</div>
                    <div class="card-subtitle">List of all SSL certificates currently linked to your domains.</div>
                </div>
            </div>
            <div class="card-body">
                <?php if (empty($certificates)): ?>
                    <p style="font-size: 13px; color: var(--text-muted);">
                        You haven't installed any SSL certificates yet.
                    </p>
                <?php else: ?>
                    <div class="table-wrapper">
                        <table>
                            <thead>
                            <tr>
                                <th>Domain Name</th>
                                <th>Expires On</th>
                                <th>Status</th>
                                <th>Auto Renew</th>
                                <th>Actions</th>
                            </tr>
                            </thead>
                            <tbody>
                            <?php foreach ($certificates as $cert): ?>
                                <tr id="cert-row-<?= (int)$cert['id'] ?>">
                                    <td><?= htmlspecialchars($cert['domain_name']); ?></td>
                                    <td><?= htmlspecialchars(date('M j, Y', strtotime($cert['expires_at']))) ?></td>
                                    <td><?= get_cert_status_badge($cert['expires_at']); ?></td>
                                    <td><?= $cert['auto_renew'] ? 'Yes' : 'No'; ?></td>
                                    <td>
                                        <button onclick="viewCertificate(<?= (int)$cert['id'] ?>)" class="btn btn-secondary btn-sm">👁️ View</button>
                                        <button onclick="renewCertificate(<?= (int)$cert['id'] ?>)" class="btn btn-primary btn-sm">♻️ Renew</button>
                                        <button onclick="deleteCertificate(<?= (int)$cert['id'] ?>)" class="btn btn-danger btn-sm">🗑️ Delete</button>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </section>

        <!-- Upload existing certificate -->
        <section class="card">
            <div class="card-header">
                <div>
                    <div class="card-title">Upload Existing Certificate</div>
                    <div class="card-subtitle">Manually provide a PEM certificate, private key, and optional CA bundle.</div>
                </div>
            </div>
            <div class="card-body">
                <form method="post">
                    <input type="hidden" name="action" value="upload">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($token) ?>">

                    <div class="form-group">
                        <label for="domain_id_upload">Domain</label>
                        <select id="domain_id_upload" name="domain_id" required>
                            <option value="">-- Select a Domain --</option>
                            <?php foreach ($domains as $d): ?>
                                <option value="<?= (int)$d['id'] ?>"><?= htmlspecialchars($d['domain_name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-grid" style="grid-template-columns: 1fr 1fr; margin-top:14px;">
                        <div class="form-group">
                            <label for="certificate">Certificate (PEM)</label>
                            <textarea name="certificate" id="certificate" rows="7" required placeholder="-----BEGIN CERTIFICATE-----..."></textarea>
                        </div>
                        <div class="form-group">
                            <label for="private_key">Private Key (PEM)</label>
                            <textarea name="private_key" id="private_key" rows="7" required placeholder="-----BEGIN PRIVATE KEY-----..."></textarea>
                        </div>
                    </div>

                    <div class="form-group" style="margin-top:14px;">
                        <label for="ca_bundle">CA Bundle / Chain (Optional)</label>
                        <textarea name="ca_bundle" id="ca_bundle" rows="5" placeholder="Your certificate authority's intermediate certificates..."></textarea>
                    </div>

                    <div class="form-actions">
                        <button type="submit" class="btn btn-primary">➕ Upload Certificate</button>
                    </div>
                </form>
            </div>
        </section>
    </div>
</main>

<!-- Modal for Viewing Certificate Details -->
<div id="viewModal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <div class="modal-title">Certificate Details</div>
            <button onclick="closeModal()" class="btn btn-sm btn-secondary" style="border-radius:50%; padding:4px 8px;">&times;</button>
        </div>
        <div id="modal-body" class="modal-body">
            <p><strong>Domain:</strong> <span id="modal-domain"></span></p>
            <p><strong>Expires At:</strong> <span id="modal-expires"></span></p>

            <h4 style="margin-top:15px; margin-bottom:5px;">Certificate</h4>
            <pre id="modal-cert"></pre>

            <h4 style="margin-top:15px; margin-bottom:5px;">
                Private Key
                <label style="font-size:0.8em; font-weight:normal; cursor:pointer;">
                    <input type="checkbox" id="toggleKey"> Show
                </label>
            </h4>
            <pre id="modal-key" style="display:none;"></pre>

            <h4 style="margin-top:15px; margin-bottom:5px;">CA Bundle</h4>
            <pre id="modal-ca"></pre>
        </div>
    </div>
</div>

<script>
    const CSRF_TOKEN = <?= json_encode($token) ?>;
    const SCRIPT_NAME = '<?= htmlspecialchars(basename(__FILE__)) ?>';

    async function postAjax(data) {
        const formData = new URLSearchParams({ ...data, 'csrf_token': CSRF_TOKEN, 'ajax': 1 });

        try {
            const response = await fetch(SCRIPT_NAME, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: formData
            });

            if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

            return await response.json();
        } catch (error) {
            console.error('AJAX Error:', error);
            alert('An unexpected error occurred. Please check the console and try again.');
            return { error: 'Network or server error.' };
        }
    }

    async function viewCertificate(certId) {
        const res = await postAjax({ action: 'view', cert_id: certId });
        if (res.error) { alert(res.error); return; }

        document.getElementById('modal-domain').textContent  = res.domain || 'N/A';
        document.getElementById('modal-expires').textContent = res.expires_at || 'N/A';
        document.getElementById('modal-cert').textContent    = res.certificate || 'Not available.';
        document.getElementById('modal-key').textContent     = res.private_key || 'Not available.';
        document.getElementById('modal-ca').textContent      = res.ca_bundle || 'Not provided.';

        document.getElementById('toggleKey').checked = false;
        document.getElementById('modal-key').style.display = 'none';
        document.getElementById('viewModal').style.display = 'flex';
    }

    function closeModal() {
        document.getElementById('viewModal').style.display = 'none';
    }

    async function renewCertificate(certId) {
        if (!confirm('This is a demo renewal that will extend the expiry by 90 days. Proceed?')) return;
        const res = await postAjax({ action: 'renew', cert_id: certId });
        if (res.error) { alert(res.error); }
        else { alert(res.success); window.location.reload(); }
    }

    async function deleteCertificate(certId) {
        if (!confirm('Are you sure you want to permanently delete this SSL certificate?')) return;
        const res = await postAjax({ action: 'delete', cert_id: certId });
        if (res.error) { alert(res.error); }
        else {
            alert(res.success);
            const row = document.getElementById(`cert-row-${certId}`);
            if (row) row.remove();
        }
    }

    const modal = document.getElementById('viewModal');
    document.getElementById('toggleKey')?.addEventListener('change', function () {
        document.getElementById('modal-key').style.display = this.checked ? 'block' : 'none';
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && modal.style.display === 'flex') {
            closeModal();
        }
    });

    modal.addEventListener('click', (event) => {
        if (event.target === modal) {
            closeModal();
        }
    });
</script>
