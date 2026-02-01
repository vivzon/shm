<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Core\Database;

class FilesController extends Controller
{
    private $user_id;
    private $base_path;
    private $current_path;
    private $domain_id;
    private $setup_error = null;

    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
        $this->user_id = $_SESSION['cid'];

        // Increase execution limits
        ini_set('upload_max_filesize', '2048M');
        ini_set('post_max_size', '2048M');
        ini_set('memory_limit', '2048M');
        ini_set('max_execution_time', '3600');
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

    private function buildpath($base, $relative)
    {
        $base = rtrim(str_replace('\\', '/', $base), '/');
        $relative = $this->normalizepath($relative);
        $full = $base . $relative;
        if (strpos($full, $base) !== 0)
            return false;
        return $full;
    }

    private function rrmdir($path)
    {
        if (!file_exists($path))
            return true;
        if (!is_dir($path))
            return @unlink($path);
        foreach (scandir($path) as $item) {
            if ($item === '.' || $item === '..')
                continue;
            if (!$this->rrmdir($path . DIRECTORY_SEPARATOR . $item))
                return false;
        }
        return @rmdir($path);
    }

    private function rcopy($src, $dst)
    {
        if (file_exists($dst))
            $this->rrmdir($dst);
        if (is_dir($src)) {
            mkdir($dst);
            $files = scandir($src);
            foreach ($files as $file) {
                if ($file != "." && $file != "..")
                    $this->rcopy("$src/$file", "$dst/$file");
            }
        } else if (file_exists($src)) {
            copy($src, $dst);
        }
    }

    public function index()
    {
        $this->setup();
        $full_path = $this->buildpath($this->base_path, $this->current_path);

        // Auto-create subfolders if missing
        if (!file_exists($full_path)) {
            mkdir($full_path, 0777, true);
            clearstatcache(true, $full_path);
        }

        $items = [];
        if (is_dir($full_path)) {
            foreach (scandir($full_path) as $item) {
                if ($item === '.' || $item === '..')
                    continue;
                $abs = $full_path . '/' . $item;
                $items[] = [
                    'name' => $item,
                    'is_dir' => is_dir($abs),
                    'size' => is_dir($abs) ? '-' : round(filesize($abs) / 1024, 2) . ' KB',
                    'perm' => substr(sprintf('%o', fileperms($abs)), -4),
                    'date' => date("Y-m-d H:i", filemtime($abs)),
                    'rel' => $this->normalizepath($this->current_path . '/' . $item)
                ];
            }
            usort($items, function ($a, $b) {
                if ($a['is_dir'] && !$b['is_dir'])
                    return -1;
                if (!$a['is_dir'] && $b['is_dir'])
                    return 1;
                return strnatcasecmp($a['name'], $b['name']);
            });
        }

        // Get Domain Info for UI
        $domain = Database::fetch("SELECT * FROM domains WHERE id = ?", [$this->domain_id]);

        $this->view('Client::files/manager', [
            'items' => $items,
            'domain_id' => $this->domain_id,
            'current_path' => $this->current_path,
            'is_writable' => is_writable($full_path),
            'domain' => $domain
        ]);
    }

    public function action()
    {
        $this->setup();
        $full_path = $this->buildpath($this->base_path, $this->current_path);

        // POST Handling
        $is_ajax = isset($_POST['ajax']) || isset($_POST['ajax_action']);

        // Helper
        $fm_return = function ($status, $msg = '', $data = []) use ($is_ajax) {
            if ($is_ajax) {
                echo json_encode(array_merge(['status' => $status, 'msg' => $msg], $data));
            } else {
                $this->redirect("/files?domain_id={$this->domain_id}&path={$this->current_path}");
            }
            exit;
        };

        if (isset($_POST['upload_files'])) {
            $count = 0;
            $errors = [];
            if (!isset($_FILES['files']['name']))
                $fm_return('error', 'No files received');

            foreach ($_FILES['files']['name'] as $key => $name) {
                $target = $full_path . '/' . basename($name);
                if (move_uploaded_file($_FILES['files']['tmp_name'][$key], $target)) {
                    $count++;
                } else {
                    $errors[] = "$name: Move failed";
                }
            }
            $count > 0 ? $fm_return('success', "$count files uploaded") : $fm_return('error', 'Upload failed');
        }

        if (isset($_POST['create_item'])) {
            $name = preg_replace('/[^a-zA-Z0-9\._-]/', '', $_POST['name']);
            $target = $full_path . '/' . $name;
            if (file_exists($target))
                $fm_return('error', 'Item already exists');

            if ($_POST['type'] == 'folder') {
                if (mkdir($target, 0775))
                    $fm_return('success', 'Folder created');
            } else {
                if (file_put_contents($target, '') !== false)
                    $fm_return('success', 'File created');
            }
            $fm_return('error', 'Creation failed');
        }

        if (isset($_POST['delete_paths'])) {
            $count = 0;
            foreach ($_POST['paths'] as $p) {
                $abs = $this->buildpath($this->base_path, $p);
                if ($abs === $this->base_path)
                    continue;
                if ($abs && $this->rrmdir($abs))
                    $count++;
            }
            $fm_return('success', "$count items deleted");
        }

        // ZIP, RENAME, COPY, MOVE, UNZIP, PREVIEW, CHMOD, DOWNLOAD logic 
        // copied almost verbatim but using $this->base_path

        if (isset($_POST['zip_paths'])) {
            $zip = new \ZipArchive();
            $zip_name = $full_path . '/' . (count($_POST['paths']) > 1 ? 'archive_' . date('Hi') . '.zip' : basename($_POST['paths'][0]) . '.zip');
            if ($zip->open($zip_name, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) === TRUE) {
                foreach ($_POST['paths'] as $p) {
                    $abs = $this->buildpath($this->base_path, $p);
                    if (is_file($abs))
                        $zip->addFile($abs, basename($abs));
                    if (is_dir($abs)) {
                        $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($abs), \RecursiveIteratorIterator::LEAVES_ONLY);
                        foreach ($files as $name => $file) {
                            if (!$file->isDir()) {
                                $filePath = $file->getRealPath();
                                $relativePath = substr($filePath, strlen($abs) + 1);
                                $zip->addFile($filePath, basename($abs) . '/' . $relativePath);
                            }
                        }
                    }
                }
                $zip->close();
                $fm_return('success', 'Archive created');
            }
            $fm_return('error', 'Zip creation failed');
        }

        if (isset($_POST['rename_item'])) {
            $old = $this->buildpath($this->base_path, $_POST['old']);
            $new = $this->buildpath($this->base_path, $_POST['new_name']);
            if ($old && $new && rename($old, $new))
                $fm_return('success', 'Renamed');
            $fm_return('error', 'Rename failed');
        }

        if (isset($_POST['copy_move_items'])) {
            $action = $_POST['action'];
            $dest_folder = $this->buildpath($this->base_path, $_POST['destination']);
            $count = 0;
            if ($dest_folder) {
                foreach ($_POST['paths'] as $p) {
                    $src = $this->buildpath($this->base_path, $p);
                    $name = basename($src);
                    $dest = $dest_folder . '/' . $name;
                    if ($src && $action == 'move' && rename($src, $dest))
                        $count++;
                    if ($src && $action == 'copy') {
                        $this->rcopy($src, $dest);
                        $count++;
                    }
                }
                $fm_return('success', "$count items processed");
            }
            $fm_return('error', 'Invalid destination');
        }

        if (isset($_POST['unzip_item'])) {
            $zip_file = $this->buildpath($this->base_path, $_POST['item']);
            $zip = new \ZipArchive;
            if ($zip->open($zip_file) === TRUE) {
                $zip->extractTo(dirname($zip_file));
                $zip->close();
                $fm_return('success', 'Extracted successfully');
            }
            $fm_return('error', 'Extraction failed');
        }

        if (isset($_POST['preview_item'])) {
            $file = $this->buildpath($this->base_path, $_POST['item']);
            if (is_file($file)) {
                $content = file_get_contents($file, false, NULL, 0, 10240);
                echo json_encode(['status' => 'success', 'type' => 'code', 'content' => htmlspecialchars($content)]);
            } else {
                echo json_encode(['status' => 'error', 'msg' => 'File not found']);
            }
            exit;
        }

        if (isset($_POST['chmod_item'])) {
            $target = $this->buildpath($this->base_path, $_POST['item']);
            $mode = intval($_POST['mode'], 8);
            if ($target && chmod($target, $mode))
                $fm_return('success', 'Permissions updated');
            $fm_return('error', 'Failed');
        }

        if (isset($_POST['download_items'])) {
            $paths = $_POST['paths'];
            if (count($paths) === 1 && is_file($this->buildpath($this->base_path, $paths[0]))) {
                $file = $this->buildpath($this->base_path, $paths[0]);
                header('Content-Type: application/octet-stream');
                header('Content-Disposition: attachment; filename="' . basename($file) . '"');
                header('Content-Length: ' . filesize($file));
                readfile($file);
                exit;
            } else {
                $zip_name = 'download_' . date('Ymd_His') . '.zip';
                $tmp_zip = sys_get_temp_dir() . '/' . $zip_name;
                $zip = new \ZipArchive();
                if ($zip->open($tmp_zip, \ZipArchive::CREATE)) {
                    foreach ($paths as $p) {
                        $abs = $this->buildpath($this->base_path, $p);
                        if (is_dir($abs) || is_file($abs)) {
                            if (is_file($abs))
                                $zip->addFile($abs, basename($abs));
                            if (is_dir($abs)) {
                                $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($abs), \RecursiveIteratorIterator::LEAVES_ONLY);
                                foreach ($files as $name => $file) {
                                    if (!$file->isDir()) {
                                        $relativePath = substr($file->getRealPath(), strlen($abs) + 1);
                                        $zip->addFile($file->getRealPath(), basename($abs) . '/' . $relativePath);
                                    }
                                }
                            }
                        }
                    }
                    $zip->close();
                    header('Content-Type: application/zip');
                    header('Content-disposition: attachment; filename=' . $zip_name);
                    header('Content-Length: ' . filesize($tmp_zip));
                    readfile($tmp_zip);
                    unlink($tmp_zip);
                    exit;
                }
            }
            exit;
        }

        $fm_return('error', 'Unknown Action');
    }

    private function setup()
    {
        $this->domain_id = isset($_REQUEST['domain_id']) ? (int) $_REQUEST['domain_id'] : 0;
        $this->current_path = isset($_REQUEST['path']) ? $this->normalizepath($_REQUEST['path']) : '/';

        $domain = Database::fetch("SELECT * FROM domains WHERE id = ? AND client_id = ?", [$this->domain_id, $this->user_id]);

        if (!$domain) {
            $first = Database::fetch("SELECT id FROM domains WHERE client_id = ? LIMIT 1", [$this->user_id]);
            if ($first) {
                $this->redirect("/files?domain_id={$first['id']}&path=/");
            }
            die("No domains found. Please add a domain first.");
        }

        $default_root = "/var/www/clients/" . ($_SESSION['client'] ?? 'default') . "/public_html";
        $this->base_path = rtrim($domain['document_root'] ?? $default_root, '/');

        // Windows Dev Mapping
        if (DIRECTORY_SEPARATOR === '\\') {
            if (strpos($this->base_path, '/var') === 0 || strpos($this->base_path, '/') === 0) {
                $this->base_path = __DIR__ . '/../../../../../storage/' . ($_SESSION['client'] ?? 'guest');
                $this->base_path = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $this->base_path);
            }
        }

        if (!file_exists($this->base_path)) {
            mkdir($this->base_path, 0777, true);
        }
    }
}
