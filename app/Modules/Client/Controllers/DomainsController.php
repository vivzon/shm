<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Modules\Client\Models\Domain;

class DomainsController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['cid'])) {
            $this->redirect('/login');
        }

        $clientId = $_SESSION['cid'];
        $domains = Domain::getAll($clientId);

        $this->view('Client::domains/index', ['domains' => $domains]);
    }

    public function action()
    {
        if (!isset($_SESSION['cid'])) {
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        }

        $action = $this->input('ajax_action');

        try {
            if ($action === 'add_domain') {
                $this->addDomain();
            } elseif ($action === 'delete_domain') {
                $this->deleteDomain();
            } elseif ($action === 'convert_htaccess') {
                $this->convertHtaccess();
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()]);
        }
    }

    private function convertHtaccess()
    {
        $id = $this->input('id');
        $domain = Domain::find($id, $_SESSION['cid']);

        if (!$domain) {
            throw new \Exception("Domain not found.");
        }

        // Use the domain path from DB
        $path = $domain['path'];

        // Call system command
        // Output might include logs, so we capture it
        $output = cmd("convert-htaccess " . escapeshellarg($path));

        $this->json(['status' => 'success', 'msg' => 'Conversion triggered.', 'output' => $output]);
    }

    private function addDomain()
    {
        $dom = strtolower(trim($this->input('domain')));
        $path = trim($this->input('path'));

        if (!preg_match('/^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/', $dom)) {
            throw new \Exception("Invalid Domain Name Format");
        }

        if (Domain::exists($dom)) {
            throw new \Exception("Domain already exists on this server.");
        }

        // Auto path if empty
        if (empty($path)) {
            $user = $_SESSION['client'];
            // New structure: /var/www/clients/domain.com
            $path = "/var/www/clients/$dom";
        }

        Domain::create($_SESSION['cid'], $dom, $path);

        // System Command
        // Using 'add-domain' to match shm-manage
        cmd("add-domain " . escapeshellarg($_SESSION['client']) . " " . escapeshellarg($dom));

        $this->json(['status' => 'success', 'msg' => 'Domain Added']);
    }

    private function deleteDomain()
    {
        $id = $this->input('id');
        $domain = Domain::find($id, $_SESSION['cid']);

        if (!$domain) {
            throw new \Exception("Domain not found.");
        }

        Domain::delete($id, $_SESSION['cid']);

        cmd("delete-domain " . escapeshellarg($_SESSION['client']) . " " . escapeshellarg($domain['domain']));

        $this->json(['status' => 'success', 'msg' => 'Domain Deleted']);
    }
}
