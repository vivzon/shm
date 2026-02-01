<?php

namespace App\Modules\Landing\Controllers;

use App\Core\Controller;

class CheckoutController extends Controller
{
    public function index()
    {
        $id = $_GET['package_id'] ?? 1;
        // Mock packages data or fetch from DB
        $package = [
            'id' => $id,
            'name' => 'Premium Hosting',
            'price' => 9.99
        ];

        $this->view('Landing::checkout/index', ['package' => $package]);
    }

    public function process()
    {
        // Mock Payment Processing
        $data = $_POST;
        // Logic to create client, invoice, etc would go here.
        // For now, redirect to login or success.

        // Simulate Success
        $this->redirect('https://buy.stripe.com/mock_link');
    }
}
