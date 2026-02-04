<?php

namespace App\Http\Controllers;

use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CronController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $user = Auth::user();

        try {
            $output = $this->server->execute('cron-manage', [$user->name, 'list']);
            $lines = array_filter(explode("\n", trim($output)));

            $cronJobs = [];
            foreach ($lines as $index => $line) {
                $cronJobs[] = [
                    'line_num' => $index + 1,
                    'content' => $line
                ];
            }
        } catch (\Exception $e) {
            $cronJobs = [];
        }

        return view('cron.index', compact('cronJobs'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'schedule' => 'required|string',
            'command' => 'required|string',
        ]);

        $user = Auth::user();

        try {
            $this->server->execute('cron-manage', [
                $user->name,
                'add',
                $request->schedule,
                $request->command
            ]);

            return redirect()->back()->with('success', 'Cron job added successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to add cron job: ' . $e->getMessage());
        }
    }

    public function destroy($lineNum)
    {
        $user = Auth::user();

        try {
            $this->server->execute('cron-manage', [
                $user->name,
                'remove',
                $lineNum
            ]);

            return redirect()->back()->with('success', 'Cron job removed.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to remove: ' . $e->getMessage());
        }
    }
}
