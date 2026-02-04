<?php

namespace App\Http\Controllers;

use App\Models\Domain;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DomainController extends Controller
{
    protected $server;

    public function __construct(ServerService $server)
    {
        $this->server = $server;
    }

    public function index()
    {
        $domains = Auth::user()->domains;
        return view('domains.index', compact('domains'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'domain_name' => 'required|unique:domains,domain_name|regex:/^(?!:\/\/)([a-zA-Z0-9-_]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?$/',
            'php_version' => 'required|in:7.4,8.0,8.1,8.2',
        ]);

        $user = Auth::user();

        // 1. Create system user and site via ServerService
        // If this is the user's first domain, we might need to create the system user first.
        // For simplicity, we assume one system user per hosting account (Auth::user()).

        try {
            $this->server->createSite($user->name, $request->domain_name, $request->php_version);

            Domain::create([
                'user_id' => $user->id,
                'domain_name' => $request->domain_name,
                'document_root' => "/home/{$user->name}/public_html",
                'php_version' => $request->php_version,
            ]);

            return redirect()->back()->with('success', 'Domain added successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to create site: ' . $e->getMessage());
        }
    }

    public function issueSsl(Domain $domain)
    {
        try {
            $this->server->issueSsl($domain->domain_name);
            $domain->update(['has_ssl' => true, 'ssl_provider' => 'letsencrypt']);
            return redirect()->back()->with('success', 'SSL issued successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'SSL failed: ' . $e->getMessage());
        }
    }
}
