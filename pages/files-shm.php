<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('file_management'); // or use is_admin() if you want only admins

// TEMP: show any PHP errors directly on the page while debugging.
// Remove or comment these three lines after it works.
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

/**
 * Simple local cleaner (so we don't depend on sanitize_input())
 */
function shm_clean($value) {
    if (is_array($value)) return $value;
    return trim(strip_tags($value));
}

/**
 * Format file size nicely
 */
if (!function_exists('format_file_size')) {
    function format_file_size($bytes)
    {
        if (!is_numeric($bytes) || $bytes <= 0) {
            return '0 B';
        }
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $power = floor(log($bytes, 1024));
        $power = min($power, count($units) - 1);
        return round($bytes / pow(1024, $power), 2) . ' ' . $units[$power];
    }
}

/**
 * Change file permissions safely
 */
if (!function_exists('change_file_permissions')) {
    function change_file_permissions($path, $permissions)
    {
        $permissions = trim($permissions);
        $permissions = ltrim($permissions, '0');
        if ($permissions === '') $permissions = '0';
        if (!preg_match('/^[0-7]{3,4}$/', $permissions)) {
            return false;
        }
        $mode = octdec($permissions);
        return @chmod($path, $mode);
    }
}

/**
 * Recursive delete (file or directory)
 */
function shm_rrmdir($path)
{
    if (!file_exists($path)) return true;
    if (!is_dir($path)) return @unlink($path);

    $items = scandir($path);
    foreach ($items as $item) {
        if ($item === '.' || $item === '..') continue;
        $sub = $path . DIRECTORY_SEPARATOR . $item;
        if (is_dir($sub)) {
            shm_rrmdir($sub);
        } else {
            @unlink($sub);
        }
    }
    return @rmdir($path);
}

/**
 * Normalize a relative path (removes .. and .)
 */
function shm_normalize_relative($path)
{
    $path = str_replace('\\', '/', $path);
    $path = '/' . ltrim($path, '/');
    $parts = [];
    foreach (explode('/', $path) as $part) {
        if ($part === '' || $part === '.') continue;
        if ($part === '..') {
            array_pop($parts);
        } else {
            $parts[] = $part;
        }
    }
    return '/' . implode('/', $parts);
}

/**
 * Build a safe absolute path inside base
 */
function shm_build_path($base, $relative)
{
    $base = rtrim(str_replace('\\', '/', $base), '/');
    $relative = shm_normalize_relative($relative);
    $full = $base . $relative;

    if (file_exists($full)) {
        $real = realpath($full);
        if ($real === false) return false;
        $real = str_replace('\\', '/', $real);
        if (strpos($real, $base) !== 0) return false;
        return $real;
    }

    $normalized = str_replace('\\', '/', $full);
    if (strpos($normalized, $base) !== 0) return false;
    return $normalized;
}

// -------- CONFIG: SHM PANEL ROOT --------
// This should resolve to /var/www/shm-panel if this file is in /var/www/shm-panel/pages
$panel_root = realpath(dirname(__DIR__));
if ($panel_root === false) {
    die("Could not resolve SHM panel root");
}
$panel_root = str_replace('\\', '/', $panel_root);

// -------- INPUTS --------
$current_path = isset($_GET['path']) ? $_GET['path'] : '/';
$current_path = shm_normalize_relative($current_path);

$search_query = isset($_GET['q']) ? shm_clean($_GET['q']) : '';
$sort         = isset($_GET['sort']) ? shm_clean($_GET['sort']) : 'name';

$files = [];

// Full path of current folder
$full_path = shm_build_path($panel_root, $current_path . '/');
if ($full_path === false) {
    die("Invalid path");
}

// -------- DOWNLOAD ACTION (GET) --------
if (isset($_GET['download'])) {
    $file_rel   = shm_clean($_GET['download']);
    $target_abs = shm_build_path($panel_root, $file_rel);

    if ($target_abs !== false && is_file($target_abs)) {
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($target_abs) . '"');
        header('Content-Length: ' . filesize($target_abs));
        header('Pragma: public');
        header('Cache-Control: must-revalidate, post-check=0, pre-check=0');
        readfile($target_abs);
        exit;
    } else {
        header('Location: files-shm.php?path=' . urlencode($current_path) . '&error=' . urlencode('Invalid file for download'));
        exit;
    }
}

// -------- POST ACTIONS --------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    // Upload file
    if (isset($_POST['upload_file']) && isset($_FILES['file'])) {
        $target_dir = rtrim($full_path, '/') . '/';
        if (is_dir($target_dir)) {
            $name = basename($_FILES['file']['name']);
            $target_file = $target_dir . $name;
            if (is_uploaded_file($_FILES['file']['tmp_name']) &&
                move_uploaded_file($_FILES['file']['tmp_name'], $target_file)) {

                header('Location: files-shm.php?path=' . urlencode($current_path) . '&success=' . urlencode('File uploaded successfully'));
                exit;
            } else {
                header('Location: files-shm.php?path=' . urlencode($current_path) . '&error=' . urlencode('File upload failed'));
                exit;
            }
        }
    }

    // Create folder
    if (isset($_POST['create_folder'])) {
        $folder_name = shm_clean($_POST['folder_name'] ?? '');
        $folder_name = trim(str_replace(['/', '\\'], '', $folder_name));
        if ($folder_name !== '') {
            $rel = ($current_path === '/' ? '' : $current_path) . '/' . $folder_name;
            $new_abs = shm_build_path($panel_root, $rel);
            if ($new_abs !== false && !file_exists($new_abs)) {
                @mkdir($new_abs, 0755, true);
                header('Location: files-shm.php?path=' . urlencode($current_path) . '&success=' . urlencode('Folder created'));
                exit;
            } else {
                header('Location: files-shm.php?path=' . urlencode($current_path) . '&error=' . urlencode('Folder exists or invalid'));
                exit;
            }
        }
    }

    // Change permissions
    if (isset($_POST['change_permissions'])) {
        $file_path_rel = shm_clean($_POST['file_path'] ?? '');
        $permissions   = shm_clean($_POST['permissions'] ?? '');
        $target_abs    = shm_build_path($panel_root, $file_path_rel);
        if ($target_abs !== false && file_exists($target_abs)) {
            if (change_file_permissions($target_abs, $permissions)) {
                header('Location: files-shm.php?path=' . urlencode($current_path) . '&success=' . urlencode('Permissions changed'));
                exit;
            } else {
                header('Location: files-shm.php?path=' . urlencode($current_path) . '&error=' . urlencode('Failed to change permissions'));
                exit;
            }
        }
    }

    // Delete file / folder
    if (isset($_POST['delete_path'])) {
        $file_path_rel = shm_clean($_POST['file_path'] ?? '');
        $target_abs    = shm_build_path($panel_root, $file_path_rel);
        if ($target_abs !== false && file_exists($target_abs)) {
            $ok = shm_rrmdir($target_abs);
            $msg = $ok ? 'Item deleted' : 'Failed to delete item';
            header('Location: files-shm.php?path=' . urlencode($current_path) . '&success=' . urlencode($msg));
            exit;
        }
    }

    // Rename
    if (isset($_POST['rename_path'])) {
        $file_path_rel = shm_clean($_POST['file_path'] ?? '');
        $new_name      = shm_clean($_POST['new_name'] ?? '');
        $new_name      = trim(str_replace(['/', '\\'], '', $new_name));

        if ($new_name !== '') {
            $old_abs = shm_build_path($panel_root, $file_path_rel);
            if ($old_abs !== false && file_exists($old_abs)) {
                $dir_rel = trim(str_replace('\\', '/', dirname($file_path_rel)), '/');
                $new_rel = ($dir_rel ? '/' . $dir_rel : '') . '/' . $new_name;
                $new_abs = shm_build_path($panel_root, $new_rel);
                if ($new_abs !== false) {
                    if (@rename($old_abs, $new_abs)) {
                        header('Location: files-shm.php?path=' . urlencode($current_path) . '&success=' . urlencode('Item renamed'));
                        exit;
                    } else {
                        header('Location: files-shm.php?path=' . urlencode($current_path) . '&error=' . urlencode('Failed to rename item'));
                        exit;
                    }
                }
            }
        }
    }
}

// -------- BUILD FILE LIST --------
if (is_dir($full_path)) {
    $items = scandir($full_path);
    foreach ($items as $item) {
        if ($item === '.' || $item === '..') continue;

        $abs = rtrim($full_path, '/') . '/' . $item;
        $is_dir = is_dir($abs);

        $rel = ($current_path === '/' ? '' : $current_path) . '/' . $item;
        $rel = shm_normalize_relative($rel);

        $size = 0;
        if (!$is_dir) {
            $size = @filesize($abs);
        }

        $perm = @fileperms($abs);
        $perm = $perm ? substr(sprintf('%o', $perm), -4) : '----';

        $files[] = [
            'name'        => $item,
            'relative'    => $rel,
            'is_dir'      => $is_dir,
            'size'        => $size,
            'permissions' => $perm,
            'modified'    => date('Y-m-d H:i:s', @filemtime($abs)),
            'extension'   => $is_dir ? '' : strtolower(pathinfo($item, PATHINFO_EXTENSION)),
        ];
    }
}

// Sort: dirs first, then by field
usort($files, function ($a, $b) use ($sort) {
    if ($a['is_dir'] && !$b['is_dir']) return -1;
    if (!$a['is_dir'] && $b['is_dir']) return 1;

    switch ($sort) {
        case 'size':
            return $a['size'] <=> $b['size'];
        case 'modified':
            return strcmp($a['modified'], $b['modified']);
        case 'type':
            return strcmp($a['extension'], $b['extension']);
        case 'name':
        default:
            return strcasecmp($a['name'], $b['name']);
    }
});

// Filter by search
if ($search_query !== '') {
    $q = strtolower($search_query);
    $files = array_filter($files, function ($f) use ($q) {
        return strpos(strtolower($f['name']), $q) !== false;
    });
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>SHM Panel File Manager</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: Arial, sans-serif; background: #f8f9fa; }

        .sidebar {
            position: fixed; left: 0; top: 0;
            width: 250px; height: 100%;
            background: #ffffff;
            border-right: 1px solid #dee2e6;
            padding: 20px 0;
        }
        .sidebar h2 {
            text-align: center;
            margin-bottom: 30px;
            padding: 0 20px;
            font-size: 18px;
        }
        .sidebar ul { list-style: none; padding: 0 10px; }
        .sidebar li { margin-bottom: 5px; }
        .sidebar a {
            display: block; color: #495057; text-decoration: none;
            padding: 8px 12px; border-radius: 4px;
            font-size: 14px; transition: all 0.2s;
        }
        .sidebar a:hover { background: #f1f3f5; }
        .sidebar a.active { background: #e7f1ff; color: #0d6efd; }

        .main-content { margin-left: 250px; padding: 20px; }
        .header {
            background: #ffffff; padding: 15px 20px;
            border: 1px solid #dee2e6; border-radius: 6px;
            margin-bottom: 20px;
            display: flex; justify-content: space-between; align-items: center;
        }
        .header h1 { font-size: 20px; margin: 0; }
        .header span { font-size: 13px; color: #6c757d; }

        .alert {
            padding: 10px 12px; border-radius: 4px;
            margin-bottom: 15px; font-size: 14px;
        }
        .alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .alert-error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }

        .card {
            background: #ffffff; border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.05);
            border: 1px solid #e5e7eb; margin-bottom: 20px;
        }
        .card-header {
            padding: 12px 16px; border-bottom: 1px solid #e5e7eb;
            display: flex; justify-content: space-between; align-items: center;
        }
        .card-header h3 { margin: 0; font-size: 16px; }
        .card-body { padding: 12px 16px 16px; }

        .breadcrumb { font-size: 13px; margin-bottom: 10px; }
        .breadcrumb a { color: #0d6efd; text-decoration: none; }
        .breadcrumb a:hover { text-decoration: underline; }

        .toolbar {
            display: flex; flex-wrap: wrap; gap: 8px;
            margin-bottom: 10px; align-items: center;
        }
        .btn {
            padding: 7px 12px; border-radius: 4px; border: none;
            cursor: pointer; font-size: 13px; text-decoration: none;
            display: inline-block;
        }
        .btn-primary { background: #0d6efd; color: #ffffff; }
        .btn-secondary { background: #f8f9fa; color: #212529; border: 1px solid #ced4da; }
        .btn-danger { background: #dc3545; color: #ffffff; }

        .search-input {
            padding: 6px 8px; border-radius: 4px;
            border: 1px solid #ced4da; font-size: 13px;
        }
        .select-input {
            padding: 6px 8px; border-radius: 4px;
            border: 1px solid #ced4da; font-size: 13px;
        }

        .inline-panel {
            margin-bottom: 10px; padding: 10px 12px;
            border-radius: 4px; border: 1px dashed #ced4da;
            background: #f8f9fa; font-size: 13px;
        }
        .inline-panel form {
            display: flex; flex-wrap: wrap; gap: 8px;
            align-items: center; margin-top: 6px;
        }

        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 8px 10px; border-bottom: 1px solid #e5e7eb; text-align: left; }
        th { background: #f8f9fa; color: #6c757d; font-weight: 500; }
        tr:hover td { background: #f8fafc; }
        .file-name a { color: #0d6efd; text-decoration: none; }
        .file-name a:hover { text-decoration: underline; }

        .badge-perms {
            display: inline-block; padding: 3px 6px;
            border-radius: 3px; background: #f1f3f5;
            border: 1px solid #dee2e6; font-size: 11px; color: #495057;
        }
        .actions { display: flex; gap: 4px; }

        @media (max-width: 768px) {
            .sidebar { position: static; width: 100%; height: auto; border-right: none; border-bottom: 1px solid #dee2e6; }
            .main-content { margin-left: 0; padding: 15px; }
            .header { flex-direction: column; align-items: flex-start; gap: 6px; }
        }
    </style>
</head>
<body>

<div class="sidebar">
    <h2>SHM Panel</h2>
    <ul>
        <li><a href="dashboard.php">Dashboard</a></li>
        <?php if (has_permission('domain_management')): ?>
        <li><a href="domains.php">Domains</a></li>
        <?php endif; ?>
        <?php if (has_permission('file_management')): ?>
        <li><a href="files-shm.php" class="active">SHM Files</a></li>
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
        <div>
            <h1>SHM Panel File Manager</h1>
            <span>Manage files inside your SHM panel (PHP, configs, assets).</span>
        </div>
        <div>
            <span>Logged in as <?php echo htmlspecialchars($_SESSION['username']); ?></span>
        </div>
    </div>

    <?php if (isset($_GET['success'])): ?>
        <div class="alert alert-success">
            <?php echo htmlspecialchars($_GET['success']); ?>
        </div>
    <?php endif; ?>

    <?php if (isset($_GET['error'])): ?>
        <div class="alert alert-error">
            <?php echo htmlspecialchars($_GET['error']); ?>
        </div>
    <?php endif; ?>

    <div class="card">
        <div class="card-header">
            <h3>Current Path</h3>
        </div>
        <div class="card-body">
            <div class="breadcrumb">
                <strong>SHM Root</strong>
                <?php
                echo ' / <a href="files-shm.php?path=%2F">Root</a>';
                $parts = explode('/', trim($current_path, '/'));
                $crumb = '/';
                foreach ($parts as $part) {
                    if ($part === '') continue;
                    $crumb .= $part . '/';
                    echo ' / <a href="files-shm.php?path=' . urlencode($crumb) . '">' . htmlspecialchars($part) . '</a>';
                }
                ?>
            </div>

            <div class="toolbar">
                <button type="button" class="btn btn-primary" onclick="togglePanel('upload-panel')">Upload</button>
                <button type="button" class="btn btn-secondary" onclick="togglePanel('folder-panel')">New Folder</button>

                <form method="get" style="display:flex; gap:8px; align-items:center;">
                    <input type="hidden" name="path" value="<?php echo htmlspecialchars($current_path); ?>">
                    <input type="text" name="q" class="search-input" placeholder="Search in this folder"
                           value="<?php echo htmlspecialchars($search_query); ?>">
                    <select name="sort" class="select-input">
                        <option value="name" <?php echo $sort === 'name' ? 'selected' : ''; ?>>Name</option>
                        <option value="size" <?php echo $sort === 'size' ? 'selected' : ''; ?>>Size</option>
                        <option value="modified" <?php echo $sort === 'modified' ? 'selected' : ''; ?>>Modified</option>
                        <option value="type" <?php echo $sort === 'type' ? 'selected' : ''; ?>>Type</option>
                    </select>
                    <button type="submit" class="btn btn-secondary">Apply</button>
                </form>
            </div>

            <div id="upload-panel" class="inline-panel" style="display:none;">
                <strong>Upload file to this folder</strong>
                <form method="post" enctype="multipart/form-data">
                    <input type="file" name="file" required>
                    <button type="submit" name="upload_file" class="btn btn-primary">Upload</button>
                    <button type="button" class="btn btn-secondary" onclick="togglePanel('upload-panel')">Cancel</button>
                </form>
            </div>

            <div id="folder-panel" class="inline-panel" style="display:none;">
                <strong>Create new folder</strong>
                <form method="post">
                    <input type="text" name="folder_name" placeholder="Folder name" required>
                    <button type="submit" name="create_folder" class="btn btn-primary">Create</button>
                    <button type="button" class="btn btn-secondary" onclick="togglePanel('folder-panel')">Cancel</button>
                </form>
            </div>

            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Size</th>
                        <th>Permissions</th>
                        <th>Modified</th>
                        <th style="text-align:right;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <?php if (empty($files)): ?>
                    <tr>
                        <td colspan="5" style="color:#6c757d;">This folder is empty.</td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($files as $f): ?>
                        <?php
                        $isDir = $f['is_dir'];
                        $rel   = $f['relative'];
                        $name  = $f['name'];
                        ?>
                        <tr>
                            <td class="file-name">
                                <?php if ($isDir): ?>
                                    <a href="files-shm.php?path=<?php echo urlencode($rel . '/'); ?>">
                                        📁 <?php echo htmlspecialchars($name); ?>
                                    </a>
                                <?php else: ?>
                                    📄 <?php echo htmlspecialchars($name); ?>
                                <?php endif; ?>
                            </td>
                            <td><?php echo $isDir ? '-' : format_file_size($f['size']); ?></td>
                            <td><span class="badge-perms"><?php echo htmlspecialchars($f['permissions']); ?></span></td>
                            <td><?php echo htmlspecialchars($f['modified']); ?></td>
                            <td>
                                <div class="actions">
                                    <?php if (!$isDir): ?>
                                        <!-- Edit file in panel editor -->
                                        <a href="editor.php?file=<?php echo urlencode($rel); ?>" class="btn btn-secondary btn-sm">Edit</a>

                                        <!-- Download file -->
                                        <a href="files-shm.php?path=<?php echo urlencode($current_path); ?>&download=<?php echo urlencode($rel); ?>"
                                           class="btn btn-secondary btn-sm">
                                            Download
                                        </a>
                                    <?php endif; ?>
                                    <button type="button" class="btn btn-secondary btn-sm"
                                            onclick="changePerms('<?php echo htmlspecialchars($rel); ?>', '<?php echo htmlspecialchars($f['permissions']); ?>')">
                                        Perms
                                    </button>
                                    <button type="button" class="btn btn-secondary btn-sm"
                                            onclick="renameItem('<?php echo htmlspecialchars($rel); ?>', '<?php echo htmlspecialchars($name); ?>')">
                                        Rename
                                    </button>
                                    <button type="button" class="btn btn-danger btn-sm"
                                            onclick="deleteItem('<?php echo htmlspecialchars($rel); ?>', '<?php echo htmlspecialchars($name); ?>')">
                                        Delete
                                    </button>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
                </tbody>
            </table>

            <!-- Hidden forms -->
            <form id="permForm" method="post" style="display:none;">
                <input type="hidden" name="file_path" value="">
                <input type="hidden" name="permissions" value="">
                <input type="hidden" name="change_permissions" value="1">
            </form>

            <form id="delForm" method="post" style="display:none;">
                <input type="hidden" name="file_path" value="">
                <input type="hidden" name="delete_path" value="1">
            </form>

            <form id="renameForm" method="post" style="display:none;">
                <input type="hidden" name="file_path" value="">
                <input type="hidden" name="new_name" value="">
                <input type="hidden" name="rename_path" value="1">
            </form>
        </div>
    </div>
</div>

<script>
    function togglePanel(id) {
        const el = document.getElementById(id);
        if (!el) return;
        el.style.display = (el.style.display === 'none' || el.style.display === '') ? 'block' : 'none';
    }

    function changePerms(filePath, currentPerms) {
        const newPerms = prompt('Change permissions for ' + filePath + ' (e.g. 755):', currentPerms);
        if (newPerms && /^[0-7]{3,4}$/.test(newPerms)) {
            const form = document.getElementById('permForm');
            form.file_path.value = filePath;
            form.permissions.value = newPerms;
            form.submit();
        }
    }

    function deleteItem(filePath, name) {
        if (confirm('Delete "' + name + '"?')) {
            const form = document.getElementById('delForm');
            form.file_path.value = filePath;
            form.submit();
        }
    }

    function renameItem(filePath, currentName) {
        const newName = prompt('Rename "' + currentName + '" to:', currentName);
        if (newName && newName.trim() !== '') {
            const form = document.getElementById('renameForm');
            form.file_path.value = filePath;
            form.new_name.value = newName.trim();
            form.submit();
        }
    }
</script>
</body>
</html>
