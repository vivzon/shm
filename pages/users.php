<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_admin();

// Handle user operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_user'])) {
        $username = sanitize_input($_POST['username']);
        $email = sanitize_input($_POST['email']);
        $password = $_POST['password'];
        $role = sanitize_input($_POST['role']);
        
        $hashed_password = password_hash($password, PASSWORD_DEFAULT);
        
        $stmt = $pdo->prepare("INSERT INTO users (username, email, password, role, created_at) VALUES (?, ?, ?, ?, NOW())");
        $stmt->execute([$username, $email, $hashed_password, $role]);
        
        $user_id = $pdo->lastInsertId();
        
        // Set default permissions
        $permissions = ['domain_management', 'file_management', 'database_management', 'ssl_management', 'dns_management'];
        foreach ($permissions as $permission) {
            $stmt = $pdo->prepare("INSERT INTO user_permissions (user_id, permission, allowed) VALUES (?, ?, 1)");
            $stmt->execute([$user_id, $permission]);
        }
        
        header('Location: users.php?success=User added successfully');
        exit;
    }
    
    if (isset($_POST['update_permissions'])) {
        $user_id = intval($_POST['user_id']);
        $permissions = $_POST['permissions'] ?? [];
        
        // Delete existing permissions
        $stmt = $pdo->prepare("DELETE FROM user_permissions WHERE user_id = ?");
        $stmt->execute([$user_id]);
        
        // Insert new permissions
        $all_permissions = ['domain_management', 'file_management', 'database_management', 'ssl_management', 'dns_management'];
        foreach ($all_permissions as $permission) {
            $allowed = in_array($permission, $permissions) ? 1 : 0;
            $stmt = $pdo->prepare("INSERT INTO user_permissions (user_id, permission, allowed) VALUES (?, ?, ?)");
            $stmt->execute([$user_id, $permission, $allowed]);
        }
        
        header('Location: users.php?success=Permissions updated successfully');
        exit;
    }
}

// Get all users
$stmt = $pdo->prepare("SELECT * FROM users ORDER BY username");
$stmt->execute();
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get permissions for each user
$user_permissions = [];
foreach ($users as $user) {
    $stmt = $pdo->prepare("SELECT permission FROM user_permissions WHERE user_id = ? AND allowed = 1");
    $stmt->execute([$user['id']]);
    $user_permissions[$user['id']] = $stmt->fetchAll(PDO::FETCH_COLUMN);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Management - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>User Management</h1>
        </div>

        <?php if (isset($_GET['success'])): ?>
            <div style="background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $_GET['success']; ?>
            </div>
        <?php endif; ?>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <h3>Add New User</h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Username</label>
                            <input type="text" name="username" required>
                        </div>
                        <div class="form-group">
                            <label>Email</label>
                            <input type="email" name="email" required>
                        </div>
                        <div class="form-group">
                            <label>Password</label>
                            <input type="password" name="password" required>
                        </div>
                        <div class="form-group">
                            <label>Role</label>
                            <select name="role">
                                <option value="user">User</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <button type="submit" name="add_user" class="btn btn-primary">Add User</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>User List</h3>
                </div>
                <div class="card-body">
                    <table>
                        <thead>
                            <tr>
                                <th>Username</th>
                                <th>Email</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Last Login</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($users as $user): ?>
                            <tr>
                                <td><?php echo $user['username']; ?></td>
                                <td><?php echo $user['email']; ?></td>
                                <td><?php echo ucfirst($user['role']); ?></td>
                                <td><?php echo ucfirst($user['status']); ?></td>
                                <td><?php echo $user['last_login'] ? date('Y-m-d H:i', strtotime($user['last_login'])) : 'Never'; ?></td>
                                <td>
                                    <button onclick="editPermissions(<?php echo $user['id']; ?>, '<?php echo $user['username']; ?>')">Permissions</button>
                                    <?php if ($user['id'] != $_SESSION['user_id']): ?>
                                        <button onclick="toggleStatus(<?php echo $user['id']; ?>, '<?php echo $user['status']; ?>')">
                                            <?php echo $user['status'] == 'active' ? 'Disable' : 'Enable'; ?>
                                        </button>
                                    <?php endif; ?>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- Permissions Modal -->
    <div id="permissionsModal" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); justify-content: center; align-items: center;">
        <div style="background: white; padding: 20px; border-radius: 5px; width: 400px;">
            <h3 id="modalTitle">Edit Permissions</h3>
            <form method="post" id="permissionsForm">
                <input type="hidden" name="user_id" id="modalUserId">
                <div class="form-group">
                    <label>
                        <input type="checkbox" name="permissions[]" value="domain_management"> Domain Management
                    </label>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" name="permissions[]" value="file_management"> File Management
                    </label>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" name="permissions[]" value="database_management"> Database Management
                    </label>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" name="permissions[]" value="ssl_management"> SSL Management
                    </label>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" name="permissions[]" value="dns_management"> DNS Management
                    </label>
                </div>
                <button type="submit" name="update_permissions" class="btn btn-primary">Save Permissions</button>
                <button type="button" onclick="document.getElementById('permissionsModal').style.display = 'none'">Cancel</button>
            </form>
        </div>
    </div>

    <script>
        function editPermissions(userId, username) {
            document.getElementById('modalTitle').textContent = 'Edit Permissions for ' + username;
            document.getElementById('modalUserId').value = userId;
            
            // Reset checkboxes
            const checkboxes = document.querySelectorAll('input[name="permissions[]"]');
            checkboxes.forEach(checkbox => checkbox.checked = false);
            
            // In real implementation, fetch current permissions via AJAX
            // For demo, we'll assume all are checked for admin users
            <?php
            // This would be replaced with AJAX call in production
            ?>
            
            document.getElementById('permissionsModal').style.display = 'flex';
        }
        
        function toggleStatus(userId, currentStatus) {
            if (confirm('Are you sure you want to ' + (currentStatus === 'active' ? 'disable' : 'enable') + ' this user?')) {
                // In real implementation, submit status change via AJAX
                alert('User status change requested for ID: ' + userId);
            }
        }
    </script>
</body>
</html>