<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('database_management');

// Handle database operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_database'])) {
        $db_name   = sanitize_input($_POST['db_name']);
        $db_user   = sanitize_input($_POST['db_user']);
        $db_pass   = sanitize_input($_POST['db_pass']);
        $domain_id = isset($_POST['domain_id']) && $_POST['domain_id'] !== '' ? intval($_POST['domain_id']) : null;

        if (create_database_user($db_name, $db_user, $db_pass)) {
            $stmt = $pdo->prepare("
                INSERT INTO `databases` (user_id, domain_id, db_name, db_user, db_pass, created_at)
                VALUES (?, ?, ?, ?, ?, NOW())
            ");
            $stmt->execute([$_SESSION['user_id'], $domain_id, $db_name, $db_user, $db_pass]);
            header('Location: database.php?success=' . urlencode('Database created successfully.'));
            exit;
        } else {
            $error = "Failed to create database.";
        }
    }

    if (isset($_POST['delete_database'])) {
        $db_id = intval($_POST['db_id']);

        // Verify ownership
        $stmt = $pdo->prepare("SELECT * FROM `databases` WHERE id = ? AND user_id = ?");
        $stmt->execute([$db_id, $_SESSION['user_id']]);
        $database = $stmt->fetch();

        if ($database) {
            if (delete_database_user($database['db_name'], $database['db_user'])) {
                $stmt = $pdo->prepare("DELETE FROM `databases` WHERE id = ?");
                $stmt->execute([$db_id]);
                header('Location: database.php?success=' . urlencode('Database deleted successfully.'));
                exit;
            } else {
                $error = "Failed to delete database.";
            }
        }
    }
}

// Get user databases
$stmt = $pdo->prepare("
    SELECT d.*, dom.domain_name
    FROM `databases` d
    LEFT JOIN domains dom ON d.domain_id = dom.id
    WHERE d.user_id = ?
    ORDER BY d.db_name
");
$stmt->execute([$_SESSION['user_id']]);
$databases = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get user domains for dropdown
$domains = get_user_domains($_SESSION['user_id']);
?>

<?php include '../includes/header.php'; ?>
    <style>
        
        .card {
            background: var(--bg-card);
            border-radius: var(--radius-lg);
            box-shadow: var(--shadow-soft);
            border: 1px solid var(--border-soft);
            margin-bottom: 18px;
        }
        .card-header {
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-soft);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .card-title { font-size: 15px; font-weight: 500; }
        .card-subtitle { font-size: 12px; color: var(--text-muted); }
        .card-body { padding: 16px; }

        .form-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 14px 18px;
        }
        .form-group {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        label {
            font-size: 13px;
            font-weight: 500;
        }
        .field-hint {
            font-size: 11px;
            color: var(--text-muted);
        }
        input[type="text"],
        input[type="password"],
        select {
            width: 100%;
            padding: 8px 9px;
            border-radius: 8px;
            border: 1px solid #d1d5db;
            font-size: 13px;
            outline: none;
            background: #ffffff;
            transition: border-color 0.12s ease, box-shadow 0.12s ease;
        }
        input[type="text"]:focus,
        input[type="password"]:focus,
        select:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 1px var(--primary-soft);
        }
        .form-actions {
            margin-top: 14px;
            display: flex;
            justify-content: flex-end;
        }

        .btn {
            padding: 8px 16px;
            border-radius: 999px;
            border: none;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            text-decoration: none;
        }
        .btn-primary {
            background: var(--primary);
            color: #ffffff;
        }
        .btn-primary:hover { background: var(--primary-dark); }
        .btn-danger {
            background: #ef4444;
            color: #ffffff;
        }
        .btn-danger:hover { background: #b91c1c; }
        .btn-secondary {
            background: #f3f4f6;
            color: var(--text-main);
            border: 1px solid #e5e7eb;
        }
        .btn-secondary:hover { background: #e5e7eb; }
        .btn-sm {
            padding: 5px 10px;
            font-size: 12px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        th, td {
            padding: 10px 10px;
            text-align: left;
            border-bottom: 1px solid var(--border-soft);
            white-space: nowrap;
        }
        th {
            font-weight: 500;
            color: var(--text-muted);
            background: #f9fafb;
        }
        tr:hover td {
            background: #f9fafb;
        }

        .modal-backdrop {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.45);
            display: none;
            justify-content: center;
            align-items: center;
            z-index: 999;
        }
        .modal {
            background: #ffffff;
            border-radius: 16px;
            padding: 18px 18px 16px;
            box-shadow: 0 20px 45px rgba(15, 23, 42, 0.25);
            width: 380px;
            max-width: 90%;
        }
        .modal h3 {
            font-size: 16px;
            margin-bottom: 8px;
        }
        .modal p {
            font-size: 13px;
            margin-bottom: 4px;
        }
        .modal small {
            font-size: 11px;
            color: var(--text-muted);
        }

        @media (max-width: 840px) {
            .sidebar { display: none; }
            .main-content {
                margin-left: 0;
                padding: 14px 14px 20px;
            }
            .header {
                flex-direction: column;
                align-items: flex-start;
            }
            .header-right {
                justify-content: space-between;
                width: 100%;
            }
        }
    </style>
    
    <!-- MAIN -->
    <main class="main-content">
        <div class="page-container">
            <section class="header">
                <div class="header-left">
                    <div class="page-title">Database Management</div>
                    <div class="page-subtitle">
                        Create and manage MySQL databases and users for your domains.
                    </div>
                </div>
                <div class="header-right">
                    <span class="chip chip-live">● Session Active</span>
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

            <?php if (isset($error)): ?>
                <div class="alert alert-error">
                    <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endif; ?>

            <?php if (isset($_GET['success'])): ?>
                <div class="alert alert-success">
                    <?php echo htmlspecialchars($_GET['success']); ?>
                </div>
            <?php endif; ?>

            <!-- CREATE DB -->
            <section class="card">
                <div class="card-header">
                    <div>
                        <div class="card-title">Create New Database</div>
                        <div class="card-subtitle">
                            A database and a corresponding user will be provisioned on the server.
                        </div>
                    </div>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-grid">
                            <div class="form-group">
                                <label for="db_name">Database Name</label>
                                <input
                                    type="text"
                                    id="db_name"
                                    name="db_name"
                                    pattern="[a-zA-Z0-9_]+"
                                    title="Only letters, numbers, and underscores"
                                    required>
                                <div class="field-hint">Example: <code>project_db</code></div>
                            </div>
                            <div class="form-group">
                                <label for="db_user">Database User</label>
                                <input
                                    type="text"
                                    id="db_user"
                                    name="db_user"
                                    pattern="[a-zA-Z0-9_]+"
                                    title="Only letters, numbers, and underscores"
                                    required>
                                <div class="field-hint">Example: <code>project_user</code></div>
                            </div>
                            <div class="form-group">
                                <label for="db_pass">Database Password</label>
                                <input
                                    type="password"
                                    id="db_pass"
                                    name="db_pass"
                                    required>
                                <div class="field-hint">Use a strong password.</div>
                            </div>
                            <div class="form-group">
                                <label for="domain_id">Associate with Domain (optional)</label>
                                <select id="domain_id" name="domain_id">
                                    <option value="">None</option>
                                    <?php foreach ($domains as $domain): ?>
                                        <option value="<?php echo (int)$domain['id']; ?>">
                                            <?php echo htmlspecialchars($domain['domain_name']); ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                                <div class="field-hint">For organization inside SHM Panel only.</div>
                            </div>
                        </div>

                        <div class="form-actions">
                            <button type="submit" name="add_database" class="btn btn-primary">
                                ➕ Create Database
                            </button>
                        </div>
                    </form>
                </div>
            </section>

            <!-- DB LIST -->
            <section class="card">
                <div class="card-header">
                    <div>
                        <div class="card-title">Your Databases</div>
                        <div class="card-subtitle">
                            All databases provisioned under your SHM account.
                        </div>
                    </div>
                </div>
                <div class="card-body">
                    <?php if (empty($databases)): ?>
                        <p style="font-size: 13px; color: var(--text-muted);">
                            No databases found. Create your first database above.
                        </p>
                    <?php else: ?>
                        <div style="overflow-x: auto;">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Database Name</th>
                                        <th>Username</th>
                                        <th>Associated Domain</th>
                                        <th>Created</th>
                                        <th style="text-align: right;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($databases as $db): ?>
                                        <tr>
                                            <td><?php echo htmlspecialchars($db['db_name']); ?></td>
                                            <td><?php echo htmlspecialchars($db['db_user']); ?></td>
                                            <td><?php echo $db['domain_name'] ? htmlspecialchars($db['domain_name']) : 'None'; ?></td>
                                            <td><?php echo htmlspecialchars(date('Y-m-d', strtotime($db['created_at']))); ?></td>
                                            <td style="text-align: right;">
                                                <button
                                                    type="button"
                                                    class="btn btn-secondary btn-sm"
                                                    onclick="showConnectionInfo(
                                                        '<?php echo htmlspecialchars($db['db_name'], ENT_QUOTES); ?>',
                                                        '<?php echo htmlspecialchars($db['db_user'], ENT_QUOTES); ?>',
                                                        '<?php echo htmlspecialchars($db['db_pass'], ENT_QUOTES); ?>'
                                                    )">
                                                    🔐 Connection Info
                                                </button>
                                                <form method="post" style="display: inline;">
                                                    <input type="hidden" name="db_id" value="<?php echo (int)$db['id']; ?>">
                                                    <button
                                                        type="submit"
                                                        name="delete_database"
                                                        class="btn btn-danger btn-sm"
                                                        onclick="return confirm('Are you sure? This will permanently delete the database and user.');">
                                                        🗑️ Delete
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

    <!-- Connection Info Modal -->
    <div id="connectionModal" class="modal-backdrop">
        <div class="modal">
            <h3>Database Connection Information</h3>
            <div id="connectionDetails" style="margin-bottom: 10px;"></div>
            <small>Keep this information secure. Do not share it publicly.</small>
            <div style="margin-top: 12px; text-align: right;">
                <button class="btn btn-secondary btn-sm" onclick="hideConnectionInfo()">Close</button>
            </div>
        </div>
    </div>

    <script>
        function showConnectionInfo(dbName, dbUser, dbPass) {
            const modal   = document.getElementById('connectionModal');
            const details = document.getElementById('connectionDetails');

            const host = 'localhost';
            const port = '3306';

            details.innerHTML = `
                <p><strong>Host:</strong> ${host}</p>
                <p><strong>Port:</strong> ${port}</p>
                <p><strong>Database:</strong> ${dbName}</p>
                <p><strong>Username:</strong> ${dbUser}</p>
                <p><strong>Password:</strong> ${dbPass}</p>
                <p><strong>DSN (PDO):</strong><br>
                <code>mysql:host=${host};port=${port};dbname=${dbName};charset=utf8mb4</code></p>
            `;
            modal.style.display = 'flex';
        }

        function hideConnectionInfo() {
            const modal = document.getElementById('connectionModal');
            modal.style.display = 'none';
        }
    </script>

<?php include '../includes/footer.php'; ?>