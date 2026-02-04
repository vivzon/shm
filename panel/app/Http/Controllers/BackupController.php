<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class BackupController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $user = Auth::user();
        // In a real app, we would scan the backup directory for files
        $backupPath = "/home/{$user->name}/backups";

        // Mocking list for UI
        $backups = [
            ['filename' => "{$user->name}_backup_20240101_120000.tar.gz", 'size' => '45MB', 'date' => '2024-01-01 12:00:00'],
        ];

        return view('backups.index', compact('backups'));
    }

    public function store(Request $request)
    {
        $user = Auth::user();
        $backupDir = "/home/{$user->name}/backups";

        try {
            // Call bash script: backup-create <username> <backup_dir>
            $this->server->execute('backup-create', [
                $user->name,
                $backupDir
            ]);

            return redirect()->back()->with('success', 'Backup started successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Backup failed: ' . $e->getMessage());
        }
    }

    public function download($filename)
    {
        $user = Auth::user();
        $filePath = "/home/{$user->name}/backups/" . $filename;

        if (!file_exists($filePath)) {
            abort(404);
        }

        // Security check: ensure file belongs to user
        if (strpos($filename, $user->name) !== 0) {
            abort(403);
        }

        return response()->download($filePath);
    }
}
