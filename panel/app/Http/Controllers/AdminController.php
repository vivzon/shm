<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AdminController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $usersCount = User::count();
        $resellersCount = User::where('role', 'reseller')->count();
        $clientsCount = User::where('role', 'client')->count();

        return view('admin.dashboard', compact('usersCount', 'resellersCount', 'clientsCount'));
    }

    public function users()
    {
        $users = User::with('domains')->get();
        return view('admin.users.index', compact('users'));
    }

    public function storeUser(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|min:8',
            'role' => 'required|in:reseller,client',
        ]);

        try {
            // 1. Create system user via automation script
            $this->server->createUser($request->name, $request->password, $request->email);

            // 2. Create user in DB
            User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'role' => $request->role,
                'status' => 'active',
            ]);

            return redirect()->back()->with('success', 'User account created successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to create user: ' . $e->getMessage());
        }
    }
}
