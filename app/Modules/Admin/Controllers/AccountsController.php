<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;
use App\Modules\Admin\Models\Client;

class AccountsController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['admin'])) {
            $this->redirect('/admin/login');
        }

        $page = (int) $this->input('page', 1);
        $search = $this->input('search');
        $limit = 10;
        $offset = ($page - 1) * $limit;

        $owner_id = ($_SESSION['role'] === 'reseller') ? $_SESSION['user_id'] : null;

        $clients = Client::getAll($limit, $offset, $search, $owner_id);
        $total = Client::count($search, $owner_id);
        $pages = ceil($total / $limit);
        $packages = Client::getPackages();

        $this->view('Admin::accounts/index', [
            'clients' => $clients,
            'total' => $total,
            'page' => $page,
            'total_pages' => $pages,
            'packages' => $packages
        ]);
    }

    public function action()
    {
        if (!isset($_SESSION['admin'])) {
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        }

        $action = $this->input('ajax_action');

        try {
            if ($action === 'save_account') {
                $this->saveAccount();
            } elseif ($action === 'delete_account') {
                $this->deleteAccount();
            } elseif ($action === 'suspend_account') {
                $this->suspendAccount();
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }

    private function saveAccount()
    {
        $id = $this->input('id');
        $u = trim($this->input('user'));
        $d = trim($this->input('dom'));
        $e = trim($this->input('email'));
        $pkg = (int) $this->input('package_id');
        $pass = $this->input('pass');

        if ($id) {
            // Update Logic
            $client = Client::find($id);
            if (!$client) {
                throw new \Exception("Client not found.");
            }

            Client::update($id, $e, $pkg, empty($pass) ? null : $pass);

            // If package changed, we might need to update limits on system
            if ($client['package_id'] != $pkg) {
                cmd("update-account-limits " . escapeshellarg($client['username']) . " " . (int) $pkg);
            }

            $this->json(['status' => 'success', 'msg' => 'Account Updated']);
        } else {
            // Create Logic
            if (Client::exists($u, $d)) {
                throw new \Exception("User or Domain already exists.");
            }

            $owner_id = ($_SESSION['role'] === 'reseller') ? $_SESSION['user_id'] : null;
            $cid = Client::create($u, $e, $pass, $pkg, $d, $owner_id);

            // Shell Command
            cmd("create-account " . escapeshellarg($u) . " " . escapeshellarg($d) . " " . escapeshellarg($e) . " " . escapeshellarg($pass));

            $this->json(['status' => 'success', 'msg' => 'Account Created']);
        }
    }

    private function deleteAccount()
    {
        $id = (int) $this->input('id');
        $client = Client::find($id);

        if (!$client) {
            throw new \Exception("Client not found");
        }

        // System Command: delete-account <username>
        $output = cmd("delete-account " . escapeshellarg($client['username']));

        // Database Cleanup
        Client::delete($id);

        $this->json(['status' => 'success', 'msg' => 'Account Terminated. System Output: ' . $output]);
    }

    private function suspendAccount()
    {
        $user = $this->input('user');
        $id = (int) $this->input('id'); // Ensure ID is passed from frontend
        $suspend = $this->input('suspend') === 'true';

        $cmd = $suspend ? 'suspend-account' : 'unsuspend-account';
        $output = cmd("$cmd " . escapeshellarg($user));

        // Update DB Status
        $status = $suspend ? 'suspended' : 'active';
        Client::updateStatus($id, $status);

        $this->json(['status' => 'success', 'msg' => $suspend ? 'Account Suspended' : 'Account Unsuspended']);
    }
}
