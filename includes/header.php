<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($pageTitle); ?> Management - SHM Panel</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --bg-body: #f8fafc;
            --bg-sidebar: #ffffff;
            --bg-header: #ffffff;
            --bg-card: #ffffff;
            --border-soft: #e2e8f0;
            --primary: #3b82f6;
            --primary-soft: #dbeafe;
            --primary-dark: #2563eb;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --info: #06b6d4;
            --radius-lg: 12px;
            --radius-md: 8px;
            --radius-sm: 6px;
            --shadow-soft: 0 4px 12px rgba(15, 23, 42, 0.08);
            --shadow-medium: 0 10px 25px rgba(15, 23, 42, 0.1);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Poppins', system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-body);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            line-height: 1.6;
        }

        /* SIDEBAR */
        .sidebar {
            position: fixed;
            left: 0;
            top: 0;
            width: 260px;
            height: 100vh;
            background: var(--bg-sidebar);
            border-right: 1px solid var(--border-soft);
            padding: 20px 16px;
            display: flex;
            flex-direction: column;
            gap: 16px;
            z-index: 1000;
            overflow-y: auto;
        }
        .sidebar-brand {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
            padding: 0 8px;
        }
        .brand-logo {
            width: 38px;
            height: 38px;
            border-radius: 10px;
            background: linear-gradient(135deg, var(--primary), var(--primary-dark));
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            font-size: 18px;
            box-shadow: var(--shadow-soft);
        }
        .brand-text { display: flex; flex-direction: column; }
        .brand-title { font-size: 17px; font-weight: 700; color: var(--text-main); }
        .brand-subtitle { font-size: 11px; color: var(--text-muted); margin-top: -2px; }

        .sidebar-section-title {
            font-size: 11px;
            text-transform: uppercase;
            color: var(--text-muted);
            margin: 16px 0 8px;
            letter-spacing: .08em;
            font-weight: 400;
            padding: 0 8px;
        }

        .sidebar ul {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .sidebar li { width: 100%; }
        .sidebar a {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 12px;
            border-radius: var(--radius-md);
            text-decoration: none;
            color: var(--text-muted);
            font-size: 14px;
            font-weight: 500;
            transition: all 0.2s ease;
            position: relative;
        }
        .nav-icon {
            width: 20px;
            text-align: center;
            font-size: 16px;
        }
        .sidebar a:hover {
            background: #f1f5f9;
            color: var(--primary-dark);
            transform: translateX(2px);
        }
        .sidebar a.active {
            background: var(--primary-soft);
            color: var(--primary-dark);
            font-weight: 600;
            box-shadow: var(--shadow-soft);
        }
        .sidebar a.active::before {
            content: '';
            position: absolute;
            left: 0;
            top: 50%;
            transform: translateY(-50%);
            width: 3px;
            height: 60%;
            background: var(--primary);
            border-radius: 0 2px 2px 0;
        }
        .sidebar-footer {
            margin-top: auto;
            padding: 16px 8px 0;
            border-top: 1px solid var(--border-soft);
            font-size: 11px;
            color: var(--text-muted);
        }
        .sidebar-footer span { display: block; margin-bottom: 4px; }

        /* MAIN CONTENT */
        .main-content {
            margin-left: 260px;
            flex: 1;
            min-height: 100vh;
            padding: 24px 28px 32px;
        }
        .page-container {
            max-width: 1400px;
            margin: 0 auto;
        }

        /* HEADER */
        .header {
            background: var(--bg-header);
            border-radius: var(--radius-lg);
            padding: 20px 24px;
            border: 1px solid var(--border-soft);
            box-shadow: var(--shadow-soft);
            margin-bottom: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }
        .header-left { display: flex; flex-direction: column; gap: 6px; }
        .page-title { font-size: 24px; font-weight: 700; color: var(--text-main); }
        .page-subtitle { font-size: 14px; color: var(--text-muted); }
        .header-right { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; justify-content: flex-end; }
        .chip {
            font-size: 12px;
            padding: 6px 12px;
            border-radius: 20px;
            border: 1px solid var(--border-soft);
            color: var(--text-muted);
            background: #f8fafc;
            font-weight: 500;
        }
        .chip-live {
            border-color: rgba(16, 185, 129, 0.3);
            color: var(--success);
            background: #ecfdf5;
        }
        .user-info { 
            display: flex; 
            align-items: center; 
            gap: 12px; 
            padding: 8px 12px;
            background: #f8fafc;
            border-radius: var(--radius-md);
            border: 1px solid var(--border-soft);
        }
        .user-avatar {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--primary), var(--primary-dark));
            color: white;
            font-weight: 600;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: var(--shadow-soft);
        }
        .user-meta { display: flex; flex-direction: column; }
        .user-name { font-size: 14px; font-weight: 600; }
        .user-role { font-size: 12px; color: var(--text-muted); }

        /* ALERTS */
        .alert {
            border-radius: var(--radius-md);
            padding: 14px 16px;
            margin-bottom: 20px;
            font-size: 14px;
            display: flex;
            align-items: center;
            gap: 10px;
            border-left: 4px solid transparent;
        }
        .alert-success {
            background: #ecfdf5;
            border-color: var(--success);
            color: #065f46;
        }
        .alert-error {
            background: #fef2f2;
            border-color: var(--danger);
            color: #991b1b;
        }
        .alert-danger { background: var(--danger-soft); border: 1px solid #fecaca; color: #991b1b; }
        .card { background: var(--bg-card); border-radius: var(--radius-lg); box-shadow: var(--shadow-soft); border: 1px solid var(--border-soft); margin-bottom: 18px; }
        .card-header { padding: 12px 16px; border-bottom: 1px solid var(--border-soft); }
        .card-title { font-size: 15px; font-weight: 500; }
        .card-subtitle { font-size: 12px; color: var(--text-muted); }
        .card-body { padding: 16px 16px 18px; }
        .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px 18px; }
        .form-group { display: flex; flex-direction: column; gap: 4px; }
        label { font-size: 14px; font-weight: 500; }
        .field-hint { font-size: 11px; color: var(--text-muted); }
        input, select { width: 100%; padding: 8px 9px; border-radius: 8px; border: 1px solid #d1d5db; font-size: 14px; outline: none; transition: all 0.12s ease; background: #ffffff; }
        input:focus, select:focus { border-color: var(--primary); box-shadow: 0 0 0 1px var(--primary-soft); }
        .form-actions { margin-top: 14px; display: flex; justify-content: flex-end; }
        .btn { padding: 8px 16px; border-radius: 999px; border: none; cursor: pointer; font-size: 14px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; text-decoration: none; }
        .btn-primary { background: var(--primary); color: #ffffff; }
        .btn-danger { background: var(--danger); color: #ffffff; }
        .btn-sm { padding: 6px 12px; font-size: 12px; }
        .table-wrapper { width: 100%; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid var(--border-soft); white-space: nowrap; }
        th { font-weight: 500; color: var(--text-muted); background: #f9fafb; }
        tr:hover td { background: #f9fafb; }
        .badge { display: inline-block; padding: 3px 8px; font-size: 11px; border-radius: 999px; }
        .badge-success { background: #ecfdf3; color: #166534; border: 1px solid #bbf7d0; }
        .badge-muted { background: #f3f4f6; color: var(--text-muted); border: 1px solid #e5e7eb; }
        
        /* NEW STYLES for Collapsible Sidebar */
        .sidebar .submenu { display: none; margin-left: 20px; padding-left: 10px; border-left: 1px solid var(--border-soft); }
        .sidebar li.has-submenu > a { cursor: pointer; }
        .sidebar li.has-submenu.open > .submenu { display: block; }
        .sidebar .arrow { transition: transform 0.2s ease; display: inline-block; margin-right: 6px; }
        .sidebar li.has-submenu.open > a .arrow { transform: rotate(90deg); }

        /* NEW STYLES for Tabs */
        .tab-nav { border-bottom: 1px solid var(--border-soft); margin-bottom: 16px; display: flex; gap: 4px; }
        .tab-btn { background: none; border: none; padding: 8px 16px; font-size: 14px; font-weight: 500; color: var(--text-muted); cursor: pointer; border-bottom: 2px solid transparent; }
        .tab-btn.active { color: var(--primary); border-bottom-color: var(--primary); }
        .tab-pane { display: none; }
        .tab-pane.active { display: block; }
        
        @media (max-width: 840px) { .sidebar { display: none; } .main-content { margin-left: 0; padding: 14px; } }
    </style>
</head>
<body>

    <aside class="sidebar" id="sidebar">
        <div>
            <div class="sidebar-brand">
                <div class="brand-logo">S</div>
                <div class="brand-text"><div class="brand-title">SHM Panel</div><div class="brand-subtitle">Simple Hosting Manager</div></div>
            </div>
            <div class="sidebar-section-title">Main Menu</div>
            <ul>
                <li>
                    <a href="/dashboard">
                        <span class="nav-icon" <?php if ($slug === 'dashboard') echo 'class="active"'; ?>>🏠</span>
                        <span>Dashboard</span>
                    </a>
                </li>
            </ul>
            <!-- === UPDATED COLLAPSIBLE SIDEBAR STRUCTURE === -->
            <div class="sidebar-section-title">Website Management</div>
            <ul>
                <?php if (has_permission('domain_management')): ?><li><a href="/domains" <?php if ($slug === 'domains') echo 'class="active"'; ?>><span class="nav-icon">🌐</span><span>Domains</span></a></li><?php endif; ?>
                <?php if (has_permission('ssl_management')): ?><li><a href="/ssl" <?php if ($slug === 'ssl') echo 'class="active"'; ?>><span class="nav-icon">🔐</span><span>SSL Certificates</span></a></li><?php endif; ?>
                <?php if (has_permission('database_management')): ?><li><a href="/database" <?php if ($slug === 'database') echo 'class="active"'; ?>><span class="nav-icon">🗄️</span><span>Databases</span></a></li><?php endif; ?>
            </ul>

            <div class="sidebar-section-title">File Management</div>
            <ul>
                <?php if (has_permission('file_management')): ?>
                <li class="has-submenu">
                    <a><span class="arrow">▶</span><span class="nav-icon">📁</span><span>Files</span></a>
                    <ul class="submenu">
                        <li><a href="/files" <?php if ($slug === 'files') echo 'class="active"'; ?>>File Manager</a></li>
                        <li><a href="#">FTP Accounts</a></li>
                        <li><a href="#">Backups</a></li>
                    </ul>
                </li>
                <?php endif; ?>
            </ul>

            <div class="sidebar-section-title">Advanced Settings</div>
            <ul>
                <li class="has-submenu">
                    <a><span class="arrow">▶</span><span class="nav-icon">🛠️</span><span>Advanced</span></a>
                    <ul class="submenu">
                        <?php if (has_permission('dns_management')): ?>
                        <li><a href="/dns" <?php if ($slug === 'dns') echo 'class="active"'; ?>>DNS Management</a></li>
                        <?php endif; ?>
                        <li><a href="#">PHP Config</a></li>
                        <li><a href="#">SSH Access</a></li>
                    </ul>
                </li>
            </ul>

            <div class="sidebar-section-title">Account</div>
            <ul>
                <li><a href="#"><span class="nav-icon">🔑</span><span>Reset Password</span></a></li>
                <?php if (is_admin()): ?>
                <li><a href="/users" <?php if ($slug === 'users') echo 'class="active"'; ?>><span class="nav-icon">👥</span><span>User Management</span></a></li>
                <?php endif; ?>
                <li><a href="/logout" ><span class="nav-icon">⏏️</span><span>Logout</span></a></li>
            </ul>
        </div>
        <div class="sidebar-footer">
            <span>Logged in as: <strong><?= htmlspecialchars($_SESSION['username']); ?></strong></span>
        </div>
    </aside>
