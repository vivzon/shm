nul not found
<?php
// Common header for all pages
?>
<div class="sidebar">
    <h2>SHM Panel</h2>
    <ul>
        <li><a href="dashboard.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'dashboard.php' ? 'active' : ''; ?>">Dashboard</a></li>
        <?php if (has_permission('domain_management')): ?>
        <li><a href="domains.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'domains.php' ? 'active' : ''; ?>">Domains</a></li>
        <?php endif; ?>
        <?php if (has_permission('file_management')): ?>
        <li><a href="files.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'files.php' ? 'active' : ''; ?>">Files</a></li>
        <?php endif; ?>
        <?php if (has_permission('database_management')): ?>
        <li><a href="database.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'database.php' ? 'active' : ''; ?>">Databases</a></li>
        <?php endif; ?>
        <?php if (has_permission('ssl_management')): ?>
        <li><a href="ssl.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'ssl.php' ? 'active' : ''; ?>">SSL</a></li>
        <?php endif; ?>
        <?php if (has_permission('dns_management')): ?>
        <li><a href="dns.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'dns.php' ? 'active' : ''; ?>">DNS</a></li>
        <?php endif; ?>
        <?php if (is_admin()): ?>
        <li><a href="users.php" class="<?php echo basename($_SERVER['PHP_SELF']) == 'users.php' ? 'active' : ''; ?>">Users</a></li>
        <?php endif; ?>
        <li><a href="../logout.php">Logout</a></li>
    </ul>
</div>