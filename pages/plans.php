<?php
// plans.php: Admin page for managing hosting subscription plans.
// This version uses PDO to match the current config.php standard.

require_once '../includes/config.php'; // This provides the $pdo connection object.
require_once '../includes/auth.php';

// This is a critical management page, so only admins can access it.
require_admin();

// --- Main POST Request Handler ---
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    
    // Sanitize all common inputs
    $plan_id        = filter_input(INPUT_POST, 'plan_id', FILTER_VALIDATE_INT);
    $name           = sanitize_input($_POST['name'] ?? '');
    $disk_space     = filter_input(INPUT_POST, 'disk_space_mb', FILTER_VALIDATE_INT);
    $bandwidth      = filter_input(INPUT_POST, 'bandwidth_gb', FILTER_VALIDATE_INT);
    $max_domains    = filter_input(INPUT_POST, 'max_domains', FILTER_VALIDATE_INT);
    $max_databases  = filter_input(INPUT_POST, 'max_databases', FILTER_VALIDATE_INT);
    $max_emails     = filter_input(INPUT_POST, 'max_emails', FILTER_VALIDATE_INT);
    $price_monthly  = filter_input(INPUT_POST, 'price_monthly', FILTER_VALIDATE_FLOAT);
    $price_annually = filter_input(INPUT_POST, 'price_annually', FILTER_VALIDATE_FLOAT);
    $is_visible     = isset($_POST['is_visible']) ? 1 : 0;

    try {
        switch ($_POST['action']) {
            // --- ADD PLAN ---
            case 'add_plan':
                $sql = "INSERT INTO hosting_plans (name, disk_space_mb, bandwidth_gb, max_domains, max_databases, max_emails, price_monthly, price_annually, is_visible) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $pdo->prepare($sql);
                $stmt->execute([$name, $disk_space, $bandwidth, $max_domains, $max_databases, $max_emails, $price_monthly, $price_annually, $is_visible]);
                header('Location: plans.php?success=' . urlencode('New hosting plan created successfully!'));
                exit;

            // --- UPDATE PLAN ---
            case 'update_plan':
                $sql = "UPDATE hosting_plans SET name=?, disk_space_mb=?, bandwidth_gb=?, max_domains=?, max_databases=?, max_emails=?, price_monthly=?, price_annually=?, is_visible=? WHERE id=?";
                $stmt = $pdo->prepare($sql);
                $stmt->execute([$name, $disk_space, $bandwidth, $max_domains, $max_databases, $max_emails, $price_monthly, $price_annually, $is_visible, $plan_id]);
                header('Location: plans.php?success=' . urlencode('Hosting plan updated successfully!'));
                exit;

            // --- DELETE PLAN ---
            case 'delete_plan':
                $sql = "DELETE FROM hosting_plans WHERE id = ?";
                $stmt = $pdo->prepare($sql);
                $stmt->execute([$plan_id]);
                header('Location: plans.php?success=' . urlencode('Hosting plan deleted successfully.'));
                exit;
        }
    } catch (PDOException $e) {
        // Redirect with a generic error message if any database operation fails
        header('Location: plans.php?error=' . urlencode('A database error occurred.'));
        exit;
    }
}

// --- Data Fetching for Page Display using PDO ---
$stmt = $pdo->query("SELECT * FROM hosting_plans ORDER BY price_monthly ASC");
$plans = $stmt->fetchAll(PDO::FETCH_ASSOC);

$flash_success = $_GET['success'] ?? null;
$flash_error = $_GET['error'] ?? null;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Subscription Plans - SHM Panel</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600&display=swap" rel="stylesheet">
    <style>
        /* Your beautiful theme CSS is unchanged */
        :root {
            --bg-body: #f3f4f6; --bg-sidebar: #ffffff; --bg-header: #ffffff; --bg-card: #ffffff;
            --border-soft: #e5e7eb; --primary: #2563eb; --primary-soft: #dbeafe; --primary-dark: #1d4ed8;
            --text-main: #111827; --text-muted: #6b7280; --danger: #ef4444; --danger-soft: #fee2e2;
            --success: #16a34a; --radius-lg: 14px; --shadow-soft: 0 10px 25px rgba(15, 23, 42, 0.06);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Poppins', sans-serif; background: var(--bg-body); color: var(--text-main); display: flex; }
        .sidebar { position: fixed; left: 0; top: 0; width: 240px; height: 100vh; background: var(--bg-sidebar); border-right: 1px solid var(--border-soft); padding: 18px; display: flex; flex-direction: column; gap: 16px; }
        .sidebar-brand { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
        .brand-logo { width: 34px; height: 34px; border-radius: 10px; background: var(--primary-soft); color: var(--primary-dark); display: flex; align-items: center; justify-content: center; font-weight: 600; font-size: 18px; }
        .brand-text { display: flex; flex-direction: column; }
        .brand-title { font-size: 16px; font-weight: 600; }
        .brand-subtitle { font-size: 11px; color: var(--text-muted); }
        .sidebar-section-title { font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin: 10px 0 6px; letter-spacing: .08em; }
        .sidebar ul { list-style: none; display: flex; flex-direction: column; gap: 4px; }
        .sidebar a { display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 8px; text-decoration: none; color: var(--text-muted); font-size: 13px; transition: all 0.16s ease; }
        .nav-icon { width: 26px; display: inline-flex; justify-content: center; }
        .sidebar a:hover { background: #eff6ff; color: var(--primary-dark); transform: translateX(1px); }
        .sidebar a.active { background: var(--primary-soft); color: var(--primary-dark); font-weight: 500; }
        .sidebar-footer { margin-top: auto; padding-top: 12px; border-top: 1px solid var(--border-soft); font-size: 11px; color: var(--text-muted); }
        .main-content { margin-left: 240px; flex: 1; padding: 20px 22px 24px; }
        .header { background: var(--bg-header); border-radius: 12px; padding: 14px 16px; border: 1px solid var(--border-soft); box-shadow: var(--shadow-soft); margin-bottom: 18px; display: flex; justify-content: space-between; align-items: center; gap: 14px; }
        .header-left { display: flex; flex-direction: column; gap: 4px; }
        .page-title { font-size: 20px; font-weight: 600; }
        .page-subtitle { font-size: 13px; color: var(--text-muted); }
        .header-right { display: flex; align-items: center; gap: 12px; }
        .user-info { display: flex; align-items: center; gap: 8px; }
        .user-avatar { width: 30px; height: 30px; border-radius: 999px; background: var(--primary-soft); color: var(--primary-dark); font-weight: 600; font-size: 14px; display: flex; align-items: center; justify-content: center; }
        .user-name { font-size: 13px; font-weight: 500; }
        .user-role { font-size: 11px; color: var(--text-muted); }
        .page-container { max-width: 1180px; margin: 0 auto; }
        .alert { border-radius: 8px; padding: 10px 12px; margin-bottom: 16px; font-size: 13px; }
        .alert-success { background: #ecfdf3; border: 1px solid #bbf7d0; color: #166534; }
        .alert-danger { background: var(--danger-soft); border: 1px solid #fecaca; color: #991b1b; }
        .card { background: var(--bg-card); border-radius: var(--radius-lg); box-shadow: var(--shadow-soft); border: 1px solid var(--border-soft); margin-bottom: 18px; }
        .card-header { padding: 12px 16px; border-bottom: 1px solid var(--border-soft); }
        .card-title { font-size: 15px; font-weight: 500; }
        .card-body { padding: 16px 16px 18px; }
        .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px 18px; }
        .form-group { display: flex; flex-direction: column; gap: 4px; }
        label { font-size: 13px; font-weight: 500; }
        .field-hint { font-size: 11px; color: var(--text-muted); }
        input, select { width: 100%; padding: 8px 9px; border-radius: 8px; border: 1px solid #d1d5db; font-size: 13px; outline: none; transition: all 0.12s ease; background: #ffffff; }
        input:focus, select:focus { border-color: var(--primary); box-shadow: 0 0 0 1px var(--primary-soft); }
        .form-actions { margin-top: 14px; display: flex; justify-content: flex-end; }
        .btn { padding: 8px 16px; border-radius: 999px; border: none; cursor: pointer; font-size: 13px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; }
        .btn-primary { background: var(--primary); color: #ffffff; }
        .btn-secondary { background: #e5e7eb; color: #374151; }
        .btn-danger { background: var(--danger); color: #ffffff; }
        .btn-sm { padding: 6px 12px; font-size: 12px; }
        .table-wrapper { width: 100%; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid var(--border-soft); white-space: nowrap; }
        th { font-weight: 500; color: var(--text-muted); background: #f9fafb; }
        tr:hover td { background: #f9fafb; }
        .badge { display: inline-block; padding: 3px 8px; font-size: 11px; border-radius: 999px; font-weight:500; }
        .badge-success { background: #ecfdf3; color: #166534; border: 1px solid #bbf7d0; }
        .badge-muted { background: #f3f4f6; color: var(--text-muted); border: 1px solid #e5e7eb; }
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; overflow: auto; background-color: rgba(17, 24, 39, 0.5); align-items: center; justify-content: center; backdrop-filter: blur(4px); }
        .modal-content { background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-soft); width: 90%; max-width: 900px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: var(--shadow-soft); }
        .modal-header { padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-soft); }
        .modal-title { font-size: 15px; font-weight: 500; }
        .modal-body { padding: 16px; overflow-y: auto; }
        .checkbox label { display: flex; gap: 8px; align-items: center; margin-bottom: 7px; }
        .checkbox label input{ width:auto!important; }
        @media (max-width: 840px) { .sidebar { display: none; } .main-content { margin-left: 0; padding: 14px; } }
    </style>
</head>
<body>

    <aside class="sidebar">
        <!-- Sidebar HTML is unchanged -->
        <div>
            <div class="sidebar-brand">
                <div class="brand-logo">S</div>
                <div class="brand-text"><div class="brand-title">SHM Panel</div><div class="brand-subtitle">Simple Hosting Manager</div></div>
            </div>
            <div class="sidebar-section-title">Main Menu</div>
            <ul>
                <li><a href="dashboard.php"><span class="nav-icon">🏠</span><span>Dashboard</span></a></li>
                <?php if (has_permission('domain_management')): ?><li><a href="domains.php"><span class="nav-icon">🌐</span><span>Domains</span></a></li><?php endif; ?>
                <?php if (has_permission('file_management')): ?><li><a href="files.php"><span class="nav-icon">📁</span><span>Files</span></a></li><?php endif; ?>
                <?php if (has_permission('database_management')): ?><li><a href="database.php"><span class="nav-icon">🗄️</span><span>Databases</span></a></li><?php endif; ?>
                <?php if (has_permission('ssl_management')): ?><li><a href="ssl.php"><span class="nav-icon">🔐</span><span>SSL</span></a></li><?php endif; ?>
                <?php if (has_permission('dns_management')): ?><li><a href="dns.php"><span class="nav-icon">📡</span><span>DNS</span></a></li><?php endif; ?>
                <?php if (is_admin()): ?>
                    <li><a href="users.php"><span class="nav-icon">👥</span><span>Users</span></a></li>
                    <li><a href="plans.php" class="active"><span class="nav-icon">💳</span><span>Plans</span></a></li>
                <?php endif; ?>
                <li><a href="../logout.php"><span class="nav-icon">⏏️</span><span>Logout</span></a></li>
            </ul>
        </div>
        <div class="sidebar-footer">
            <span>Logged in as: <strong><?= htmlspecialchars($_SESSION['username']); ?></strong></span>
        </div>
    </aside>

    <main class="main-content">
        <div class="page-container">
            <!-- Header, Cards, and Table HTML are all unchanged -->
            <section class="header">
                <div class="header-left">
                    <div class="page-title">Subscription Plans</div>
                    <div class="page-subtitle">Create, edit, and manage hosting plans for your users.</div>
                </div>
                <div class="header-right">
                    <div class="user-info">
                        <div class="user-avatar"><?= htmlspecialchars(strtoupper(substr($_SESSION['username'] ?? 'U', 0, 1))); ?></div>
                        <div>
                            <span class="user-name"><?= htmlspecialchars($_SESSION['username']); ?></span>
                            <span class="user-role"><?= is_admin() ? 'Administrator' : 'User'; ?></span>
                        </div>
                    </div>
                </div>
            </section>

            <?php if ($flash_success): ?><div class="alert alert-success"><?= htmlspecialchars($flash_success); ?></div><?php endif; ?>
            <?php if ($flash_error): ?><div class="alert alert-danger"><?= htmlspecialchars($flash_error); ?></div><?php endif; ?>

            <section class="card">
                <div class="card-header"><div class="card-title">Add New Hosting Plan</div></div>
                <div class="card-body">
                    <form method="post">
                        <input type="hidden" name="action" value="add_plan">
                        <div class="form-grid" style="align-items: end;">
                            <div class="form-group"><label for="name">Plan Name</label><input type="text" id="name" name="name" placeholder="e.g., Basic" required></div>
                            <div class="form-group"><label for="disk_space_mb">Disk Space (MB)</label><input type="number" id="disk_space_mb" name="disk_space_mb" value="1000" required></div>
                            <div class="form-group"><label for="bandwidth_gb">Bandwidth (GB)</label><input type="number" id="bandwidth_gb" name="bandwidth_gb" value="10" required></div>
                            <div class="form-group"><label for="max_domains">Max Domains</label><input type="number" id="max_domains" name="max_domains" value="1" required></div>
                            <div class="form-group"><label for="max_databases">Max Databases</label><input type="number" id="max_databases" name="max_databases" value="1" required></div>
                            <div class="form-group"><label for="max_emails">Max Emails</label><input type="number" id="max_emails" name="max_emails" value="5" required></div>
                            <div class="form-group"><label for="price_monthly">Price (Monthly)</label><input type="number" id="price_monthly" name="price_monthly" step="0.01" value="5.00" required></div>
                            <div class="form-group"><label for="price_annually">Price (Annually)</label><input type="number" id="price_annually" name="price_annually" step="0.01" value="50.00" required></div>
                            <div class="form-group checkbox"><label><input type="checkbox" name="is_visible" value="1" checked> Visible to public</label></div>
                        </div>
                        <div class="form-actions"><button type="submit" class="btn btn-primary">➕ Add Plan</button></div>
                    </form>
                </div>
            </section>

            <section class="card">
                <div class="card-header"><div class="card-title">Existing Plans</div></div>
                <div class="card-body">
                    <div class="table-wrapper">
                        <table>
                            <thead><tr><th>Name</th><th>Disk</th><th>Bandwidth</th><th>Domains</th><th>DBs</th><th>Emails</th><th>Price/mo</th><th>Visible</th><th>Actions</th></tr></thead>
                            <tbody>
                                <?php if (empty($plans)): ?>
                                    <tr><td colspan="9" style="text-align: center; color: var(--text-muted);">No hosting plans have been created yet.</td></tr>
                                <?php else: ?>
                                    <?php foreach ($plans as $plan): ?>
                                        <tr>
                                            <td><strong><?= htmlspecialchars($plan['name']); ?></strong></td>
                                            <td><?= number_format($plan['disk_space_mb']); ?> MB</td>
                                            <td><?= number_format($plan['bandwidth_gb']); ?> GB</td>
                                            <td><?= htmlspecialchars($plan['max_domains']); ?></td>
                                            <td><?= htmlspecialchars($plan['max_databases']); ?></td>
                                            <td><?= htmlspecialchars($plan['max_emails']); ?></td>
                                            <td>₹ <?= number_format($plan['price_monthly'], 2); ?></td>
                                            <td><span class="badge <?= $plan['is_visible'] ? 'badge-success' : 'badge-muted' ?>"><?= $plan['is_visible'] ? 'Visible' : 'Hidden' ?></span></td>
                                            <td>
                                                <button onclick="openEditModal(<?= htmlspecialchars(json_encode($plan)); ?>)" class="btn btn-secondary btn-sm">✏️ Edit</button>
                                                <form method="post" style="display: inline;" onsubmit="return confirm('Are you sure you want to delete this plan? This cannot be undone.');">
                                                    <input type="hidden" name="action" value="delete_plan">
                                                    <input type="hidden" name="plan_id" value="<?= (int)$plan['id']; ?>">
                                                    <button type="submit" class="btn btn-danger btn-sm">🗑️ Delete</button>
                                                </form>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </section>
        </div>
    </main>

    <div id="editModal" class="modal">
        <!-- Modal HTML is unchanged -->
        <div class="modal-content">
            <div class="modal-header">
                <div id="modalTitle" class="modal-title">Edit Hosting Plan</div>
                <button onclick="closeModal()" class="btn btn-sm btn-secondary" style="border-radius:50%; padding:4px 8px;">&times;</button>
            </div>
            <form method="post">
                <input type="hidden" name="action" value="update_plan">
                <input type="hidden" name="plan_id" id="edit_plan_id">
                <div class="modal-body">
                     <div class="form-grid" style="align-items: end;">
                        <div class="form-group"><label for="edit_name">Plan Name</label><input type="text" id="edit_name" name="name" required></div>
                        <div class="form-group"><label for="edit_disk_space_mb">Disk Space (MB)</label><input type="number" id="edit_disk_space_mb" name="disk_space_mb" required></div>
                        <div class="form-group"><label for="edit_bandwidth_gb">Bandwidth (GB)</label><input type="number" id="edit_bandwidth_gb" name="bandwidth_gb" required></div>
                        <div class="form-group"><label for="edit_max_domains">Max Domains</label><input type="number" id="edit_max_domains" name="max_domains" required></div>
                        <div class="form-group"><label for="edit_max_databases">Max Databases</label><input type="number" id="edit_max_databases" name="max_databases" required></div>
                        <div class="form-group"><label for="edit_max_emails">Max Emails</label><input type="number" id="edit_max_emails" name="max_emails" required></div>
                        <div class="form-group"><label for="edit_price_monthly">Price (Monthly)</label><input type="number" id="edit_price_monthly" name="price_monthly" step="0.01" required></div>
                        <div class="form-group"><label for="edit_price_annually">Price (Annually)</label><input type="number" id="edit_price_annually" name="price_annually" step="0.01" required></div>
                        <div class="form-group"><label><input type="checkbox" id="edit_is_visible" name="is_visible" value="1"> Visible to public</label></div>
                    </div>
                </div>
                <div class="form-actions" style="border-top: 1px solid var(--border-soft); padding: 12px 16px; background: #f9fafb; border-bottom-left-radius: var(--radius-lg); border-bottom-right-radius: var(--radius-lg);">
                    <button type="submit" class="btn btn-primary">💾 Save Changes</button>
                </div>
            </form>
        </div>
    </div>

<script>
    // JavaScript is unchanged
    const modal = document.getElementById('editModal');
    function openEditModal(planData) {
        document.getElementById('edit_plan_id').value = planData.id;
        document.getElementById('edit_name').value = planData.name;
        document.getElementById('edit_disk_space_mb').value = planData.disk_space_mb;
        document.getElementById('edit_bandwidth_gb').value = planData.bandwidth_gb;
        document.getElementById('edit_max_domains').value = planData.max_domains;
        document.getElementById('edit_max_databases').value = planData.max_databases;
        document.getElementById('edit_max_emails').value = planData.max_emails;
        document.getElementById('edit_price_monthly').value = planData.price_monthly;
        document.getElementById('edit_price_annually').value = planData.price_annually;
        document.getElementById('edit_is_visible').checked = (planData.is_visible == 1);
        modal.style.display = 'flex';
    }
    function closeModal() { modal.style.display = 'none'; }
    document.addEventListener('keydown', (event) => { if (event.key === 'Escape' && modal.style.display === 'flex') closeModal(); });
    modal.addEventListener('click', (event) => { if (event.target === modal) closeModal(); });
</script>

</body>
</html>