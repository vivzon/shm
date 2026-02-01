<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;

class DashboardController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['client'])) {
            $this->redirect('/login');
        }

        // Mock Stats for now, or fetch from System Model
        // In legacy index.php, it showed static cards or pulled from `get-stats` maybe restricted?
        // Legacy cpanel/index.php wasn't fully analyzed but likely simple.

        $this->view('Client::dashboard', []);
    }
}
