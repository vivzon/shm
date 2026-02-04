<?php

namespace App\Http\Controllers;

use App\Models\Domain;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DashboardController extends Controller
{
    public function index()
    {
        $user = Auth::user();

        // Account Stats
        $stats = [
            'domains_count' => $user->domains()->count(),
            'databases_count' => $user->databases()->count(),
            'emails_count' => 0, // Mock
            'disk_usage' => 150, // Mock MB
            'disk_quota' => $user->disk_quota,
        ];

        // Server Health (Mock for display)
        $serverHealth = [
            'cpu_load' => 15,
            'ram_usage' => 45,
            'disk_usage' => 20,
            'uptime' => '12 days, 4 hours',
        ];

        return view('dashboard', compact('stats', 'serverHealth'));
    }
}
