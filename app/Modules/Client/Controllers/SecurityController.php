<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;

class SecurityController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
    }

    public function index()
    {
        $this->view('Client::security/index');
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
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }
}
