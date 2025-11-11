<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('file_management');

$current_path = isset($_GET['path']) ? $_GET['path'] : '/';
$domain_id = isset($_GET['domain_id']) ? intval($_GET['domain_id']) : null;

// Get user domains for selector
$domains = get_user_domains($_SESSION['user_id']);

if ($domain_id) {
    // Verify domain ownership
    $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
    $stmt->execute([$domain_id, $_SESSION['user_id']]);
    $domain = $stmt->fetch();
    
    if (!$domain) {
        die("Domain not found or access denied");
    }
    
    $base_path = $domain['document_root'];
    $full_path = $base_path . $current_path;
    
    // Handle file operations
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (isset($_POST['upload_file']) && isset($_FILES['file'])) {
            $target_file = $full_path . basename($_FILES['file']['name']);
            if (move_uploaded_file($_FILES['file']['tmp_name'], $target_file)) {
                header('Location: files.php?domain_id=' . $domain_id . '&path=' . urlencode($current_path) . '&success=File uploaded');
                exit;
            }
        }
        
        if (isset($_POST['create_folder'])) {
            $folder_name = sanitize_input($_POST['folder_name']);
            $new_folder = $full_path . $folder_name;
            if (!file_exists($new_folder)) {
                mkdir($new_folder, 0755);
                header('Location: files.php?domain_id=' . $domain_id . '&path=' . urlencode($current_path) . '&success=Folder created');
                exit;
            }
        }
        
        if (isset($_POST['change_permissions'])) {
            $file_path = sanitize_input($_POST['file_path']);
            $permissions = sanitize_input($_POST['permissions']);
            if (change_file_permissions($base_path . $file_path, $permissions)) {
                header('Location: files.php?domain_id=' . $domain_id . '&path=' . urlencode($current_path) . '&success=Permissions changed');
                exit;
            }
        }
    }
    
    // Get files and folders
    $files = [];
    if (is_dir($full_path)) {
        $items = scandir($full_path);
        foreach ($items as $item) {
            if ($item != '.' && $item != '..') {
                $file_path = $full_path . $item;
                $files[] = [
                    'name' => $item,
                    'path' => $file_path,
                    'is_dir' => is_dir($file_path),
                    'size' => filesize($file_path),
                    'permissions' => substr(sprintf('%o', fileperms($file_path)), -4),
                    'modified' => date('Y-m-d H:i:s', filemtime($file_path))
                ];
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Management - SHM Panel</title>
    <style>
        .file-manager { display: flex; }
        .sidebar { width: 200px; background: #f8f9fa; padding: 20px; }
        .content { flex: 1; padding: 20px; }
        .breadcrumb { margin-bottom: 20px; }
        .file-list { border: 1px solid #ddd; }
        .file-item { display: flex; align-items: center; padding: 10px; border-bottom: 1px solid #eee; }
        .file-item:hover { background: #f8f9fa; }
        .file-icon { margin-right: 10px; }
        .file-actions { margin-left: auto; }
    </style>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>File Management</h1>
        </div>

        <div class="file-manager">
            <div class="sidebar">
                <h3>Domains</h3>
                <ul>
                    <?php foreach ($domains as $domain): ?>
                    <li>
                        <a href="files.php?domain_id=<?php echo $domain['id']; ?>&path=/">
                            <?php echo $domain['domain_name']; ?>
                        </a>
                    </li>
                    <?php endforeach; ?>
                </ul>
            </div>

            <div class="content">
                <?php if ($domain_id): ?>
                    <div class="breadcrumb">
                        <a href="files.php?domain_id=<?php echo $domain_id; ?>&path=/">Root</a>
                        <?php
                        $path_parts = explode('/', trim($current_path, '/'));
                        $current = '';
                        foreach ($path_parts as $part) {
                            if (!empty($part)) {
                                $current .= '/' . $part;
                                echo ' / <a href="files.php?domain_id=' . $domain_id . '&path=' . urlencode($current) . '">' . $part . '</a>';
                            }
                        }
                        ?>
                    </div>

                    <div class="toolbar">
                        <button onclick="showUploadForm()">Upload</button>
                        <button onclick="showCreateFolderForm()">New Folder</button>
                    </div>

                    <div class="file-list">
                        <?php foreach ($files as $file): ?>
                        <div class="file-item">
                            <div class="file-icon">
                                <?php echo $file['is_dir'] ? '📁' : '📄'; ?>
                            </div>
                            <div class="file-name">
                                <?php if ($file['is_dir']): ?>
                                    <a href="files.php?domain_id=<?php echo $domain_id; ?>&path=<?php echo urlencode($current_path . $file['name'] . '/'); ?>">
                                        <?php echo $file['name']; ?>
                                    </a>
                                <?php else: ?>
                                    <?php echo $file['name']; ?>
                                <?php endif; ?>
                            </div>
                            <div class="file-size">
                                <?php echo $file['is_dir'] ? '' : format_file_size($file['size']); ?>
                            </div>
                            <div class="file-permissions">
                                <?php echo $file['permissions']; ?>
                            </div>
                            <div class="file-actions">
                                <?php if (!$file['is_dir']): ?>
                                    <a href="download.php?domain_id=<?php echo $domain_id; ?>&file=<?php echo urlencode($current_path . $file['name']); ?>">Download</a>
                                    <a href="editor.php?domain_id=<?php echo $domain_id; ?>&file=<?php echo urlencode($current_path . $file['name']); ?>">Edit</a>
                                <?php endif; ?>
                                <button onclick="changePermissions('<?php echo $current_path . $file['name']; ?>', '<?php echo $file['permissions']; ?>')">Permissions</button>
                            </div>
                        </div>
                        <?php endforeach; ?>
                    </div>

                    <!-- Upload Form -->
                    <div id="uploadForm" style="display: none;">
                        <form method="post" enctype="multipart/form-data">
                            <input type="file" name="file" required>
                            <button type="submit" name="upload_file">Upload</button>
                            <button type="button" onclick="hideUploadForm()">Cancel</button>
                        </form>
                    </div>

                    <!-- Create Folder Form -->
                    <div id="createFolderForm" style="display: none;">
                        <form method="post">
                            <input type="text" name="folder_name" placeholder="Folder name" required>
                            <button type="submit" name="create_folder">Create</button>
                            <button type="button" onclick="hideCreateFolderForm()">Cancel</button>
                        </form>
                    </div>

                <?php else: ?>
                    <p>Please select a domain to manage files.</p>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <script>
        function showUploadForm() {
            document.getElementById('uploadForm').style.display = 'block';
        }
        function hideUploadForm() {
            document.getElementById('uploadForm').style.display = 'none';
        }
        function showCreateFolderForm() {
            document.getElementById('createFolderForm').style.display = 'block';
        }
        function hideCreateFolderForm() {
            document.getElementById('createFolderForm').style.display = 'none';
        }
        function changePermissions(filePath, currentPerms) {
            const newPerms = prompt('Change permissions for ' + filePath + ':', currentPerms);
            if (newPerms && /^[0-7]{3,4}$/.test(newPerms)) {
                const form = document.createElement('form');
                form.method = 'post';
                form.innerHTML = `
                    <input type="hidden" name="file_path" value="${filePath}">
                    <input type="hidden" name="permissions" value="${newPerms}">
                    <input type="hidden" name="change_permissions" value="1">
                `;
                document.body.appendChild(form);
                form.submit();
            }
        }
    </script>
</body>
</html>