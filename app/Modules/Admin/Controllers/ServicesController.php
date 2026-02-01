<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;

class ServicesController extends Controller
{
    private $services = [
        'nginx' => 'Web Server',
        'mariadb' => 'MariaDB SQL',
        'php8.2-fpm' => 'PHP 8.2 Engine',
        'proftpd' => 'FTP Server',
        'postfix' => 'Mail Delivery'
    ];

    public function index()
    {
        if (!isset($_SESSION['admin'])) {
            $this->redirect('/admin/login');
        }

        // Check statuses
        $serviceStatus = [];
        foreach ($this->services as $id => $name) {
            $serviceStatus[$id] = trim(cmd("service-status $id")) == 'active';
        }

        $this->view('Admin::services/index', [
            'services' => $this->services,
            'serviceStatus' => $serviceStatus
        ]);
    }

    public function action()
    {
        if (!isset($_SESSION['admin'])) {
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        }

        $action = $this->input('ajax_action');

        try {
            if ($action === 'service_action') {
                $op = $this->input('op');
                $srv = $this->input('service');

                if (!in_array($op, ['start', 'stop', 'restart', 'reload'])) {
                    throw new \Exception("Invalid Operation");
                }

                // Immediate response for better UI feel, assuming command works/queues
                // For real async, we might need a job queue, but legacy did flush().

                if (function_exists('fastcgi_finish_request')) {
                    $this->json(['status' => 'success', 'msg' => 'Command Sent']);
                    fastcgi_finish_request();
                } else {
                    // If we can't detach, we wait, but user UI might hang a bit.
                    // On Windows dev, it's mocked anyway.
                }

                cmd("service-control " . $op . " " . escapeshellarg($srv));

                if (!function_exists('fastcgi_finish_request')) {
                    $this->json(['status' => 'success', 'msg' => 'Command Executed']);
                }
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }
}
