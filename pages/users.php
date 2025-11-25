<?php
// users.php: Themed User Management for SHM Panel (Admin only).

require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

// Enforce admin-only access for this page
require_admin();

// Define the master list of all possible permissions
$all_permissions = ['domain_management', 'file_management', 'database_management', 'ssl_management', 'dns_management'];

// Handle POST and AJAX operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? null;
    
    // AJAX Actions
    if (!empty($_POST['ajax'])) {
        header('Content-Type: application/json');
        
        if ($action === 'get_permissions') {
            $user_id = filter_input(INPUT_POST, 'user_id', FILTER_VALIDATE_INT);
            $stmt = $pdo->prepare("SELECT permission FROM user_permissions WHERE user_id = ? AND allowed = 1");
            $stmt->execute([$user_id]);
            $permissions = $stmt->fetchAll(PDO::FETCH_COLUMN);
            echo json_encode(['success' => true, 'permissions' => $permissions]);
            exit;
        }

        if ($action === 'toggle_status') {
            $user_id = filter_input(INPUT_POST, 'user_id', FILTER_VALIDATE_INT);
            if ($user_id == $_SESSION['user_id']) {
                echo json_encode(['error' => 'You cannot change your own status.']);
                exit;
            }
            
            $stmt = $pdo->prepare("SELECT status FROM users WHERE id = ?");
            $stmt->execute([$user_id]);
            $current_status = $stmt->fetchColumn();
            
            $new_status = ($current_status === 'active') ? 'disabled' : 'active';
            
            $update_stmt = $pdo->prepare("UPDATE users SET status = ? WHERE id = ?");
            $update_stmt->execute([$new_status, $user_id]);
            
            echo json_encode(['success' => true, 'newStatus' => $new_status]);
            exit;
        }
        
        echo json_encode(['error' => 'Invalid AJAX action.']);
        exit;
    }

    // Standard Form Submissions
    if ($action === 'add_user') {
        $username = sanitize_input($_POST['username']);
        $email    = filter_input(INPUT_POST, 'email', FILTER_VALIDATE_EMAIL);
        $password = $_POST['password'];
        $role     = sanitize_input($_POST['role']);
        
        $hashed_password = password_hash($password, PASSWORD_DEFAULT);
        
        $stmt = $pdo->prepare("INSERT INTO users (username, email, password, role, created_at) VALUES (?, ?, ?, ?, NOW())");
        $stmt->execute([$username, $email, $hashed_password, $role]);
        $user_id = $pdo->lastInsertId();
        
        // Grant all permissions by default to a new user
        foreach ($all_permissions as $permission) {
            $perm_stmt = $pdo->prepare("INSERT INTO user_permissions (user_id, permission, allowed) VALUES (?, ?, 1)");
            $perm_stmt->execute([$user_id, $permission]);
        }
        
        header('Location: users.php?success=' . urlencode('User added successfully. Permissions can be edited below.'));
        exit;
    }
    
    if ($action === 'update_permissions') {
        $user_id = filter_input(INPUT_POST, 'user_id', FILTER_VALIDATE_INT);
        $permissions_posted = $_POST['permissions'] ?? [];
        
        // Clear old permissions
        $stmt = $pdo->prepare("DELETE FROM user_permissions WHERE user_id = ?");
        $stmt->execute([$user_id]);
        
        // Insert new permissions based on the master list
        foreach ($all_permissions as $permission) {
            $allowed = in_array($permission, $permissions_posted) ? 1 : 0;
            $perm_stmt = $pdo->prepare("INSERT INTO user_permissions (user_id, permission, allowed) VALUES (?, ?, ?)");
            $perm_stmt->execute([$user_id, $permission, $allowed]);
        }
        
        header('Location: users.php?success=' . urlencode('Permissions updated successfully.'));
        exit;
    }
}

// --- Data Fetching for Page Render ---

// Get all users
$users_stmt = $pdo->query("SELECT * FROM users ORDER BY username");
$users = $users_stmt->fetchAll(PDO::FETCH_ASSOC);

// Get flash messages
$flash_success = $_GET['success'] ?? null;
$flash_error = $_GET['error'] ?? null;
?>

<?php require"../includes/header.php"; ?>

    <style>
        .card { background: var(--bg-card); border-radius: var(--radius-lg); box-shadow: var(--shadow-soft); border: 1px solid var(--border-soft); margin-bottom: 18px; }
        .card-header { padding: 12px 16px; border-bottom: 1px solid var(--border-soft); }
        .card-title { font-size: 15px; font-weight: 500; }
        .card-body { padding: 16px 16px 18px; }
        .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px 18px; }
        .form-group { display: flex; flex-direction: column; gap: 4px; }
        label { font-size: 13px; font-weight: 500; }
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
        th, td { padding: 10px 10px; text-align: left; border-bottom: 1px solid var(--border-soft); white-space: nowrap; }
        th { font-weight: 500; color: var(--text-muted); background: #f9fafb; }
        .badge { display: inline-block; padding: 3px 8px; font-size: 11px; border-radius: 999px; font-weight:500; }
        .badge-success { background: #ecfdf3; color: #166534; border: 1px solid #bbf7d0; }
        .badge-danger { background: var(--danger-soft); color: #991b1b; border: 1px solid #fecaca; }
        .badge-admin { background: var(--primary-soft); color: var(--primary-dark); border: 1px solid #bfdbfe; }
        .badge-user { background: #f3f4f6; color: var(--text-muted); border: 1px solid #e5e7eb; }
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; overflow: auto; background-color: rgba(17, 24, 39, 0.5); align-items: center; justify-content: center; backdrop-filter: blur(4px); }
        .modal-content { background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-soft); width: 90%; max-width: 500px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: var(--shadow-soft); }
        .modal-header { padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-soft); }
        .modal-title { font-size: 15px; font-weight: 500; }
        .modal-body { padding: 16px; overflow-y: auto; }
        .permissions-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .permissions-grid label { display: flex; align-items: center; gap: 8px; font-weight: normal; }
        @media (max-width: 840px) { .sidebar { display: none; } .main-content { margin-left: 0; padding: 14px; } }
    </style>

    <main class="main-content">
        <div class="page-container">
            <!-- PAGE HEADER -->
            <section class="header">
                <div class="header-left">
                    <div class="page-title">User Management</div>
                    <div class="page-subtitle">Add new users, manage roles, and set permissions.</div>
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

            <!-- ADD NEW USER -->
            <section class="card">
                <div class="card-header"><div class="card-title">Add New User</div></div>
                <div class="card-body">
                    <form method="post">
                        <input type="hidden" name="action" value="add_user">
                        <div class="form-grid">
                            <div class="form-group"><label for="username">Username</label><input type="text" id="username" name="username" required></div>
                            <div class="form-group"><label for="email">Email</label><input type="email" id="email" name="email" required></div>
                            <div class="form-group"><label for="password">Password</label><input type="password" id="password" name="password" required></div>
                            <div class="form-group"><label for="role">Role</label><select id="role" name="role"><option value="user">User</option><option value="admin">Admin</option></select></div>
                        </div>
                        <div class="form-actions"><button type="submit" name="add_user" class="btn btn-primary">➕ Add User</button></div>
                    </form>
                </div>
            </section>

            <!-- USER LIST -->
            <section class="card">
                <div class="card-header"><div class="card-title">User Accounts</div></div>
                <div class="card-body">
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>Username</th><th>Email</th><th>Role</th><th>Status</th><th>Last Login</th><th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($users as $user): ?>
                                <tr id="user-row-<?= (int)$user['id'] ?>">
                                    <td><?= htmlspecialchars($user['username']); ?></td>
                                    <td><?= htmlspecialchars($user['email']); ?></td>
                                    <td><span class="badge <?= $user['role'] == 'admin' ? 'badge-admin' : 'badge-user' ?>"><?= htmlspecialchars(ucfirst($user['role'])); ?></span></td>
                                    <td><span class="status-badge badge <?= $user['status'] == 'active' ? 'badge-success' : 'badge-danger' ?>"><?= htmlspecialchars(ucfirst($user['status'])); ?></span></td>
                                    <td><?= $user['last_login'] ? date('M j, Y H:i', strtotime($user['last_login'])) : 'Never'; ?></td>
                                    <td>
                                        <button onclick="editPermissions(<?= (int)$user['id'] ?>, '<?= htmlspecialchars($user['username']) ?>')" class="btn btn-secondary btn-sm">Permissions</button>
                                        <?php if ($user['id'] != $_SESSION['user_id']): ?>
                                            <button onclick="toggleStatus(<?= (int)$user['id'] ?>)" class="toggle-status-btn btn btn-sm <?= $user['status'] == 'active' ? 'btn-danger' : 'btn-primary' ?>">
                                                <?= $user['status'] == 'active' ? 'Disable' : 'Enable'; ?>
                                            </button>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </section>
        </div>
    </main>

    <!-- Permissions Modal -->
    <div id="permissionsModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <div id="modalTitle" class="modal-title">Edit Permissions</div>
                <button onclick="closeModal()" class="btn btn-sm btn-secondary" style="border-radius:50%; padding:4px 8px;">&times;</button>
            </div>
            <form method="post">
                <input type="hidden" name="action" value="update_permissions">
                <input type="hidden" name="user_id" id="modalUserId">
                <div class="modal-body">
                    <div class="permissions-grid">
                        <?php foreach($all_permissions as $p): ?>
                        <div class="form-group">
                            <label>
                                <input type="checkbox" name="permissions[]" value="<?= htmlspecialchars($p) ?>">
                                <?= htmlspecialchars(ucwords(str_replace('_', ' ', $p))) ?>
                            </label>
                        </div>
                        <?php endforeach; ?>
                    </div>
                </div>
                <div class="form-actions" style="border-top: 1px solid var(--border-soft); padding: 12px 16px; background: #f9fafb; border-bottom-left-radius: var(--radius-lg); border-bottom-right-radius: var(--radius-lg);">
                    <button type="submit" name="update_permissions" class="btn btn-primary">Save Permissions</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        const SCRIPT_NAME = '<?= htmlspecialchars(basename(__FILE__)) ?>';
        
        // Generic AJAX helper function
        async function postAjax(data) {
            const formData = new URLSearchParams({ ...data, 'ajax': 1 });
            try {
                const response = await fetch(SCRIPT_NAME, { method: 'POST', body: formData });
                if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
                return await response.json();
            } catch (error) {
                console.error('AJAX Error:', error);
                alert('An unexpected error occurred.');
                return { error: 'Network or server error.' };
            }
        }

        // Permissions Modal Logic
        const modal = document.getElementById('permissionsModal');
        async function editPermissions(userId, username) {
            document.getElementById('modalTitle').textContent = 'Edit Permissions for ' + username;
            document.getElementById('modalUserId').value = userId;
            
            const checkboxes = modal.querySelectorAll('input[name="permissions[]"]');
            checkboxes.forEach(checkbox => checkbox.checked = false); // Reset first

            const res = await postAjax({ action: 'get_permissions', user_id: userId });
            if (res.success && res.permissions) {
                checkboxes.forEach(checkbox => {
                    if (res.permissions.includes(checkbox.value)) {
                        checkbox.checked = true;
                    }
                });
            }
            modal.style.display = 'flex';
        }
        
        function closeModal() {
            modal.style.display = 'none';
        }

        // Toggle User Status Logic
        async function toggleStatus(userId) {
            const row = document.getElementById(`user-row-${userId}`);
            const statusBadge = row.querySelector('.status-badge');
            const currentStatus = statusBadge.textContent.toLowerCase();
            
            if (!confirm(`Are you sure you want to ${currentStatus === 'active' ? 'disable' : 'enable'} this user?`)) return;

            const res = await postAjax({ action: 'toggle_status', user_id: userId });
            
            if (res.error) {
                alert(res.error);
            } else if (res.success) {
                const toggleBtn = row.querySelector('.toggle-status-btn');
                const newStatus = res.newStatus;

                // Update status badge
                statusBadge.textContent = newStatus.charAt(0).toUpperCase() + newStatus.slice(1);
                statusBadge.classList.toggle('badge-success', newStatus === 'active');
                statusBadge.classList.toggle('badge-danger', newStatus === 'disabled');

                // Update button text and class
                toggleBtn.textContent = newStatus === 'active' ? 'Disable' : 'Enable';
                toggleBtn.classList.toggle('btn-danger', newStatus === 'active');
                toggleBtn.classList.toggle('btn-primary', newStatus === 'disabled');
            }
        }

        // Close modal on ESC key
        document.addEventListener('keydown', (event) => { if (event.key === 'Escape' && modal.style.display === 'flex') closeModal(); });
    </script>

<?php require"../includes/footer.php"; ?>