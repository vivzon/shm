<?php

namespace App\Http\Controllers;

use App\Models\Domain;
use App\Models\EmailAccount;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class EmailController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $user = Auth::user();
        $domains = $user->domains;
        $emails = EmailAccount::whereIn('domain_id', $domains->pluck('id'))->get();

        return view('emails.index', compact('emails', 'domains'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'domain_id' => 'required|exists:domains,id',
            'email_user' => 'required|alpha_dash',
            'password' => 'required|min:8',
            'quota' => 'required|integer|min:10',
        ]);

        $domain = Domain::findOrFail($request->domain_id);

        // Security: Ensure domain belongs to user
        if ($domain->user_id !== Auth::id()) {
            abort(403);
        }

        try {
            // Call bash script: email-create <domain> <user> <pass> <quota>
            $this->server->execute('email-create', [
                $domain->domain_name,
                $request->email_user,
                $request->password,
                $request->quota
            ]);

            EmailAccount::create([
                'domain_id' => $domain->id,
                'email_address' => $request->email_user . '@' . $domain->domain_name,
                'password_hash' => Hash::make($request->password), // Stored in DB for reference/panel login if needed
                'quota' => $request->quota,
            ]);

            return redirect()->back()->with('success', 'Email account created successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to create email account: ' . $e->getMessage());
        }
    }
}
