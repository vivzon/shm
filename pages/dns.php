<?php
// dns.php: Themed DNS Record Management for SHM Panel.

require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php'; // Contains get_user_domains() and others

// Enforce authentication and permissions
require_login();
check_permission('dns_management');

// Get user domains for the selection dropdown
$domains = get_user_domains($_SESSION['user_id']);
$selected_domain = null;
$dns_records = [];
$domain_id_get = filter_input(INPUT_GET, 'domain_id', FILTER_VALIDATE_INT);

if ($domain_id_get) {
    // Verify domain ownership before showing any records
    $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
    $stmt->execute([$domain_id_get, $_SESSION['user_id']]);
    $selected_domain = $stmt->fetch();

    if ($selected_domain) {
        // Ownership verified, get the DNS records
        $dns_records = get_dns_records($selected_domain['id']);
    }
}

// Handle DNS record operations (Add/Delete)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_record'])) {
        $domain_id    = filter_input(INPUT_POST, 'domain_id', FILTER_VALIDATE_INT);
        $record_type  = sanitize_input($_POST['record_type']);
        $record_name  = sanitize_input($_POST['record_name']);
        $record_value = sanitize_input($_POST['record_value']); // Value can be complex, basic trim/htmlspecialchars is enough
        $ttl          = filter_input(INPUT_POST, 'ttl', FILTER_VALIDATE_INT);
        $priority     = ($record_type === 'MX') ? filter_input(INPUT_POST, 'priority', FILTER_VALIDATE_INT) : null;

        // Verify domain ownership again for the POST request
        $stmt = $pdo->prepare("SELECT id FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        if ($stmt->fetch()) {
            if (add_dns_record($domain_id, $record_type, $record_name, $record_value, $ttl, $priority)) {
                header('Location: dns.php?domain_id=' . $domain_id . '&success=' . urlencode('DNS record added successfully'));
                exit;
            }
        }
    }

    if (isset($_POST['delete_record'])) {
        $record_id = filter_input(INPUT_POST, 'record_id', FILTER_VALIDATE_INT);
        $domain_id = filter_input(INPUT_POST, 'domain_id', FILTER_VALIDATE_INT);

        // Verify ownership by checking if the record belongs to a domain owned by the user
        $stmt = $pdo->prepare("SELECT d.id FROM dns_records dr JOIN domains d ON dr.domain_id = d.id WHERE dr.id = ? AND d.user_id = ?");
        $stmt->execute([$record_id, $_SESSION['user_id']]);
        if ($stmt->fetch()) {
            $delete_stmt = $pdo->prepare("DELETE FROM dns_records WHERE id = ?");
            $delete_stmt->execute([$record_id]);
            header('Location: dns.php?domain_id=' . $domain_id . '&success=' . urlencode('DNS record deleted successfully'));
            exit;
        }
    }
}

// Get flash messages for alerts
$flash_success = $_GET['success'] ?? null;
$flash_error = $_GET['error'] ?? null;

// Helper function for styling record type badges
function get_record_type_badge($type) {
    $type = strtoupper($type);
    $class = 'badge-muted'; // Default
    switch ($type) {
        case 'A':
        case 'AAAA':
            $class = 'badge-primary'; // Custom badge class added in CSS
            break;
        case 'CNAME':
            $class = 'badge-info'; // Custom badge class
            break;

        case 'MX':
            $class = 'badge-warning';
            break;
        case 'TXT':
            $class = 'badge-secondary'; // Custom badge class
            break;
        case 'NS':
            $class = 'badge-success';
            break;
    }
    return '<span class="badge ' . $class . '">' . htmlspecialchars($type) . '</span>';
}
?>
<?php include '../includes/header.php'; ?>

    <style>
        .card { background: var(--bg-card); border-radius: var(--radius-lg); box-shadow: var(--shadow-soft); border: 1px solid var(--border-soft); margin-bottom: 18px; }
        .card-header { padding: 12px 16px; border-bottom: 1px solid var(--border-soft); }
        .card-title { font-size: 15px; font-weight: 500; }
        .card-subtitle { font-size: 12px; color: var(--text-muted); }
        .card-body { padding: 16px 16px 18px; }
        .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px 18px; }
        .form-group { display: flex; flex-direction: column; gap: 4px; }
        label { font-size: 13px; font-weight: 500; }
        input, select { width: 100%; padding: 8px 9px; border-radius: 8px; border: 1px solid #d1d5db; font-size: 13px; outline: none; transition: all 0.12s ease; background: #ffffff; }
        input:focus, select:focus { border-color: var(--primary); box-shadow: 0 0 0 1px var(--primary-soft); }
        .form-actions { margin-top: 14px; display: flex; justify-content: flex-end; }
        .btn { padding: 8px 16px; border-radius: 999px; border: none; cursor: pointer; font-size: 13px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; }
        .btn-primary { background: var(--primary); color: #ffffff; }
        .btn-danger { background: var(--danger); color: #ffffff; }
        .btn-sm { padding: 6px 12px; font-size: 12px; }
        .table-wrapper { width: 100%; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 10px 10px; text-align: left; border-bottom: 1px solid var(--border-soft); white-space: nowrap; }
        th { font-weight: 500; color: var(--text-muted); background: #f9fafb; }
        td.record-value { word-break: break-all; white-space: normal; } /* For long TXT records */
        .badge { display: inline-block; padding: 3px 8px; font-size: 11px; border-radius: 999px; font-weight:500; }
        .badge-success { background: #ecfdf3; color: #166534; border: 1px solid #bbf7d0; }
        .badge-warning { background: var(--warning-soft); color: #9a3412; border: 1px solid #fdba74; }
        .badge-danger { background: var(--danger-soft); color: #991b1b; border: 1px solid #fecaca; }
        .badge-info { background: var(--info-soft); color: #1e40af; border: 1px solid #bfdbfe; }
        .badge-primary { background: var(--primary-soft); color: var(--primary-dark); border: 1px solid #bfdbfe; }
        .badge-secondary { background: var(--secondary-soft); color: var(--secondary); border: 1px solid #e5e7eb; }
        @media (max-width: 840px) { .sidebar { display: none; } .main-content { margin-left: 0; padding: 14px; } }
    </style>
    
    <main class="main-content">
        <div class="page-container">
            <!-- PAGE HEADER -->
            <section class="header">
                <div class="header-left">
                    <div class="page-title">DNS Management</div>
                    <div class="page-subtitle">Add and manage DNS records for your domains.</div>
                </div>
                <div class="header-right">
                    <div class="user-info">
                        <div class="user-avatar"><?= htmlspecialchars(strtoupper(substr($_SESSION['username'] ?? 'U', 0, 1))); ?></div>
                        <div>
                            <span class="user-name"><?= htmlspecialchars($_SESSION['username']); ?></span>
                            <div class="user-role"><?= is_admin() ? 'Administrator' : 'User'; ?></div>
                        </div>
                    </div>
                </div>
            </section>

            <!-- ALERTS -->
            <?php if ($flash_success): ?><div class="alert alert-success"><?= htmlspecialchars($flash_success); ?></div><?php endif; ?>
            <?php if ($flash_error): ?><div class="alert alert-danger"><?= htmlspecialchars($flash_error); ?></div><?php endif; ?>

            <!-- SELECT DOMAIN -->
            <section class="card">
                <div class="card-header">
                    <div class="card-title">Select a Domain to Manage</div>
                </div>
                <div class="card-body">
                    <form method="get" action="dns.php">
                        <div class="form-group">
                            <select name="domain_id" onchange="this.form.submit()">
                                <option value="">-- Select Domain --</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?= (int)$domain['id']; ?>" <?= ($selected_domain && $selected_domain['id'] == $domain['id']) ? 'selected' : ''; ?>>
                                    <?= htmlspecialchars($domain['domain_name']); ?>
                                </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </form>
                </div>
            </section>

            <?php if ($selected_domain): ?>
            <!-- ADD DNS RECORD -->
            <section class="card">
                <div class="card-header">
                    <div class="card-title">Add DNS Record</div>
                    <div class="card-subtitle">For <?= htmlspecialchars($selected_domain['domain_name']) ?></div>
                </div>
                <div class="card-body">
                    <form method="post" action="dns.php?domain_id=<?= (int)$selected_domain['id'] ?>">
                        <input type="hidden" name="domain_id" value="<?= (int)$selected_domain['id']; ?>">
                        <div class="form-grid">
                            <div class="form-group">
                                <label for="recordType">Type</label>
                                <select name="record_type" id="recordType" onchange="togglePriorityField()">
                                    <option value="A">A (Address)</option>
                                    <option value="AAAA">AAAA (IPv6 Address)</option>
                                    <option value="CNAME">CNAME (Canonical Name)</option>
                                    <option value="MX">MX (Mail Exchange)</option>
                                    <option value="TXT">TXT (Text)</option>
                                    <option value="NS">NS (Name Server)</option>
                                </select>
                            </div>
                             <div class="form-group">
                                <label for="record_name">Name</label>
                                <input type="text" id="record_name" name="record_name" placeholder="@ for root, www, etc." required>
                            </div>
                            <div class="form-group">
                                <label for="record_value">Value</label>
                                <input type="text" id="record_value" name="record_value" placeholder="e.g., 192.168.1.1" required>
                            </div>
                            <div class="form-group" id="priorityField" style="display: none;">
                                <label for="priority">Priority</label>
                                <input type="number" id="priority" name="priority" value="10" min="0">
                            </div>
                            <div class="form-group">
                                <label for="ttl">TTL</label>
                                <select name="ttl" id="ttl">
                                    <option value="300">5 minutes</option>
                                    <option value="1800">30 minutes</option>
                                    <option value="3600" selected>1 hour</option>
                                    <option value="86400">1 day</option>
                                </select>
                            </div>
                        </div>
                        <div class="form-actions">
                            <button type="submit" name="add_record" class="btn btn-primary">➕ Add Record</button>
                        </div>
                    </form>
                </div>
            </section>

            <!-- DNS RECORDS LIST -->
            <section class="card">
                <div class="card-header">
                    <div class="card-title">Current DNS Records</div>
                    <div class="card-subtitle">For <?= htmlspecialchars($selected_domain['domain_name']) ?></div>
                </div>
                <div class="card-body">
                    <?php if (empty($dns_records)): ?>
                        <p style="font-size: 13px; color: var(--text-muted);">No DNS records found for this domain.</p>
                    <?php else: ?>
                        <div class="table-wrapper">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Type</th>
                                        <th>Name</th>
                                        <th>Value</th>
                                        <th>TTL</th>
                                        <th>Priority</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($dns_records as $record): ?>
                                    <tr>
                                        <td><?= get_record_type_badge($record['record_type']); ?></td>
                                        <td><?= htmlspecialchars($record['record_name']); ?></td>
                                        <td class="record-value"><?= htmlspecialchars($record['record_value']); ?></td>
                                        <td><?= htmlspecialchars($record['ttl']); ?></td>
                                        <td><?= $record['priority'] ?? '-'; ?></td>
                                        <td>
                                            <form method="post" onsubmit="return confirm('Are you sure you want to delete this DNS record?');">
                                                <input type="hidden" name="domain_id" value="<?= (int)$selected_domain['id']; ?>">
                                                <input type="hidden" name="record_id" value="<?= (int)$record['id']; ?>">
                                                <button type="submit" name="delete_record" class="btn btn-danger btn-sm">🗑️ Delete</button>
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
            <?php endif; ?>
        </div>
    </main>

    <script>
        function togglePriorityField() {
            const recordType = document.getElementById('recordType').value;
            const priorityField = document.getElementById('priorityField');
            priorityField.style.display = (recordType === 'MX') ? 'block' : 'none';
        }
        // Run on page load in case the page reloads with MX selected
        document.addEventListener('DOMContentLoaded', togglePriorityField);
    </script>

<?php include '../includes/footer.php'; ?>