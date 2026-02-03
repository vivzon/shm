<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Modules\Client\Models\Domain;

class SecurityController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
    }

    public function index()
    {
        $tab = $this->input('tab', 'ssh');
        $this->view('Client::security/index', ['active_tab' => $tab]);
    }

    public function action()
    {
        $username = $_SESSION['client'];
        $action = $this->input('ajax_action');

        try {
            if ($action == 'add_ssh') {
                cmd("shm-manage ssh-key add " . escapeshellarg($username) . " " . escapeshellarg($this->input('key')));
                $this->json(['status' => 'success', 'msg' => 'Key Added']);
            }
            if ($action == 'del_ssh') {
                cmd("shm-manage ssh-key delete " . escapeshellarg($username) . " " . (int) $this->input('line'));
                $this->json(['status' => 'success', 'msg' => 'Key Deleted']);
            }
            if ($action == 'list_ssh') {
                $out = cmd("shm-manage ssh-key list " . escapeshellarg($username));
                $lines = $out ? array_filter(explode("\n", $out)) : [];
                $this->json(['status' => 'success', 'data' => array_values($lines)]);
            }
            if ($action == 'issue_ssl') {
                $domain = $this->input('domain');
                // Verify domain ownership
                $d = Domain::existsForClient($domain, $_SESSION['cid']);
                if (!$d)
                    throw new \Exception("Invalid Domain");

                $out = cmd("issue-ssl " . escapeshellarg($domain));
                $this->json(['status' => 'success', 'msg' => 'SSL Issuance Triggered', 'output' => $out]);
            }
            if ($action == 'delete_ssl') {
                $domain = $this->input('domain');
                $out = cmd("delete-ssl " . escapeshellarg($domain));
                $this->json(['status' => 'success', 'msg' => 'SSL Removed', 'output' => $out]);
            }
            if ($action == 'list_ssl_domains') {
                $domains = Domain::getAll($_SESSION['cid']);
                $this->json(['status' => 'success', 'data' => $domains]);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }
}
