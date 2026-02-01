<?php

namespace App\Modules\Admin\Controllers;

use App\Core\Controller;
use App\Modules\Admin\Models\Package;

class PackagesController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['admin'])) {
            $this->redirect('/admin/login');
        }

        $packages = Package::getAll();
        $this->view('Admin::packages/index', ['packages' => $packages]);
    }

    public function action()
    {
        if (!isset($_SESSION['admin'])) {
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        }

        $action = $this->input('ajax_action');

        try {
            if ($action === 'save_package') {
                $this->savePackage();
            } elseif ($action === 'delete_package') {
                $this->deletePackage();
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()], 500);
        }
    }

    private function savePackage()
    {
        $id = $this->input('id');
        $name = trim($this->input('name'));
        $disk = (int) $this->input('disk');
        $doms = (int) $this->input('doms');
        $mails = (int) $this->input('mails');

        if (empty($name)) {
            throw new \Exception("Package name is required.");
        }

        if (Package::exists($name, $id)) {
            throw new \Exception("Package '$name' already exists.");
        }

        if ($id) {
            Package::update($id, $name, $disk, $doms, $mails);
            $this->json(['status' => 'success', 'msg' => 'Package Updated']);
        } else {
            Package::create($name, $disk, $doms, $mails);
            $this->json(['status' => 'success', 'msg' => 'Package Created']);
        }
    }

    private function deletePackage()
    {
        $id = $this->input('id');
        Package::delete($id);
        $this->json(['status' => 'success', 'msg' => 'Package Deleted']);
    }
}
