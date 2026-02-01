<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;

class LogsController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['admin']))
            $this->redirect('/login');
    }

    public function index()
    {
        $this->view('Admin::logs/index');
    }

    public function action()
    {
        try {
            if ($this->input('ajax_action') == 'get_logs') {
                $type = $this->input('type');
                if (!in_array($type, ['auth', 'web', 'sys']))
                    throw new \Exception("Invalid Log Type");
                $output = cmd("shm-manage get-logs " . escapeshellarg($type) . " 50");
                $this->json(['status' => 'success', 'data' => $output]);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }
}
