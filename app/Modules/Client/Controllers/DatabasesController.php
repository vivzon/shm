<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Core\Database;
use App\Modules\Client\Models\DatabaseManager;
use App\Modules\Client\Models\Domain;

class DatabasesController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');

        $clientId = $_SESSION['cid'];
        $page = isset($_GET['page']) ? (int) $_GET['page'] : 1;
        $perPage = 10;
        $offset = ($page - 1) * $perPage;

        $myDbs = DatabaseManager::getDatabases($clientId, $perPage, $offset);
        $total = DatabaseManager::getDatabaseCount($clientId);
        $totalPages = ceil($total / $perPage);

        $domains = Domain::getAll($clientId);
        $dbUsers = DatabaseManager::getDbUsers($clientId);

        // Base domain logic
        $host = $_SERVER['HTTP_HOST'];
        $parts = explode('.', $host);
        $baseDomain = (count($parts) >= 2) ? implode('.', array_slice($parts, -2)) : $host;

        $this->view('Client::databases/index', [
            'myDbs' => $myDbs,
            'total' => $total,
            'totalPages' => $totalPages,
            'currentPage' => $page,
            'domains' => $domains,
            'dbUsers' => $dbUsers,
            'baseDomain' => $baseDomain,
            'username' => $_SESSION['client']
        ]);
    }

    public function action()
    {
        if (!isset($_SESSION['cid']))
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        $clientId = $_SESSION['cid'];
        $username = $_SESSION['client'];
        $action = $this->input('ajax_action');

        try {
            if ($action == 'add_db') {
                $this->addDb($clientId, $username);
            } elseif ($action == 'add_db_user') {
                $this->addDbUser($clientId, $username);
            } elseif ($action == 'delete_db') {
                $this->deleteDb($clientId);
            } elseif ($action == 'reset_db_pass') {
                $this->resetDbPass($clientId);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()]);
        }
    }

    private function addDb($clientId, $username)
    {
        $limits = DatabaseManager::getLimits($clientId);
        $curr = DatabaseManager::getDatabaseCount($clientId);
        if ($curr >= $limits['max_databases'])
            throw new \Exception("Plan database limit reached.");

        $dbName = $username . "_" . preg_replace('/[^a-z0-9_]/', '', $this->input('db_name'));
        $domainId = $this->input('domain_id') ?: null;

        DatabaseManager::createDatabase($clientId, $domainId, $dbName);

        if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
            Database::pdo()->exec("CREATE DATABASE IF NOT EXISTS `$dbName`");
        } else {
            $out = cmd("mysql-tool create-db " . escapeshellarg($dbName));
            if ($out)
                throw new \Exception("Backend Error: " . $out);
        }
        $this->json(['status' => 'success', 'msg' => 'Database Created']);
    }

    private function addDbUser($clientId, $username)
    {
        $dbUser = $username . "_" . preg_replace('/[^a-z0-9_]/', '', $this->input('db_user'));
        $targetDb = preg_replace('/[^a-z0-9_]/', '', $this->input('target_db')); // Validate access?

        // Check if target DB belongs to user?
        if (!DatabaseManager::hasDatabaseAccess($clientId, $targetDb))
            throw new \Exception("Access Denied to Target DB");

        DatabaseManager::createDbUser($clientId, $dbUser);

        if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
            $pass = $this->input('db_pass');
            $quotedPass = Database::pdo()->quote($pass);
            Database::pdo()->exec("CREATE USER IF NOT EXISTS '$dbUser'@'localhost' IDENTIFIED BY $quotedPass");
            Database::pdo()->exec("GRANT ALL PRIVILEGES ON `$targetDb`.* TO '$dbUser'@'localhost'");
            Database::pdo()->exec("FLUSH PRIVILEGES");
        } else {
            $out = cmd("mysql-tool create-user " . escapeshellarg($dbUser) . " " . escapeshellarg($this->input('db_pass')) . " " . escapeshellarg($targetDb));
            if ($out)
                throw new \Exception("Backend Error: " . $out);
        }
        $this->json(['status' => 'success', 'msg' => 'User Created']);
    }

    private function deleteDb($clientId)
    {
        $dbName = $this->input('db_name');
        if (!DatabaseManager::hasDatabaseAccess($clientId, $dbName))
            throw new \Exception("Access Denied");

        DatabaseManager::deleteDatabase($clientId, $dbName);

        if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
            Database::pdo()->exec("DROP DATABASE IF EXISTS `$dbName`");
        } else {
            $out = cmd("mysql-tool delete-db " . escapeshellarg($dbName));
            if ($out)
                throw new \Exception("Backend Error: " . $out);
        }
        $this->json(['status' => 'success', 'msg' => 'Database Deleted']);
    }

    private function resetDbPass($clientId)
    {
        $dbUser = $this->input('db_user');
        $pass = $this->input('new_pass');

        if (!DatabaseManager::hasDbUserAccess($clientId, $dbUser))
            throw new \Exception("Access Denied");

        if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
            $quotedPass = Database::pdo()->quote($pass);
            Database::pdo()->exec("ALTER USER '$dbUser'@'localhost' IDENTIFIED BY $quotedPass");
            Database::pdo()->exec("FLUSH PRIVILEGES");
        } else {
            $out = cmd("mysql-tool reset-pass " . escapeshellarg($dbUser) . " " . escapeshellarg($pass));
            if ($out)
                throw new \Exception("Backend Error: " . $out);
        }
        $this->json(['status' => 'success', 'msg' => 'Password Reset']);
    }
}
