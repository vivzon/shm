<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Core\Database;
use App\Modules\Client\Models\Domain;

class DnsController extends Controller
{
    public function __construct()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');
    }

    public function index()
    {
        $clientId = $_SESSION['cid'];
        $domains = Domain::getAll($clientId);
        $domain_id = isset($_GET['domain_id']) ? (int) $_GET['domain_id'] : 0;

        $records = [];
        if ($domain_id) {
            // Verify ownership
            $d = Domain::find($domain_id, $clientId);
            if ($d) {
                $records = Database::fetchAll("SELECT * FROM dns_records WHERE domain_id = ? ORDER BY type, host", [$domain_id]);
            }
        }

        $this->view('Client::dns/index', [
            'domains' => $domains,
            'records' => $records,
            'selected_domain' => $domain_id
        ]);
    }

    public function action()
    {
        $action = $this->input('ajax_action');
        $clientId = $_SESSION['cid'];

        try {
            if ($action === 'add_record') {
                $this->addRecord($clientId);
            } elseif ($action === 'delete_record') {
                $this->deleteRecord($clientId);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()]);
        }
    }

    private function addRecord($clientId)
    {
        $domain_id = (int) $this->input('domain_id');
        $type = strtoupper($this->input('type'));
        $host = trim($this->input('host'));
        $value = trim($this->input('value'));
        $priority = $this->input('priority') ? (int) $this->input('priority') : null;

        $d = Domain::find($domain_id, $clientId);
        if (!$d)
            throw new \Exception("Invalid Domain");

        Database::query(
            "INSERT INTO dns_records (domain_id, type, host, value, priority) VALUES (?,?,?,?,?)",
            [$domain_id, $type, $host, $value, $priority]
        );

        // Sync with system
        cmd("shm-manage dns-tool sync " . (int) $domain_id);

        $this->json(['status' => 'success', 'msg' => 'DNS Record Added']);
    }

    private function deleteRecord($clientId)
    {
        $record_id = (int) $this->input('record_id');

        // Ownership check via JOIN
        $record = Database::fetch("SELECT r.*, d.client_id FROM dns_records r JOIN domains d ON r.domain_id = d.id WHERE r.id = ? AND d.client_id = ?", [$record_id, $clientId]);

        if (!$record)
            throw new \Exception("Record not found or access denied");

        Database::query("DELETE FROM dns_records WHERE id = ?", [$record_id]);

        // Sync with system
        cmd("shm-manage dns-tool sync " . (int) $record['domain_id']);

        $this->json(['status' => 'success', 'msg' => 'DNS Record Deleted']);
    }
}
