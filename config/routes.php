<?php

use App\Core\Router;

// Landing Page & Default Route
if (file_exists(__DIR__ . "/../app/Modules/Landing/routes.php")) {
    require_once __DIR__ . "/../app/Modules/Landing/routes.php";
} else {
    Router::get('/', function () {
        echo "<h1>SHM Panel - MVC Upgraded</h1>";
    });
}

// Load Module Routes
$modules = ['Auth', 'Admin', 'Client'];
foreach ($modules as $mod) {
    if (file_exists(__DIR__ . "/../app/Modules/$mod/routes.php")) {
        require_once __DIR__ . "/../app/Modules/$mod/routes.php";
    }
}
