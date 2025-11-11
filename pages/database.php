<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('database_management');

// Handle database operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_database'])) {
        $db_name = sanitize_input($_POST['db_name']);
        $db_user = sanitize_input($_POST['db_user']);
        $db_pass = sanitize_input($_POST['db_pass']);
        $domain_id = isset($_POST['domain_id']) ? intval($_POST['domain_id']) : null;
        
        if (create_database_user($db_name, $db_user, $db_pass)) {
            $stmt = $pdo->prepare("INSERT INTO databases (user_id, domain_id, db_name, db_user, db_pass, created_at) VALUES (?, ?, ?, ?, ?, NOW())");
            $stmt->execute([$_SESSION['user_id'], $domain_id, $db_name, $db_user, $db_pass]);
            header('Location: database.php?success=Database created successfully');
            exit;
        } else {
            $error = "Failed to create database";
        }
    }
    
    if (isset($_POST['delete_database'])) {
        $db_id = intval($_POST['db_id']);
        
        // Verify ownership
        $stmt = $pdo->prepare("SELECT * FROM databases WHERE id = ? AND user_id = ?");
        $stmt->execute([$db_id, $_SESSION['user_id']]);
        $database = $stmt->fetch();
        
        if ($database) {
            if (delete_database_user($database['db_name'], $database['db_user'])) {
                $stmt = $pdo->prepare("DELETE FROM databases WHERE id = ?");
                $stmt->execute([$db_id]);
                header('Location: database.php?success=Database deleted successfully');
                exit;
            } else {
                $error = "Failed to delete database";
            }
        }
    }
}

// Get user databases
$stmt = $pdo->prepare("SELECT d.*, dom.domain_name FROM databases d LEFT JOIN domains dom ON d.domain_id = dom.id WHERE d.user_id = ? ORDER BY d.db_name");
$stmt->execute([$_SESSION['user_id']]);
$databases = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get user domains for dropdown
$domains = get_user_domains($_SESSION['user_id']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Management - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>Database Management</h1>
        </div>

        <?php if (isset($error)): ?>
            <div style="background: #f8d7da; color: #721c24; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $error; ?>
            </div>
        <?php endif; ?>

        <?php if (isset($_GET['success'])): ?>
            <div style="background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $_GET['success']; ?>
            </div>
        <?php endif; ?>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <h3>Create New Database</h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Database Name</label>
                            <input type="text" name="db_name" pattern="[a-zA-Z0-9_]+" title="Only letters, numbers, and underscores" required>
                        </div>
                        <div class="form-group">
                            <label>Database User</label>
                            <input type="text" name="db_user" pattern="[a-zA-Z0-9_]+" title="Only letters, numbers, and underscores" required>
                        </div>
                        <div class="form-group">
                            <label>Database Password</label>
                            <input type="password" name="db_pass" required>
                        </div>
                        <div class="form-group">
                            <label>Associate with Domain (Optional)</label>
                            <select name="domain_id">
                                <option value="">None</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?php echo $domain['id']; ?>"><?php echo $domain['domain_name']; ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <button type="submit" name="add_database" class="btn btn-primary">Create Database</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>Your Databases</h3>
                </div>
                <div class="card-body">
                    <?php if (empty($databases)): ?>
                        <p>No databases found.</p>
                    <?php else: ?>
                        <table>
                            <thead>
                                <tr>
                                    <th>Database Name</th>
                                    <th>Username</th>
                                    <th>Associated Domain</th>
                                    <th>Created</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($databases as $db): ?>
                                <tr>
                                    <td><?php echo $db['db_name']; ?></td>
                                    <td><?php echo $db['db_user']; ?></td>
                                    <td><?php echo $db['domain_name'] ?: 'None'; ?></td>
                                    <td><?php echo date('Y-m-d', strtotime($db['created_at'])); ?></td>
                                    <td>
                                        <button onclick="showConnectionInfo(<?php echo $db['id']; ?>)">Connection Info</button>
                                        <form method="post" style="display: inline;">
                                            <input type="hidden" name="db_id" value="<?php echo $db['id']; ?>">
                                            <button type="submit" name="delete_database" class="btn btn-danger" onclick="return confirm('Are you sure? This will permanently delete the database.')">Delete</button>
                                        </form>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                </div>
            </div>
        </div>
    </div>

    <!-- Connection Info Modal -->
    <div id="connectionModal" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); justify-content: center; align-items: center;">
        <div style="background: white; padding: 20px; border-radius: 5px; width: 400px;">
            <h3>Database Connection Information</h3>
            <div id="connectionDetails"></div>
            <button onclick="document.getElementById('connectionModal').style.display = 'none'">Close</button>
        </div>
    </div>

    <script>
        function showConnectionInfo(dbId) {
            // In a real implementation, you would fetch this via AJAX
            const modal = document.getElementById('connectionModal');
            const details = document.getElementById('connectionDetails');
            
            // For demo purposes - in real implementation, get actual connection info
            details.innerHTML = `
                <p><strong>Host:</strong> localhost</p>
                <p><strong>Database:</strong> [Database Name]</p>
                <p><strong>Username:</strong> [Username]</p>
                <p><strong>Password:</strong> [Password]</p>
                <p><em>Keep this information secure!</em></p>
            `;
            
            modal.style.display = 'flex';
        }
    </script>
</body>
</html>