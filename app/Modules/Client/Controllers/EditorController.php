<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Core\Database;

class EditorController extends Controller
{
    private $user_id;

    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
        $this->user_id = $_SESSION['cid'];
    }

    private function normalizepath($path)
    {
        $path = str_replace(['\\', '//'], '/', $path);
        $path = '/' . ltrim($path, '/');
        $parts = array_filter(explode('/', $path));
        $safe = [];
        foreach ($parts as $part) {
            if ($part === '.')
                continue;
            if ($part === '..')
                array_pop($safe);
            else
                $safe[] = $part;
        }
        return '/' . implode('/', $safe);
    }

    public function index()
    {
        $domain_id = isset($_GET['domain_id']) ? (int) $_GET['domain_id'] : 0;
        $file = $_GET['file'] ?? '';

        $domain = Database::fetch("SELECT * FROM domains WHERE id = ? AND client_id = ?", [$domain_id, $this->user_id]);

        if (!$domain)
            die("Invalid Domain");

        $base_root = $domain['document_root'] ?? "/var/www/clients/" . $_SESSION['client'] . "/public_html";

        // Windows Dev Mapping
        if (DIRECTORY_SEPARATOR === '\\') {
            if (strpos($base_root, '/var') === 0 || strpos($base_root, '/') === 0) {
                $base_root = __DIR__ . '/../../../../../storage/' . ($_SESSION['client'] ?? 'guest');
                $base_root = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $base_root);
            }
        }

        $base_path = rtrim($base_root, '/');
        $cleaned_file = $this->normalizepath($file);
        $abs_path = $base_path . $cleaned_file;

        if (strpos($abs_path, $base_path) !== 0 || !is_file($abs_path)) {
            die("Invalid File: " . htmlspecialchars($cleaned_file));
        }

        $msg = "";
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            file_put_contents($abs_path, $_POST['content']);
            $msg = "Saved successfully at " . date("H:i:s");
        }

        $content = file_get_contents($abs_path);

        $this->view('Client::editor/index', [
            'content' => $content,
            'file_path' => $cleaned_file,
            'domain_id' => $domain_id,
            'msg' => $msg
        ]);
    }
}
