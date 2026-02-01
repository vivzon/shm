<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;

class BackupsController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
    }

    public function index()
    {
        $this->view('Client::backups/index');
    }

    public function action()
    {
        $username = $_SESSION['client'];
        $action = $this->input('ajax_action');

        try {
            if ($action == 'create_backup') {
                $out = cmd("shm-manage backup create " . escapeshellarg($username));
                // Assuming cmd returns output or void. If void/success, JSON ok.
                $this->json(['status' => 'success', 'msg' => 'Applied Successfully']);
            }
            if ($action == 'list_backups') {
                $out = cmd("shm-manage backup list " . escapeshellarg($username));
                $backups = [];
                if ($out) {
                    foreach (explode("\n", $out) as $line) {
                        if (!trim($line))
                            continue;
                        $parts = preg_split('/\s+/', trim($line));
                        if (count($parts) >= 5) {
                            $backups[] = [
                                'name' => end($parts),
                                'size' => $parts[0],
                                'date' => $parts[1] . ' ' . $parts[2] . ' ' . $parts[3]
                            ];
                        }
                    }
                }
                $this->json(['status' => 'success', 'data' => $backups]);
            }
            if ($action == 'restore_backup') {
                cmd("shm-manage backup restore " . escapeshellarg($username) . " " . escapeshellarg($this->input('file')));
                $this->json(['status' => 'success', 'msg' => 'Applied Successfully']);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }
}
