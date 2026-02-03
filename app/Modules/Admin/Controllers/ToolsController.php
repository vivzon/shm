<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;
use App\Core\Database;

class ToolsController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['admin']))
            $this->redirect('/login');
    }

    public function index()
    {
        $active_tab = $_GET['tab'] ?? 'ftp';
        $clients = Database::fetchAll("SELECT * FROM clients");
        $mail_domains = Database::fetchAll("SELECT * FROM mail_domains");
        $php_versions = ['8.1', '8.2', '8.3'];

        $this->view('Admin::tools/index', [
            'active_tab' => $active_tab,
            'clients' => $clients,
            'mail_domains' => $mail_domains,
            'php_versions' => $php_versions
        ]);
    }

    public function action()
    {
        $action = $this->input('ajax_action');
        try {
            if ($action == 'add_ftp') {
                $this->addFtp();
            } elseif ($action == 'list_ftp') {
                $this->listFtp();
            } elseif ($action == 'del_ftp') {
                $this->delFtp();
            } elseif ($action == 'add_mail') {
                $this->addMail();
            } elseif ($action == 'set_php_handler') {
                $version = $this->input('php_version');
                $out = cmd("set-php-handler " . escapeshellarg($version));
                $this->json(['status' => 'success', 'msg' => 'PHP Handler Updated: ' . $out]);
            } elseif ($action == 'set_network_card') {
                $card = $this->input('card');
                $out = cmd("set-network-card " . escapeshellarg($card));
                $this->json(['status' => 'success', 'msg' => 'Network Config Updated: ' . $out]);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }

    private function addFtp()
    {
        if ($this->input('pass') !== $this->input('pass2'))
            throw new \Exception("Passwords do not match");

        $sys_user = $this->input('sys_user');
        $ftp_user = $this->input('ftp_user') . '@' . $sys_user;
        $pass = password_hash($this->input('pass'), PASSWORD_BCRYPT);
        $home = "/var/www/clients/$sys_user/public_html";

        // Mocking posix for Win dev check
        if (!function_exists('posix_getpwnam')) {
            // Fallback or skip
            $uid = 1000;
            $gid = 1000;
        } else {
            $sys_user_info = posix_getpwnam($sys_user);
            if (!$sys_user_info)
                throw new \Exception("System user not found");
            $uid = $sys_user_info['uid'];
            $gid = $sys_user_info['gid'];
        }

        $count = Database::fetch("SELECT count(*) as c FROM ftp_users WHERE userid = ?", [$ftp_user]);
        if ($count['c'] > 0)
            throw new \Exception("FTP User already exists");

        Database::query(
            "INSERT INTO ftp_users (userid, passwd, homedir, uid, gid) VALUES (?,?,?,?,?)",
            [$ftp_user, $pass, $home, $uid, $gid]
        );

        $this->json(['status' => 'success', 'msg' => 'FTP Account Created']);
    }

    private function listFtp()
    {
        $users = Database::fetchAll("SELECT userid, homedir FROM ftp_users ORDER BY userid ASC");
        $this->json(['status' => 'success', 'data' => $users]);
    }

    private function delFtp()
    {
        Database::query("DELETE FROM ftp_users WHERE userid = ?", [$this->input('user')]);
        $this->json(['status' => 'success', 'msg' => 'Deleted']);
    }

    private function addMail()
    {
        $domain = $this->input('domain');
        $full = $this->input('prefix') . "@" . $domain;
        $pass = password_hash($this->input('mail_pass'), PASSWORD_BCRYPT);

        $d = Database::fetch("SELECT id FROM mail_domains WHERE domain = ?", [$domain]);
        if (!$d)
            throw new \Exception("Domain not found for mail");

        Database::query("INSERT INTO mail_users (domain_id, email, password) VALUES (?,?,?)", [$d['id'], $full, $pass]);
        $this->json(['status' => 'success', 'msg' => 'Mailbox Created']);
    }
}
