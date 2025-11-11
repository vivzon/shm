<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('file_management');

$domain_id = intval($_GET['domain_id']);
$file_path = isset($_GET['file']) ? $_GET['file'] : '';

// Verify domain ownership
$stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
$stmt->execute([$domain_id, $_SESSION['user_id']]);
$domain = $stmt->fetch();

if (!$domain) {
    die("Domain not found or access denied");
}

$full_path = $domain['document_root'] . $file_path;

if (!file_exists($full_path)) {
    die("File not found");
}

// Set headers for download
header('Content-Description: File Transfer');
header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename="' . basename($full_path) . '"');
header('Expires: 0');
header('Cache-Control: must-revalidate');
header('Pragma: public');
header('Content-Length: ' . filesize($full_path));
readfile($full_path);
exit;