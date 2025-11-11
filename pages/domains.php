<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('domain_management');

// Handle domain actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_domain'])) {
        $domain_name = sanitize_input($_POST['domain_name']);
        $document_root = sanitize_input($_POST['document_root']);
        $php_version = sanitize_input($_POST['php_version']);
        
        // Create directory if it doesn't exist
        if (!is_dir($document_root)) {
            mkdir($document_root, 0755, true);
        }
        
        $stmt = $pdo->prepare("INSERT INTO domains (user_id, domain_name, document_root, php_version, created_at) VALUES (?, ?, ?, ?, NOW())");
        $stmt->execute([$_SESSION['user_id'], $domain_name, $document_root, $php_version]);
        
        header('Location: domains.php?success=Domain added successfully');
        exit;
    }
    
    if (isset($_POST['delete_domain'])) {
        $domain_id = intval($_POST['domain_id']);
        
        // Verify ownership
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();
        
        if ($domain) {
            $stmt = $pdo->prepare("DELETE FROM domains WHERE id = ?");
            $stmt->execute([$domain_id]);
            header('Location: domains.php?success=Domain deleted successfully');
            exit;
        }
    }
}

// Get user domains
$domains = get_user_domains($_SESSION['user_id']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Domain Management - SHM Panel</title>
    <style>
        /* Add styles similar to dashboard */
        .container { max-width: 1200px; margin: 0 auto; }
        .card { background: white; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .card-header { padding: 15px 20px; border-bottom: 1px solid #dee2e6; }
        .card-body { padding: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #dee2e6; }
        .btn { padding: 8px 15px; border: none; border-radius: 3px; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn-primary { background: #007bff; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; }
        input, select { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; }
    </style>
</head>
<body>
    <!-- Include sidebar like in dashboard -->
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>Domain Management</h1>
        </div>

        <?php if (isset($_GET['success'])): ?>
            <div style="background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $_GET['success']; ?>
            </div>
        <?php endif; ?>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <h3>Add New Domain</h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Domain Name</label>
                            <input type="text" name="domain_name" placeholder="example.com" required>
                        </div>
                        <div class="form-group">
                            <label>Document Root</label>
                            <input type="text" name="document_root" placeholder="/var/www/example.com" required>
                        </div>
                        <div class="form-group">
                            <label>PHP Version</label>
                            <select name="php_version">
                                <option value="7.4">PHP 7.4</option>
                                <option value="8.0">PHP 8.0</option>
                                <option value="8.1">PHP 8.1</option>
                                <option value="8.2">PHP 8.2</option>
                            </select>
                        </div>
                        <button type="submit" name="add_domain" class="btn btn-primary">Add Domain</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>Your Domains</h3>
                </div>
                <div class="card-body">
                    <?php if (empty($domains)): ?>
                        <p>No domains found.</p>
                    <?php else: ?>
                        <table>
                            <thead>
                                <tr>
                                    <th>Domain Name</th>
                                    <th>Document Root</th>
                                    <th>PHP Version</th>
                                    <th>SSL</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($domains as $domain): ?>
                                <tr>
                                    <td><?php echo $domain['domain_name']; ?></td>
                                    <td><?php echo $domain['document_root']; ?></td>
                                    <td><?php echo $domain['php_version']; ?></td>
                                    <td><?php echo $domain['ssl_enabled'] ? 'Enabled' : 'Disabled'; ?></td>
                                    <td><?php echo ucfirst($domain['status']); ?></td>
                                    <td>
                                        <a href="edit_domain.php?id=<?php echo $domain['id']; ?>" class="btn btn-primary">Edit</a>
                                        <form method="post" style="display: inline;">
                                            <input type="hidden" name="domain_id" value="<?php echo $domain['id']; ?>">
                                            <button type="submit" name="delete_domain" class="btn btn-danger" onclick="return confirm('Are you sure?')">Delete</button>
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
</body>
</html>