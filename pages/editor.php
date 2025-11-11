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

// Handle file save
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $content = $_POST['content'];
    if (file_put_contents($full_path, $content)) {
        // Log file edit
        $stmt = $pdo->prepare("INSERT INTO files (user_id, domain_id, file_path, file_name, file_size, file_type, permissions, created_at, modified_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE modified_at = NOW()");
        $stmt->execute([$_SESSION['user_id'], $domain_id, dirname($file_path), basename($file_path), filesize($full_path), mime_content_type($full_path), substr(sprintf('%o', fileperms($full_path)), -4)]);
        
        header('Location: files.php?domain_id=' . $domain_id . '&path=' . urlencode(dirname($file_path)) . '&success=File saved successfully');
        exit;
    } else {
        $error = "Failed to save file";
    }
}

$content = file_get_contents($full_path);
$file_info = [
    'name' => basename($file_path),
    'path' => $file_path,
    'size' => filesize($full_path),
    'permissions' => substr(sprintf('%o', fileperms($full_path)), -4),
    'modified' => date('Y-m-d H:i:s', filemtime($full_path))
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Editor - SHM Panel</title>
    <style>
        .editor-container { width: 100%; height: 70vh; border: 1px solid #ddd; }
        .editor-header { background: #f8f9fa; padding: 10px; border-bottom: 1px solid #ddd; }
        .editor-toolbar { background: #e9ecef; padding: 5px; border-bottom: 1px solid #ddd; }
        textarea { width: 100%; height: 100%; border: none; font-family: monospace; padding: 10px; }
    </style>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>File Editor: <?php echo $file_info['name']; ?></h1>
        </div>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <div class="file-info">
                        <strong>Path:</strong> <?php echo $file_info['path']; ?> | 
                        <strong>Size:</strong> <?php echo format_file_size($file_info['size']); ?> | 
                        <strong>Permissions:</strong> <?php echo $file_info['permissions']; ?> | 
                        <strong>Modified:</strong> <?php echo $file_info['modified']; ?>
                    </div>
                </div>
                <div class="card-body">
                    <?php if (isset($error)): ?>
                        <div class="alert alert-danger"><?php echo $error; ?></div>
                    <?php endif; ?>

                    <form method="post">
                        <div class="editor-toolbar">
                            <button type="button" onclick="formatCode()">Format</button>
                            <button type="button" onclick="insertTemplate()">Insert Template</button>
                            <select onchange="changeSyntax(this.value)">
                                <option value="">Select Syntax</option>
                                <option value="php">PHP</option>
                                <option value="html">HTML</option>
                                <option value="css">CSS</option>
                                <option value="js">JavaScript</option>
                                <option value="sql">SQL</option>
                            </select>
                        </div>
                        
                        <div class="editor-container">
                            <textarea name="content" id="fileContent" spellcheck="false"><?php echo htmlspecialchars($content); ?></textarea>
                        </div>
                        
                        <div style="margin-top: 10px;">
                            <button type="submit" class="btn btn-primary">Save File</button>
                            <a href="files.php?domain_id=<?php echo $domain_id; ?>&path=<?php echo urlencode(dirname($file_path)); ?>" class="btn">Cancel</a>
                            <button type="button" onclick="downloadFile()" class="btn">Download</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        function formatCode() {
            // Basic code formatting - in production, use a proper formatter
            const content = document.getElementById('fileContent');
            content.value = content.value.replace(/\t/g, '    '); // Convert tabs to spaces
        }
        
        function insertTemplate() {
            const templates = {
                'php': '<?php\n// PHP file\necho "Hello World";\n?>',
                'html': '<!DOCTYPE html>\n<html>\n<head>\n    <title>Page</title>\n</head>\n<body>\n    \n</body>\n</html>',
                'css': '/* CSS Styles */\nbody {\n    margin: 0;\n    padding: 0;\n}'
            };
            
            const type = prompt('Select template type (php, html, css):');
            if (templates[type]) {
                document.getElementById('fileContent').value = templates[type];
            }
        }
        
        function changeSyntax(syntax) {
            // Syntax highlighting would be implemented with a proper editor
            console.log('Syntax changed to:', syntax);
        }
        
        function downloadFile() {
            const content = document.getElementById('fileContent').value;
            const blob = new Blob([content], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = '<?php echo $file_info['name']; ?>';
            a.click();
            URL.revokeObjectURL(url);
        }
        
        // Auto-save draft every 30 seconds
        setInterval(() => {
            const content = document.getElementById('fileContent').value;
            localStorage.setItem('file_draft_<?php echo md5($file_path); ?>', content);
        }, 30000);
        
        // Load draft on page load
        window.addEventListener('load', () => {
            const draft = localStorage.getItem('file_draft_<?php echo md5($file_path); ?>');
            if (draft && confirm('Found unsaved draft. Load it?')) {
                document.getElementById('fileContent').value = draft;
            }
        });
    </script>
</body>
</html>