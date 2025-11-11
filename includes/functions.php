<?php
function sanitize_input($data) {
    return htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
}

function generate_random_string($length = 16) {
    $characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $randomString = '';
    for ($i = 0; $i < $length; $i++) {
        $randomString .= $characters[rand(0, strlen($characters) - 1)];
    }
    return $randomString;
}

function format_file_size($bytes) {
    if ($bytes >= 1073741824) {
        return number_format($bytes / 1073741824, 2) . ' GB';
    } elseif ($bytes >= 1048576) {
        return number_format($bytes / 1048576, 2) . ' MB';
    } elseif ($bytes >= 1024) {
        return number_format($bytes / 1024, 2) . ' KB';
    } else {
        return $bytes . ' bytes';
    }
}

function change_file_permissions($file_path, $permissions) {
    return chmod($file_path, octdec($permissions));
}

function create_database_user($db_name, $db_user, $db_pass) {
    global $pdo;
    
    try {
        // Create database
        $pdo->exec("CREATE DATABASE IF NOT EXISTS `$db_name`");
        
        // Create user (MySQL 8.0+ syntax)
        $pdo->exec("CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass'");
        $pdo->exec("GRANT ALL PRIVILEGES ON `$db_name`.* TO '$db_user'@'localhost'");
        $pdo->exec("FLUSH PRIVILEGES");
        
        return true;
    } catch (Exception $e) {
        return false;
    }
}

function delete_database_user($db_name, $db_user) {
    global $pdo;
    
    try {
        $pdo->exec("DROP DATABASE IF EXISTS `$db_name`");
        $pdo->exec("DROP USER IF EXISTS '$db_user'@'localhost'");
        $pdo->exec("FLUSH PRIVILEGES");
        
        return true;
    } catch (Exception $e) {
        return false;
    }
}

function get_user_domains($user_id) {
    global $pdo;
    
    $stmt = $pdo->prepare("SELECT * FROM domains WHERE user_id = ? ORDER BY domain_name");
    $stmt->execute([$user_id]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function add_dns_record($domain_id, $type, $name, $value, $ttl = 3600, $priority = null) {
    global $pdo;
    
    $stmt = $pdo->prepare("INSERT INTO dns_records (domain_id, record_type, record_name, record_value, ttl, priority, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())");
    return $stmt->execute([$domain_id, $type, $name, $value, $ttl, $priority]);
}

function get_dns_records($domain_id) {
    global $pdo;
    
    $stmt = $pdo->prepare("SELECT * FROM dns_records WHERE domain_id = ? ORDER BY record_type, record_name");
    $stmt->execute([$domain_id]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
?>