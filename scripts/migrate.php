<?php
/**
 * SHM Panel Migration Runner
 * Usage: php scripts/migrate.php
 */

// Load Configuration
$configFile = __DIR__ . '/../app/Modules/Common/Config/config.php'; // Adjust path if needed
// Fallback to shared config logic or checking environment variables
// Since this is a CLI script, we might need to parse the config.sh or the PHP config

$dbHost = '127.0.0.1';
$dbName = 'shm_panel';
$dbUser = 'root'; // Default fallback, should override
$dbPass = '';

// Try to read from /etc/shm/config.sh first (System Config)
if (file_exists('/etc/shm/config.sh')) {
    $conf = file_get_contents('/etc/shm/config.sh');
    preg_match('/DB_NAME=\'(.*?)\'/', $conf, $m1);
    preg_match('/DB_USER=\'(.*?)\'/', $conf, $m2);
    preg_match('/DB_PASS=\'(.*?)\'/', $conf, $m3);

    if (isset($m1[1]))
        $dbName = $m1[1];
    if (isset($m2[1]))
        $dbUser = $m2[1];
    if (isset($m3[1]))
        $dbPass = $m3[1];
}

echo "SHM Panel Migration Tool\n";
echo "Database: $dbName\n";
echo "User: $dbUser\n";

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4", $dbUser, $dbPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Get list of migrations
    $files = glob(__DIR__ . '/migrations/*.sql');

    foreach ($files as $file) {
        $filename = basename($file);
        echo "Running migration: $filename... ";

        $sql = file_get_contents($file);

        // Split into commands if needed, or run as block
        // RENAME TABLE and ALTER usually can be one block in modern MySQL drivers if not mixed with others too weirdly
        // But for safety let's assume valid SQL dump format

        try {
            $pdo->exec($sql);
            echo "DONE\n";
        } catch (PDOException $e) {
            echo "FAILED\n";
            echo "Error: " . $e->getMessage() . "\n";
            // Check if column already exists (Duplicate column name) - naive check
            if (strpos($e->getMessage(), "Duplicate column name") !== false) {
                echo "Skipping... (Already applied?)\n";
            } else {
                exit(1);
            }
        }
    }

    echo "All migrations completed successfully.\n";

} catch (PDOException $e) {
    die("DB Connection Failed: " . $e->getMessage() . "\n");
}
