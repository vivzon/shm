<?php
function is_logged_in() {
    return isset($_SESSION['user_id']);
}

function require_login() {
    if (!is_logged_in()) {
        header('Location: ../index.php');
        exit;
    }
}

function is_admin() {
    return isset($_SESSION['user_role']) && $_SESSION['user_role'] === 'admin';
}

function require_admin() {
    require_login();
    if (!is_admin()) {
        header('HTTP/1.0 403 Forbidden');
        echo "Access denied. Admin privileges required.";
        exit;
    }
}

function has_permission($permission) {
    global $pdo;
    
    if (!is_logged_in()) return false;
    if (is_admin()) return true;
    
    $stmt = $pdo->prepare("SELECT allowed FROM user_permissions WHERE user_id = ? AND permission = ?");
    $stmt->execute([$_SESSION['user_id'], $permission]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result && $result['allowed'] == 1;
}

function check_permission($permission) {
    if (!has_permission($permission)) {
        header('HTTP/1.0 403 Forbidden');
        echo "Access denied. You don't have permission to access this feature.";
        exit;
    }
}
?>