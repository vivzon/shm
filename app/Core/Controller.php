<?php

namespace App\Core;

class Controller
{
    protected function view($view, $data = [])
    {
        return View::render($view, $data);
    }

    protected function json($data, $code = 200)
    {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }

    protected function redirect($url)
    {
        header("Location: $url");
        exit;
    }

    protected function input($key, $default = null)
    {
        return $_POST[$key] ?? $_GET[$key] ?? $default;
    }
}
