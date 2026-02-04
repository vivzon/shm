<?php

namespace App\Http\Controllers;

use App\Models\UserDatabase;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DatabaseController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $databases = Auth::user()->databases;
        return view('databases.index', compact('databases'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'db_name' => 'required|alpha_dash|max:64',
            'db_user' => 'required|alpha_dash|max:64',
            'db_pass' => 'required|min:8',
        ]);

        $user = Auth::user();
        $dbName = $user->name . '_' . $request->db_name;
        $dbUser = $user->name . '_' . $request->db_user;

        try {
            $this->server->createDatabase($dbName, $dbUser, $request->db_pass);

            UserDatabase::create([
                'user_id' => $user->id,
                'db_name' => $dbName,
                'db_user' => $dbUser,
            ]);

            return redirect()->back()->with('success', 'Database created successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to create database: ' . $e->getMessage());
        }
    }
}
