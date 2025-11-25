<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();

// Handle file selection and content saving
$filePath = 'files/index.php'; // Default file to edit
if (isset($_GET['file'])) {
    $filePath = 'files/' . basename($_GET['file']); // Prevent path traversal
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    // Save changes to file
    $fileContent = $_POST['editor'];
    file_put_contents($filePath, $fileContent);
}

// Load file content for the editor
$fileContent = file_get_contents($filePath);

// List available PHP files in the "files" directory
$files = array_diff(scandir('files'), ['.', '..']);

// Handle file management (create, delete, rename)
if (isset($_POST['action'])) {
    if ($_POST['action'] === 'create') {
        $newFile = 'files/' . $_POST['filename'];
touch($newFile);
    } elseif ($_POST['action'] === 'delete' && file_exists($filePath)) {
        unlink($filePath);
    } elseif ($_POST['action'] === 'rename' && isset($_POST['new_name'])) {
        rename($filePath, 'files/' . $_POST['new_name']);
        $filePath = 'files/' . $_POST['new_name'];
    }
}

// Run the selected file and capture the output (for preview)
ob_start();
include($filePath);
$previewContent = ob_get_clean();

// Define a list of keywords and colors for syntax highlighting (simplified for PHP)
$php_keywords = ['echo', 'if', 'else', 'foreach', 'while', 'function', 'class', 'public', 'private', 'return', 'const'];
$highlighted_code = highlight_php_code($fileContent, $php_keywords);

// Syntax highlighting function
function highlight_php_code($code, $keywords) {
    $pattern = '/\b(' . implode('|', $keywords) . ')\b/';
    return preg_replace_callback($pattern, function($matches) {
        return '<span style="color: #e91e63; font-weight: bold;">' . $matches[0] . '</span>';
    }, $code);
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Custom PHP Code Editor</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: space-between;
            padding: 20px;
        }
        .editor-container {
            width: 48%;
        }
        #editor {
            width: 100%;
            height: 500px;
            font-family: Consolas, "Courier New", monospace;
            font-size: 14px;
            line-height: 1.6;
            padding: 10px;
            border: 1px solid #ccc;
            background-color: #282c34;
            color: #f8f8f2;
            border-radius: 4px;
            white-space: pre-wrap;
            overflow-wrap: break-word;
            box-sizing: border-box;
        }
        #preview {
            width: 48%;
            height: 500px;
            padding: 10px;
height: 500px;
            padding: 10px;
            border: 1px solid #ccc;
            background-color: #f7f7f7;
            box-sizing: border-box;
            overflow-y: auto;
        }
        h2 {
            font-size: 20px;
        }
        .file-actions {
            margin-top: 20px;
        }
        .file-actions input[type="text"] {
            padding: 5px;
            margin-bottom: 10px;
            width: 100%;
            font-size: 14px;
        }
    </style>
</head>
<body>

    <!-- Editor Section -->
    <div class="editor-container">
        <h2>Code Editor</h2>
        <form method="POST" action="editor.php">
            <textarea name="editor" id="editor"><?php echo htmlspecialchars($fileContent); ?></textarea>
            <br>
            <button type="submit">Save Changes</button>
        </form>

        <!-- File Browser Section -->
<h3>File Browser</h3>
        <ul>
            <?php foreach ($files as $file): ?>
                <li><a href="?file=<?php echo urlencode($file); ?>"><?php echo $file; ?></a></li>
            <?php endforeach; ?>
        </ul>

        <!-- File Management Section -->
        <div class="file-actions">
            <form method="POST" action="editor.php">
                <h3>Create a New File</h3>
                <input type="text" name="filename" placeholder="Enter filename" required>
                <button type="submit" name="action" value="create">Create File</button>
            </form>

            <form method="POST" action="editor.php">
                <h3>Rename File</h3>
                <input type="text" name="new_name" placeholder="New filename" required>
                <button type="submit" name="action" value="rename">Rename File</button>
            </form>

            <form method="POST" action="editor.php">
                <h3>Delete File</h3>
                <button type="submit" name="action" value="delete">Delete Current File</button>
            </form>
        </div>
    </div>

    <!-- Preview Section -->
    <div id="preview">
        <h3>Preview Output</h3>
<div><?php echo nl2br($previewContent); ?></div>
    </div>

</body>
</html>
