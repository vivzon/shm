<?php
// This file will be generated during installation
if (!file_exists(__DIR__ . '/config.php')) {
    header('Location: ../install/');
    exit;
}

require_once __DIR__ . '/config.php';

// Database connection
try {
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8", DB_USER, DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage());
}

// Start session
session_start();
?>