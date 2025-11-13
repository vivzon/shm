<?php
header('Content-Type: application/json');

// Check if already installed
if (file_exists('../includes/config.php')) {
    echo json_encode(['success' => false, 'message' => 'System already installed']);
    exit;
}

$db_host = $_POST['db_host'] ?? 'localhost';
$db_name = $_POST['db_name'] ?? 'shm_panel';
$db_user = $_POST['db_user'] ?? 'root';
$db_pass = $_POST['db_pass'] ?? '';
$admin_user = $_POST['admin_user'] ?? 'admin';
$admin_email = $_POST['admin_email'] ?? '';
$admin_pass = $_POST['admin_pass'] ?? '';
$admin_pass_confirm = $_POST['admin_pass_confirm'] ?? '';

// Validate inputs
if (empty($admin_email) || empty($admin_pass)) {
    echo json_encode(['success' => false, 'message' => 'All fields are required']);
    exit;
}

if ($admin_pass !== $admin_pass_confirm) {
    echo json_encode(['success' => false, 'message' => 'Passwords do not match']);
    exit;
}

try {
    // Test database connection
    $pdo = new PDO("mysql:host=$db_host", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create database if not exists
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `$db_name`");
    $pdo->exec("USE `$db_name`");
    
    // Read and execute SQL file
    $sql = file_get_contents('../install.sql');
    $pdo->exec($sql);
    
    // Create admin user
    $hashed_password = password_hash($admin_pass, PASSWORD_DEFAULT);
    $stmt = $pdo->prepare("INSERT INTO users (username, email, password, role, created_at) VALUES (?, ?, ?, 'admin', NOW())");
    $stmt->execute([$admin_user, $admin_email, $hashed_password]);
    
    // Create config file
    $config_content = "<?php\n";
    $config_content .= "define('DB_HOST', '$db_host');\n";
    $config_content .= "define('DB_NAME', '$db_name');\n";
    $config_content .= "define('DB_USER', '$db_user');\n";
    $config_content .= "define('DB_PASS', '$db_pass');\n";
    $config_content .= "define('SITE_URL', 'http://' . \$_SERVER['HTTP_HOST'] . str_replace('/install', '', dirname(\$_SERVER['PHP_SELF'])));\n";
    $config_content .= "?>";
    
    file_put_contents('../includes/config.php', $config_content);
    
    echo json_encode(['success' => true]);
    
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}
?>
