<?php

namespace App\Core;

class View
{
    public static function render($view, $data = [])
    {
        extract($data);

        // check module views
        // View format: "Module::view_name" or "folder.view_name"

        $path = __DIR__ . '/../../app/Modules/';

        // Naive discovery for now. 
        // Example: Auth::login -> app/Modules/Auth/Views/login.php

        if (strpos($view, '::') !== false) {
            list($module, $file) = explode('::', $view);
            $file = str_replace('.', '/', $file);
            $viewFile = $path . $module . '/Views/' . $file . '.php';
        } else {
            // Fallback or Shared views? 
            // For now, assume everything is modular.
            $viewFile = __DIR__ . '/../../public/views/' . str_replace('.', '/', $view) . '.php';
        }

        if (file_exists($viewFile)) {
            require $viewFile;
        } else {
            die("View not found: $viewFile");
        }
    }
}
