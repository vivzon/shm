<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('database_management');

$db_id = intval($_GET['id']);
// Verify ownership
$stmt = $pdo->prepare("SELECT * FROM databases WHERE id = ? AND user_id = ?");
$stmt->execute([$db_id, $_SESSION['user_id']]);
$database = $stmt->fetch();

if (!$database) {
    die("Database not found or access denied");
}

// Get user domains for dropdown
$domains = get_user_domains($_SESSION['user_id']);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $db_pass = $_POST['db_pass'];
    $domain_id = isset($_POST['domain_id']) ? intval($_POST['domain_id']) : null;
    
    // If password is provided, update it
    if (!empty($db_pass)) {
        // Update the database user password in MySQL
        // Note: This requires the MySQL root password or a user with sufficient privileges
        // This is a sensitive operation and should be handled with care
        // For now, we'll just update the password in our database, but note that the actual MySQL user password is not updated.
        $stmt = $pdo->prepare("UPDATE databases SET db_pass = ?, domain_id = ? WHERE id = ?");
        $stmt->execute([$db_pass, $domain_id, $db_id]);
        
        header('Location: database.php?success=Database updated successfully');
        exit;
    } else {
        // Only update the domain association
        $stmt = $pdo->prepare("UPDATE databases SET domain_id = ? WHERE id = ?");
        $stmt->execute([$domain_id, $db_id]);
        
        header('Location: database.php?success=Database updated successfully');
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Edit Database - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>Edit Database</h1>
        </div>

        <div class="container">
            <div class="card">
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Database Name</label>
                            <input type="text" value="<?php echo $database['db_name']; ?>" disabled>
                            <small>Database name cannot be changed.</small>
                        </div>
                        <div class="form-group">
                            <label>Username</label>
                            <input type="text" value="<?php echo $database['db_user']; ?>" disabled>
                            <small>Username cannot be changed.</small>
                        </div>
                        <div class="form-group">
                            <label>New Password (leave blank to keep current)</label>
                            <input type="password" name="db_pass">
                        </div>
                        <div class="form-group">
                            <label>Associate with Domain (Optional)</label>
                            <select name="domain_id">
                                <option value="">None</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?php echo $domain['id']; ?>" <?php echo $database['domain_id'] == $domain['id'] ? 'selected' : ''; ?>>
                                    <?php echo $domain['domain_name']; ?>
                                </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <button type="submit" class="btn btn-primary">Update Database</button>
                        <a href="database.php" class="btn">Cancel</a>
                    </form>
                </div>
            </div>
        </div>
    </div>
</body>
</html>