<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - SHM Panel</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: Arial, sans-serif; background: #f8f9fa; }
        .sidebar { position: fixed; left: 0; top: 0; width: 250px; height: 100%; background: #343a40; color: white; padding: 20px 0; }
        .sidebar h2 { text-align: center; margin-bottom: 30px; padding: 0 20px; }
        .sidebar ul { list-style: none; }
        .sidebar li { margin-bottom: 5px; }
        .sidebar a { display: block; color: #adb5bd; text-decoration: none; padding: 10px 20px; transition: all 0.3s; }
        .sidebar a:hover, .sidebar a.active { background: #495057; color: white; }
        .main-content { margin-left: 250px; padding: 20px; }
        .header { background: white; padding: 15px 20px; border-bottom: 1px solid #dee2e6; margin-bottom: 20px; display: flex; justify-content: between; align-items: center; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .stat-card h3 { color: #6c757d; margin-bottom: 10px; }
        .stat-number { font-size: 2em; font-weight: bold; color: #007bff; }
    </style>
</head>
<body>
    <div class="sidebar">
        <h2>SHM Panel</h2>
        <ul>
            <li><a href="dashboard.php" class="active">Dashboard</a></li>
            <?php if (has_permission('domain_management')): ?>
            <li><a href="domains.php">Domains</a></li>
            <?php endif; ?>
            <?php if (has_permission('file_management')): ?>
            <li><a href="files.php">Files</a></li>
            <?php endif; ?>
            <?php if (has_permission('database_management')): ?>
            <li><a href="database.php">Databases</a></li>
            <?php endif; ?>
            <?php if (has_permission('ssl_management')): ?>
            <li><a href="ssl.php">SSL</a></li>
            <?php endif; ?>
            <?php if (has_permission('dns_management')): ?>
            <li><a href="dns.php">DNS</a></li>
            <?php endif; ?>
            <?php if (is_admin()): ?>
            <li><a href="users.php">Users</a></li>
            <?php endif; ?>
            <li><a href="../logout.php">Logout</a></li>
        </ul>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Dashboard</h1>
            <div>Welcome, <?php echo $_SESSION['username']; ?>!</div>
        </div>

        <div class="stats">
            <?php
            // Get stats
            $user_id = $_SESSION['user_id'];
            
            $domains_count = $pdo->prepare("SELECT COUNT(*) FROM domains WHERE user_id = ?");
            $domains_count->execute([$user_id]);
            $domains = $domains_count->fetchColumn();
            
            $databases_count = $pdo->prepare("SELECT COUNT(*) FROM databases WHERE user_id = ?");
            $databases_count->execute([$user_id]);
            $databases = $databases_count->fetchColumn();
            
            $ssl_count = $pdo->prepare("SELECT COUNT(*) FROM ssl_certificates sc JOIN domains d ON sc.domain_id = d.id WHERE d.user_id = ?");
            $ssl_count->execute([$user_id]);
            $ssl = $ssl_count->fetchColumn();
            ?>
            
            <div class="stat-card">
                <h3>Domains</h3>
                <div class="stat-number"><?php echo $domains; ?></div>
            </div>
            <div class="stat-card">
                <h3>Databases</h3>
                <div class="stat-number"><?php echo $databases; ?></div>
            </div>
            <div class="stat-card">
                <h3>SSL Certificates</h3>
                <div class="stat-number"><?php echo $ssl; ?></div>
            </div>
        </div>

        <div class="recent-activity">
            <h2>Recent Activity</h2>
            <!-- Add recent activity log here -->
        </div>
    </div>
</body>
</html>