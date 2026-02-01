<?php
// bootstrap/app.php

// 1. PSR-4 Autoloader
spl_autoload_register(function ($class) {
    // Project-specific namespace prefix
    $prefix = 'App\\';

    // Base directory for the namespace prefix
    $base_dir = __DIR__ . '/../app/';

    // Does the class use the namespace prefix?
    $len = strlen($prefix);
    if (strncmp($prefix, $class, $len) !== 0) {
        // no, move to the next registered autoloader
        return;
    }

    // Get the relative class name
    $relative_class = substr($class, $len);

    // Replace the namespace prefix with the base directory, replace namespace
    // separators with directory separators in the relative class name, append
    // with .php
    $file = $base_dir . str_replace('\\', '/', $relative_class) . '.php';

    // If the file exists, require it
    if (file_exists($file)) {
        require $file;
    }
});

// 2. Load Configuration
// simplified loader
$config = [];
if (file_exists(__DIR__ . '/../config/app.php')) $config['app'] = require __DIR__ . '/../config/app.php';
if (file_exists(__DIR__ . '/../config/database.php')) $config['database'] = require __DIR__ . '/../config/database.php';

// 3. Start Session
if (session_status() === PHP_SESSION_NONE) {
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    if (!filter_var($host, FILTER_VALIDATE_IP) && $host !== 'localhost') {
        $parts = explode('.', $host);
        if (count($parts) >= 2) {
            $base_domain = '.' . implode('.', array_slice($parts, -2));
            session_set_cookie_params([
                'lifetime' => 0,
                'path' => '/',
                'domain' => $base_domain,
                'secure' => true,
                'httponly' => true
            ]);
        }
    }
    session_start();
}

// 4. Initialize Core
require_once __DIR__ . '/../app/Core/Helpers.php';
