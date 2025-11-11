<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('domain_management');

$domain_id = intval($_GET['id']);

// Verify ownership
$stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
$stmt->execute([$domain_id, $_SESSION['user_id']]);
$domain = $stmt->fetch();

if (!$domain) {
    die("Domain not found or access denied");
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $domain_name = sanitize_input($_POST['domain_name']);
    $document_root = sanitize_input($_POST['document_root']);
    $php_version = sanitize_input($_POST['php_version']);
    
    $stmt = $pdo->prepare("UPDATE domains SET domain_name = ?, document_root = ?, php_version = ? WHERE id = ?");
    $stmt->execute([$domain_name, $document_root, $php_version, $domain_id]);
    
    header('Location: domains.php?success=Domain updated successfully');
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Edit Domain - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>Edit Domain</h1>
        </div>

        <div class="container">
            <div class="card">
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Domain Name</label>
                            <input type="text" name="domain_name" value="<?php echo $domain['domain_name']; ?>" required>
                        </div>
                        <div class="form-group">
                            <label>Document Root</label>
                            <input type="text" name="document_root" value="<?php echo $domain['document_root']; ?>" required>
                        </div>
                        <div class="form-group">
                            <label>PHP Version</label>
                            <select name="php_version">
                                <option value="7.4" <?php echo $domain['php_version'] == '7.4' ? 'selected' : ''; ?>>PHP 7.4</option>
                                <option value="8.0" <?php echo $domain['php_version'] == '8.0' ? 'selected' : ''; ?>>PHP 8.0</option>
                                <option value="8.1" <?php echo $domain['php_version'] == '8.1' ? 'selected' : ''; ?>>PHP 8.1</option>
                                <option value="8.2" <?php echo $domain['php_version'] == '8.2' ? 'selected' : ''; ?>>PHP 8.2</option>
                            </select>
                        </div>
                        <button type="submit" class="btn btn-primary">Update Domain</button>
                        <a href="domains.php" class="btn">Cancel</a>
                    </form>
                </div>
            </div>
        </div>
    </div>
</body>
</html>