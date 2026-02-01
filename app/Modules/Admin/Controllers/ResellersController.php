<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;
use App\Modules\Admin\Models\Reseller;

class ResellersController extends Controller
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

        $resellers = Reseller::getAll($limit, $offset, $search);
        $total = Reseller::count($search);
        $pages = ceil($total / $limit);

        $this->view('Admin::resellers/index', [
            'resellers' => $resellers,
            'total' => $total,
            'page' => $page,
            'total_pages' => $pages
        ]);
    }

    public function action()
    {
        if (!isset($_SESSION['admin'])) {
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        }

        $action = $this->input('ajax_action');

        try {
            if ($action === 'create_reseller') {
                $this->createReseller();
            } elseif ($action === 'delete_reseller') {
                $this->deleteReseller();
            } elseif ($action === 'suspend_reseller') {
                $this->suspendReseller();
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }

    private function createReseller()
    {
        $u = trim($this->input('username'));
        $e = trim($this->input('email'));
        $p = $this->input('password');

        if (Reseller::exists($u)) {
            throw new \Exception("Username already exists");
        }

        Reseller::create($u, $e, $p);

        // System Command (Optional: Create linux user if needed for reseller-specific isolation)
        // cmd("create-reseller " . escapeshellarg($u)); // To be implemented in shm-manage

        $this->json(['status' => 'success', 'msg' => 'Reseller Created']);
    }

    private function deleteReseller()
    {
        $id = (int) $this->input('id');
        Reseller::delete($id);
        $this->json(['status' => 'success', 'msg' => 'Reseller Deleted']);
    }

    private function suspendReseller()
    {
        $id = (int) $this->input('id');
        $suspend = $this->input('suspend') === 'true';
        $status = $suspend ? 'suspended' : 'active';

        Reseller::updateStatus($id, $status);

        $this->json(['status' => 'success', 'msg' => $suspend ? 'Reseller Suspended' : 'Reseller Activated']);
    }
}
