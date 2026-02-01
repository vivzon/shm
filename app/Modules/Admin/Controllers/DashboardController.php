<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;

class DashboardController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['admin'])) {
            $this->redirect('/admin/login');
        }

        // Stats
        $stats = explode('|', (string) cmd("get-stats"));

        $this->view('Admin::dashboard', ['stats' => $stats]);
    }
}
