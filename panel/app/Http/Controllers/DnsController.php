<?php

namespace App\Http\Controllers;

use App\Models\Domain;
use App\Models\DnsRecord;
use App\Services\ServerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DnsController extends Controller
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

        return view('dns.index', compact('domains'));
    }

    public function show(Domain $domain)
    {
        // Security check
        if ($domain->user_id !== Auth::id()) {
            abort(403);
        }

        $records = $domain->dnsRecords;
        return view('dns.show', compact('domain', 'records'));
    }

    public function store(Request $request, Domain $domain)
    {
        if ($domain->user_id !== Auth::id()) {
            abort(403);
        }

        $request->validate([
            'type' => 'required|in:A,AAAA,CNAME,MX,TXT,SRV',
            'name' => 'required|string',
            'content' => 'required|string',
            'ttl' => 'required|integer|min:60',
        ]);

        try {
            // In a real scenario, we'd update the zone file via shm-dns-manager.sh
            // For now, let's assume shm-manage dns-manage <add|remove> <domain> <record_data>
            // We'll just track it in the DB first.

            DnsRecord::create([
                'domain_id' => $domain->id,
                'type' => $request->type,
                'name' => $request->name,
                'content' => $request->content,
                'ttl' => $request->ttl,
            ]);

            return redirect()->back()->with('success', 'DNS record added successfully!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to add DNS record: ' . $e->getMessage());
        }
    }
}
