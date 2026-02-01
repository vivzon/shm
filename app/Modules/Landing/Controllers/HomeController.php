<?php

namespace App\Modules\Landing\Controllers;

use App\Core\Controller;

class HomeController extends Controller
{
    public function index()
    {
        $host = $_SERVER['HTTP_HOST'];
        // Logic from original landing/index.php
        if (filter_var($host, FILTER_VALIDATE_IP)) {
            $base = $host;
            $scheme = "http://";
        } else {
            $parts = explode('.', $host);
            $base = implode('.', array_slice($parts, -2));
            $scheme = "http://";
        }

        $brandName = get_branding();

        $this->view('Landing::home', [
            'base' => $base,
            'scheme' => $scheme,
            'brandName' => $brandName
        ]);
    }
}
